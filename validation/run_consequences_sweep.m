% RUN_CONSEQUENCES_SWEEP  Phase 2 consequences over the whole catalog.
%
% Runs compare_derived_quantities.m for every registered instrument-record.
% Purpose beyond the per-record numbers: settle whether the Ub/Ef error is
% depth-dependent. A 5-record pilot showed a monotonic depth trend, but the
% Phase 1 sweep gives Hs-ratio-vs-depth rho = -0.172 (p = 0.18, not
% significant) with non-monotonic depth bins, and in the pilot depth was
% confounded with season. Only a full sweep with both axes populated can
% separate them.
%
% Writes outputs/validation/cross_deployment_consequences.mat
%   ROWS, SKIPPED, meta
%
% Deduplicates registry aliases (TOR23S -> TBR23_config) so the record count
% matches the server manifest.
%
% Author: Holden Leslie-Bole, 2026

startup_puv

toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

registry    = deployment_registry();
deployNames = sort(keys(registry));

pipelineRoot = fileparts(fileparts(mfilename('fullpath')));
outDir = fullfile(pipelineRoot,'outputs','validation');
if ~isfolder(outDir), mkdir(outDir); end

fprintf('\n================================================================\n');
fprintf(' Consequences sweep — Ub, Ef, IG, Shields, alongshore\n');
fprintf('================================================================\n\n');

ROWS = struct([]); SKIPPED = struct([]);
nAttempt = 0; t0 = tic;
seen = containers.Map('KeyType','char','ValueType','logical');

for d = 1:numel(deployNames)
    try
        configFn = registry(deployNames{d});
        cfg = configFn();
    catch
        continue
    end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true; %#ok<NASGU>

    l2Dir = fullfile(cfg.outputDir,'L2',cfg.name);
    if ~isfolder(l2Dir), continue; end
    files = dir(fullfile(l2Dir,'*_L2.mat'));
    if isempty(files), continue; end

    fprintf('[%2d/%2d] %s\n', d, numel(deployNames), cfg.name);
    for k = 1:numel(files)
        nAttempt = nAttempt + 1;
        try
            S = load(fullfile(files(k).folder, files(k).name));
            R = compare_derived_quantities(S.L2, struct('verbose', false));
        catch ME
            R = struct('status',['error: ' ME.message], 'deployment',cfg.name, ...
                       'label',erase(files(k).name,'_L2.mat'), 'station','');
        end
        if isempty(R.status)
            R.seg = []; R.retention = [];
            fprintf('   %-13s h=%5.1f  Ub %.3f [E %.3f x S %.3f]  Ef %.3f  tau %.3f  mob %.3f  SxyR %+.2f\n', ...
                R.label, R.h_median, R.Ub_ratio, R.Ub_energy_factor, R.Ub_shape_factor, ...
                R.Ef_ratio, R.tau_ratio, R.mobil_hours_ratio, R.Sxy_R);
            if isempty(ROWS), ROWS = R; else, ROWS(end+1) = orderfields(R, ROWS); end %#ok<SAGROW>
        else
            fprintf('   [skip] %-13s %s\n', R.label, R.status);
            s = struct('deployment',R.deployment,'label',R.label,'station',R.station,'status',R.status);
            if isempty(SKIPPED), SKIPPED = s; else, SKIPPED(end+1) = s; end %#ok<SAGROW>
        end
    end
end
elapsed = toc(t0);

%% ---- Summary -----------------------------------------------------------
fprintf('\n================================================================\n');
fprintf(' %d of %d records produced metrics (%.1f min)\n', numel(ROWS), nAttempt, elapsed/60);
fprintf('================================================================\n\n');

