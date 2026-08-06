% RUN_CLUSTER_SENSITIVITY  Cluster-aware uncertainty and site sensitivity
% for the paper's headline effects.  (2026-08-06 audit, P0 item 1.3)
%
% Records are not independent experimental units: simultaneous instruments
% share a deployment, 40 of 65 records are at Torrey Pines, and repeated
% years share geometry and model error. This script reports, for each
% headline statistic:
%   - the point estimate on its named population;
%   - a DEPLOYMENT-cluster bootstrap 95% CI (resample deployments with
%     replacement, keeping all records of a deployment together; 2000 reps);
%   - a SITE-cluster bootstrap CI (sites: Torrey = TOR/TBR/RUBY; SIO; IB;
%     COR; CDF; SOL; LPL; CAT);
%   - leave-one-site-out values and the Torrey-removed value.
%
% Statistics covered: nu_ratio median (model-inference, n=60); beta_ss_net
% median (in-situ, n=61 incl. CAT); excess-vs-beta closure median(y-x) and
% through-origin slope (with and without COR16B); alongshore b0 median and
% its direction-corrected counterfactual.
%
% All inputs are saved per-record tables; no re-sweeps. Output:
% outputs/validation/cluster_sensitivity.mat
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
rng(806, 'twister');
NB = 2000;

% site mapping: Torrey Pines = TOR*/TBR*/RUBY* deployments (same reach)

%% ---- load per-record tables -------------------------------------------
M = load(fullfile(root,'validation','cross_deployment_matched_shape.mat'));
R1 = M.ROWS(cellfun(@isempty,{M.ROWS.status}));
ex1 = arrayfun(@(r) excluded_records(r.deployment, r.label), R1);
R1 = R1(~ex1);
nu   = [R1.nu_ratio];
dep1 = {R1.deployment};

B = load(fullfile(root,'validation','bispectral_beta.mat'));
RB = B.R([B.R.closure_ok] & ~[B.R.excluded]);
bet  = [RB.beta_ss_net];
dep2 = {RB.deployment};

E = load(fullfile(root,'validation','beta_excess_closure.mat'));
C = E.C;
x  = [C.beta]./(1-[C.beta]); y = [C.Eharm_ratio]-1;
dep3 = cellfun(@(r) strtok(r,'/'), {C.rec}, 'UniformOutput', false);
notCor = ~strcmp({C.rec}, 'COR16B/MOP158_9m');

A = load(fullfile(root,'validation','alongshore_b2_split.mat'));
W = A.W(~[A.W.excluded]);
b0  = [W.b0_actual]; b0d = [W.b0_spronly];
dep4 = cellfun(@(r) strtok(r,'/'), {W.rec}, 'UniformOutput', false);

%% ---- the statistics as closures over index sets ------------------------
stats = {
 'nu_ratio median (model-inference)', dep1, @(ii) median(nu(ii));
 'beta_ss_net median (in-situ)',      dep2, @(ii) median(bet(ii));
 'closure median(y-x)',               dep3, @(ii) median(y(ii)-x(ii));
 'closure slope b0 (all)',            dep3, @(ii) sum(x(ii).*y(ii))/max(sum(x(ii).^2),eps);
 'closure slope b0 (minus COR16B)',   dep3, @(ii) slope_noCor(ii, x, y, notCor);
 'alongshore b0 median',              dep4, @(ii) median(b0(ii));
 'alongshore b0 dir-corrected',       dep4, @(ii) median(b0d(ii));
};

OUT = struct('name',{},'est',{},'ciDep',{},'ciSite',{},'looSite',{},'noTorrey',{});
for s = 1:size(stats,1)
    deps = stats{s,2}; fun = stats{s,3};
    n = numel(deps);
    est = fun(1:n);
    ciD = cboot(deps, fun, NB);
    sites = cellfun(@siteOf, deps, 'UniformOutput', false);
    ciS = cboot(sites, fun, NB);
    uS = unique(sites);
    loo = cell(numel(uS),2);
    for q = 1:numel(uS)
        ii = find(~strcmp(sites, uS{q}));
        loo{q,1} = uS{q}; loo{q,2} = fun(ii);
    end
    noT = fun(find(~strcmp(sites,'Torrey'))); %#ok<FNDSB>
    OUT(end+1) = struct('name',stats{s,1},'est',est,'ciDep',ciD, ...
        'ciSite',ciS,'looSite',{loo},'noTorrey',noT); %#ok<SAGROW>
    fprintf('%-36s est %7.3f  dep-CI [%7.3f %7.3f]  site-CI [%7.3f %7.3f]  noTorrey %7.3f (n=%d)\n', ...
        stats{s,1}, est, ciD(1), ciD(2), ciS(1), ciS(2), noT, ...
        sum(~strcmp(sites,'Torrey')));
end
fprintf('\nleave-one-site-out, nu_ratio median:\n');
loo = OUT(1).looSite;
for q = 1:size(loo,1), fprintf('  minus %-8s %7.4f\n', loo{q,1}, loo{q,2}); end

meta = struct('created', datetime('now'), 'NB', NB, ...
    'note', 'Deployment- and site-cluster bootstrap CIs + leave-one-site-out (audit P0 1.3).');
save(fullfile(root,'validation','cluster_sensitivity.mat'), 'OUT', 'meta');
fprintf('saved outputs/validation/cluster_sensitivity.mat\n');

%% ---- helpers -----------------------------------------------------------
function ci = cboot(clusters, fun, NB)
uC = unique(clusters); nC = numel(uC);
idx = cellfun(@(c) reshape(find(strcmp(clusters, c)), [], 1), uC, 'UniformOutput', false);
v = NaN(NB,1);
for b = 1:NB
    pick = randi(nC, nC, 1);
    ii = vertcat(idx{pick});
    v(b) = fun(ii(:)');
end
ci = quantile(v, [0.025 0.975]);
end

function b = slope_noCor(ii, x, y, notCor)
ii = ii(notCor(ii));
b = sum(x(ii).*y(ii)) / max(sum(x(ii).^2), eps);
end

function s = siteOf(dep)
if any(strncmp(dep, {'TOR','TBR','RUB'}, 3)), s = 'Torrey';
elseif strncmp(dep,'SIO',3), s = 'SIO';
elseif strncmp(dep,'IB',2),  s = 'IB';
elseif strncmp(dep,'COR',3), s = 'COR';
elseif strncmp(dep,'CDF',3), s = 'CDF';
elseif strncmp(dep,'SOL',3), s = 'SOL';
elseif strncmp(dep,'LPL',3), s = 'LPL';
elseif strncmp(dep,'CAT',3), s = 'CAT';
else, s = 'OTHER';
end
end
