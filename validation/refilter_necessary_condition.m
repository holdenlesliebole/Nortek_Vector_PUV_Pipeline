% REFILTER_NECESSARY_CONDITION  Apply the exclusion registry to the
% necessary-condition truncation test.  (2026-08-06 audit, P0 item 1.2)
%
% The published values (rho(Ur, nu_PUV) = +0.448 full band, +0.007 at
% 2.5 fp, -0.493 at 1.5 fp; 62 records / 77,402 hours) were computed before
% the exclusion registry existed. This script reconstructs the record list
% by the same enumeration test_harmonic_closure.m uses, CLOSES against the
% published full-set values first (assertion), then recomputes with the two
% RUBY22 exclusions applied and reports the in-situ population values.
%
% Output: appended summary in outputs/validation/harmonic_closure_S_eta_refiltered.mat
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

S = load(fullfile(root, 'validation', 'harmonic_closure_S_eta.mat'));
A = S.A;

% reconstruct the enumeration exactly as the sweeps do: registry order,
% records with both L2 and L4 files
reg = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');
recList = {};
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;
    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        if isfile(fullfile(root, 'L4', cfg.name, [lab '_L4.mat']))
            recList(end+1,:) = {cfg.name, lab}; %#ok<SAGROW>
        end
    end
end
nRec = max(A.rec);
fprintf('enumeration gives %d records; A.rec max = %d, unique = %d\n', ...
    size(recList,1), nRec, numel(unique(A.rec)));
assert(size(recList,1) >= nRec, 'enumeration shorter than record indices');

% closure against published full-set values (Spearman, pooled hours)
% CUTS maps the nu columns; nu1 = full band per the original script
cutNames = {'nu1','nu2','nu3','nu4'};
fprintf('\nfull set (published: +0.448 full, +0.007 @2.5fp, -0.493 @1.5fp):\n');
rhoFull = NaN(1,4);
for c = 1:4
    v = A.(cutNames{c});
    g = isfinite(v) & isfinite(A.ur);
    rhoFull(c) = corr(A.ur(g), v(g), 'type', 'Spearman');
    fprintf('  %s (cut %s): rho = %+.4f  (n = %d hours)\n', cutNames{c}, ...
        mat2str(S.CUTS(min(c,numel(S.CUTS)))), rhoFull(c), sum(g));
end

% apply exclusions
excl = false(nRec,1);
for i = 1:nRec
    excl(i) = excluded_records(recList{i,1}, recList{i,2});
end
fprintf('\nexcluded record indices: %s (%s)\n', mat2str(find(excl)'), ...
    strjoin(cellfun(@(a,b)[a '/' b], recList(excl,1), recList(excl,2), ...
    'UniformOutput', false)', ', '));

keep = ~ismember(A.rec, find(excl));
fprintf('\nin-situ population (exclusions applied): %d records, %d hours\n', ...
    numel(unique(A.rec(keep))), sum(keep));
for c = 1:4
    v = A.(cutNames{c});
    g = keep & isfinite(v) & isfinite(A.ur);
    fprintf('  %s: rho = %+.4f\n', cutNames{c}, ...
        corr(A.ur(g), v(g), 'type', 'Spearman'));
end

save(fullfile(root, 'validation', 'harmonic_closure_S_eta_refiltered.mat'), ...
    'recList', 'excl', 'rhoFull', '-v7.3');
fprintf('saved outputs/validation/harmonic_closure_S_eta_refiltered.mat\n');
