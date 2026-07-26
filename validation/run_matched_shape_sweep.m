% RUN_MATCHED_SHAPE_SWEEP  Resolution-matched shape comparison over the whole catalog.
%
% Successor to the shape half of run_full_validation_suite.m, which used the
% interp-up code path now known to manufacture the peak-broadening effect it
% was measuring (validation/test_resolution_artifact.m). This driver calls
% compare_shape_matched.m, which reduces both products to the model's native
% bin grid first.
%
% Walks every deployment in the registry rather than the 33 post-2023 records
% the old summary covered, and records a reason for every record it skips --
% silent truncation reads as "covered everything" when it did not.
%
% Writes outputs/validation/cross_deployment_matched_shape.mat with:
%   ROWS    struct array, one entry per attempted instrument-record
%   SKIPPED struct array of records that produced no metrics, with .status
%   meta    band, timestamp, code provenance
%
% Author: Holden Leslie-Bole, 2026

startup_puv

toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

registry    = deployment_registry();
deployNames = sort(keys(registry));

pipelineRoot = fileparts(fileparts(mfilename('fullpath')));
outDir       = fullfile(pipelineRoot, 'outputs', 'validation');
if ~isfolder(outDir), mkdir(outDir); end

fprintf('\n================================================================\n');
fprintf(' Matched-grid shape sweep — %d registered deployments\n', numel(deployNames));
fprintf(' Both products reduced to the model bin grid before any metric.\n');
fprintf('================================================================\n\n');

ROWS = struct([]); SKIPPED = struct([]);
nAttempt = 0; t0 = tic;
seenRecord = containers.Map('KeyType','char','ValueType','logical');

for d = 1:numel(deployNames)
    dName = deployNames{d};
    try
        configFn = registry(dName);
        cfg = configFn();
    catch
        continue
    end

    % The registry holds aliases -- TOR23S points at TBR23_config -- so two
    % keys can resolve to the same cfg.name and the same L2 directory. Walk
    % each physical record once; otherwise TBR23's 4 records are counted
    % twice and the catalog total reads 69 instead of the manifest's 65.
    if isKey(seenRecord, cfg.name)
        fprintf('[%2d/%2d] %s -> alias of an already-processed config, skipping\n', ...
            d, numel(deployNames), dName);
        continue
    end
    seenRecord(cfg.name) = true; %#ok<NASGU>

    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l2Dir), continue; end
    files = dir(fullfile(l2Dir, '*_L2.mat'));
    if isempty(files), continue; end

    fprintf('[%2d/%2d] %s (%d instrument-records)\n', d, numel(deployNames), cfg.name, numel(files));

    for k = 1:numel(files)
        fn = fullfile(files(k).folder, files(k).name);
        nAttempt = nAttempt + 1;
        try
            S = load(fn); L2 = S.L2;
            R = compare_shape_matched(L2, struct('verbose', true));
        catch ME
            R = struct('status', ['error: ' ME.message], ...
                       'deployment', cfg.name, 'label', erase(files(k).name,'_L2.mat'), ...
                       'station','');
        end

        if isempty(R.status)
            R.seg = [];              % drop per-hour vectors from the summary file
            R.time = [];
            if isempty(ROWS), ROWS = R; else, ROWS(end+1) = orderfields(R, ROWS); end %#ok<SAGROW>
        else
            fprintf('        [skip] %-14s %s\n', R.label, R.status);
            s = struct('deployment', R.deployment, 'label', R.label, ...
                       'station', R.station, 'status', R.status);
            if isempty(SKIPPED), SKIPPED = s; else, SKIPPED(end+1) = s; end %#ok<SAGROW>
        end
    end
end

elapsed = toc(t0);

%% ---- Summary table ----------------------------------------------------
fprintf('\n================================================================\n');
fprintf(' RESULTS — %d of %d attempted records produced metrics (%.1f min)\n', ...
    numel(ROWS), nAttempt, elapsed/60);
fprintf('================================================================\n\n');

fprintf('%-9s %-13s %5s %5s %6s %7s %7s %7s %7s %8s %8s\n', ...
    'deploy','label','h(m)','n','bins','Qp','pkNorm','nu','Hs','Qp_leg','bw%_leg');
for i = 1:numel(ROWS)
    R = ROWS(i);
    fprintf('%-9s %-13s %5.1f %5d %6d %7.3f %7.3f %7.3f %7.3f %8.3f %8.1f\n', ...
        R.deployment, R.label, R.h_median, R.nGood, R.nBins, ...
        R.Qp_ratio, R.pkNorm_ratio, R.nu_ratio, R.Hs_ratio, ...
        R.Qp_ratio_legacy, R.bw_narrow_legacy);
end

if ~isempty(ROWS)
    qp  = [ROWS.Qp_ratio];   nu  = [ROWS.nu_ratio];
    pk  = [ROWS.pkNorm_ratio]; hs = [ROWS.Hs_ratio];
    qpl = [ROWS.Qp_ratio_legacy];
    fprintf('\n--- Cross-catalog medians (n = %d records) ---\n', numel(ROWS));
    fprintf('  MATCHED  Qp ratio     : %.3f   [IQR %.3f - %.3f]  range %.3f - %.3f\n', ...
        median(qp,'omitnan'), prctile(qp,25), prctile(qp,75), min(qp), max(qp));
    fprintf('  MATCHED  peak density : %.3f   [IQR %.3f - %.3f]\n', ...
        median(pk,'omitnan'), prctile(pk,25), prctile(pk,75));
    fprintf('  MATCHED  nu ratio     : %.3f   [IQR %.3f - %.3f]  range %.3f - %.3f\n', ...
        median(nu,'omitnan'), prctile(nu,25), prctile(nu,75), min(nu), max(nu));
    fprintf('  Hs ratio (PUV/model)  : %.3f   [IQR %.3f - %.3f]\n', ...
        median(hs,'omitnan'), prctile(hs,25), prctile(hs,75));
    fprintf('  LEGACY   Qp ratio     : %.3f   [IQR %.3f - %.3f]   <- artifact-contaminated\n', ...
        median(qpl,'omitnan'), prctile(qpl,25), prctile(qpl,75));
    fprintf('\n  Reference: self-comparison artifact on the legacy path is Qp 1.225.\n');
    fprintf('  A matched median near 1.000 means no physical peak-shape bias.\n');
end

if ~isempty(SKIPPED)
    fprintf('\n--- Skipped: %d records ---\n', numel(SKIPPED));
    for i = 1:numel(SKIPPED)
        fprintf('  %-9s %-14s %s\n', SKIPPED(i).deployment, SKIPPED(i).label, SKIPPED(i).status);
    end
end

meta = struct();
meta.created     = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
meta.nAttempted  = nAttempt;
meta.nSucceeded  = numel(ROWS);
meta.elapsed_min = elapsed/60;
meta.note = ['Matched-grid shape metrics. Supersedes ' ...
             'cross_deployment_shape_summary.mat, whose bandwidth/Qp numbers ' ...
             'came from the interp-up path and are artifact-contaminated. ' ...
             'See PUV_paper/docs/findings_resolution_artifact_2026-07-24.md'];

outFile = fullfile(outDir, 'cross_deployment_matched_shape.mat');
save(outFile, 'ROWS', 'SKIPPED', 'meta');
fprintf('\nSaved: %s\n\n', outFile);
