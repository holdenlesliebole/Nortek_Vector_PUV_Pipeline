function reprocess_all_hourly(opts)
% REPROCESS_ALL_HOURLY  Re-run L2 spectral with 1-hour segments (7200 samples
% @ 2 Hz) across every deployment that has L1 outputs. Writes to a parallel
% outputs/L2_hourly/<deployment>/ tree, leaving 17-min L2 intact.
%
% Skips instruments that already have an hourly L2 file. Skips deployments
% with no L1 directory or no L1 files.
%
%   reprocess_all_hourly()                      % default settings
%   reprocess_all_hourly(struct('NW',4))        % override
%
% Settings:
%   segLen         = 7200    % 1 hour @ 2 Hz
%   spectralMethod = 'mtm_full'
%   NW             = 4
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);

if ~isfield(opts,'segLen'),         opts.segLen         = 7200; end
if ~isfield(opts,'spectralMethod'), opts.spectralMethod = 'mtm_full'; end
if ~isfield(opts,'NW'),             opts.NW             = 4; end

reg = deployment_registry();
deployments = sort(keys(reg));

fprintf('\n========================================\n');
fprintf(' L2 1-hour reprocess — %d deployments\n', numel(deployments));
fprintf(' segLen=%d (%.0f min), method=%s, NW=%d\n', ...
    opts.segLen, opts.segLen/2/60, opts.spectralMethod, opts.NW);
fprintf('========================================\n');

nProcessedTotal = 0; nSkippedTotal = 0; nFailedTotal = 0;

for iD = 1:numel(deployments)
    dep = deployments{iD};
    try
        configFn = reg(dep);
        cfg = configFn();
    catch ME
        fprintf('  [skip] %s — config error: %s\n', dep, ME.message);
        continue
    end
    l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
    outDir = fullfile(cfg.outputDir, 'L2_hourly', cfg.name);
    if ~isfolder(l1Dir)
        fprintf('  [skip] %s — no L1 directory\n', dep); continue
    end
    if ~exist(outDir,'dir'), mkdir(outDir); end

    fprintf('\n=== [%d/%d] %s ===\n', iD, numel(deployments), dep);
    nProcessed = 0; nSkipped = 0; nFailed = 0;
    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L2.mat']);
        if isfile(outFile)
            fprintf('  [%d/%d] %s — already 1-hr processed, skipping\n', k, numel(cfg.instruments), instr.label);
            nSkipped = nSkipped + 1;
            continue
        end
        l1File = fullfile(l1Dir, [instr.label '_processed.mat']);
        if ~isfile(l1File)
            fprintf('  [%d/%d] %s — no L1 file, skipping\n', k, numel(cfg.instruments), instr.label);
            nFailed = nFailed + 1;
            continue
        end
        fprintf('  [%d/%d] %s — processing\n', k, numel(cfg.instruments), instr.label);
        try
            loaded = load(l1File, 'PUV');
            tic
            L2 = PUV_L2_spectral(loaded.PUV, instr, opts);
            elapsed = toc;
            save(outFile, 'L2', '-v7.3');
            nValid = sum(L2.segValid); nTotal = numel(L2.segValid);
            fprintf('       saved (%d/%d valid hours, %.1f min wall)\n', nValid, nTotal, elapsed/60);
            nProcessed = nProcessed + 1;
        catch ME
            warning('reprocess:fail','FAILED: %s/%s — %s', dep, instr.label, ME.message);
            nFailed = nFailed + 1;
        end
    end
    fprintf('  -> %d ok, %d skip, %d fail\n', nProcessed, nSkipped, nFailed);
    nProcessedTotal = nProcessedTotal + nProcessed;
    nSkippedTotal   = nSkippedTotal   + nSkipped;
    nFailedTotal    = nFailedTotal    + nFailed;
end

fprintf('\n=== 1-hr reprocess complete: %d ok, %d skip, %d fail ===\n', ...
    nProcessedTotal, nSkippedTotal, nFailedTotal);
end