if ~isempty(ROWS)
    h  = [ROWS.h_median]';   ub = [ROWS.Ub_ratio]';
    en = [ROWS.Ub_energy_factor]'; shp = [ROWS.Ub_shape_factor]';
    ef = [ROWS.Ef_ratio]';   ta = [ROWS.tau_ratio]';
    mo = [ROWS.mobil_hours_ratio]'; ig = [ROWS.IG_var_fraction]';
    sr = [ROWS.Sxy_R]';      sb = [ROWS.spectrum_beats_bulk]';

    pr = @(n,v) fprintf('  %-26s %7.3f  [IQR %6.3f - %6.3f]  n=%d\n', n, ...
        median(v,'omitnan'), prctile(v,25), prctile(v,75), sum(isfinite(v)));
    fprintf('--- Cross-catalog medians ---\n');
    pr('Ub ratio (model/PUV)', ub);
    pr('  energy factor', en);
    pr('  SHAPE factor', shp);
    pr('Ef ratio', ef);
    pr('tau_b ratio', ta);
    pr('mobilized-hours ratio', mo);
    pr('IG share of near-bed var', ig);
    pr('Sxy correlation', sr);
    pr('spectrum-beats-bulk margin', sb);

    fprintf('\n--- THE DEPTH QUESTION ---\n');
    vars = {'Ub ratio',ub; 'energy factor',en; 'shape factor',shp; ...
            'Ef ratio',ef; 'tau ratio',ta; 'IG share',ig};
    for i = 1:size(vars,1)
        m = isfinite(h) & isfinite(vars{i,2});
        [rr,pp] = corr(h(m), vars{i,2}(m), 'type','Spearman');
        star = ''; if pp < 0.05, star = ' *'; end
        fprintf('  %-16s vs depth : rho = %+.3f  (p = %.3g)%s\n', vars{i,1}, rr, pp, star);
    end

    edges = [0 6 8 9.5 12 20 40];
    fprintf('\n  binned by depth:\n');
    fprintf('  %-12s %4s %9s %9s %9s %9s\n','band','n','Ub','energy','shape','Ef');
    for b = 1:numel(edges)-1
        m = h >= edges(b) & h < edges(b+1) & isfinite(ub);
        if ~any(m), continue; end
        fprintf('  %4.1f-%4.1f m %4d %9.3f %9.3f %9.3f %9.3f\n', edges(b), edges(b+1), ...
            sum(m), median(ub(m)), median(en(m)), median(shp(m)), median(ef(m),'omitnan'));
    end

    % Season, to break the pilot's depth/season confound
    fprintf('\n--- SEASON (deployment code S=summer, W=winter) ---\n');
    dn = {ROWS.deployment}';
    isW = contains(dn,'W') & ~contains(dn,'RUBY');
    isS = contains(dn,'S') & ~contains(dn,'SIO') & ~contains(dn,'SOL');
    fprintf('  winter-coded n=%d: Ub %.3f, energy %.3f\n', sum(isW), median(ub(isW),'omitnan'), median(en(isW),'omitnan'));
    fprintf('  summer-coded n=%d: Ub %.3f, energy %.3f\n', sum(isS), median(ub(isS),'omitnan'), median(en(isS),'omitnan'));
    fprintf('  (crude coding from deployment names; refine before quoting)\n');

    nBad = sum(sr < 0);
    fprintf('\n--- ALONGSHORE FRAME ---\n');
    fprintf('  %d of %d records have NEGATIVE Sxy correlation (frame/quality problem)\n', ...
        nBad, sum(isfinite(sr)));
    if nBad > 0
        bad = find(sr < 0);
        for i = bad'
            fprintf('    %-9s %-13s h=%5.1f  R=%+.3f\n', ROWS(i).deployment, ROWS(i).label, h(i), sr(i));
        end
    end
end

if ~isempty(SKIPPED)
    fprintf('\n--- Skipped: %d ---\n', numel(SKIPPED));
    for i = 1:numel(SKIPPED)
        fprintf('  %-9s %-14s %s\n', SKIPPED(i).deployment, SKIPPED(i).label, SKIPPED(i).status);
    end
end

meta = struct('created', datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
              'nAttempted', nAttempt, 'nSucceeded', numel(ROWS), ...
              'elapsed_min', elapsed/60); %#ok<TNOW1,DATST>
save(fullfile(outDir,'cross_deployment_consequences.mat'), 'ROWS','SKIPPED','meta');
fprintf('\nSaved: %s\n\n', fullfile(outDir,'cross_deployment_consequences.mat'));
