% REPROCESS_TBR23_MOP586_HOURLY  Re-run L2 spectral on TBR23 MOP586 5m & 7m
% with 1-hour segments (7200 samples @ 2 Hz), writing to a parallel
% outputs/L2_hourly/TBR23/ directory so the existing 17-min L2 stays intact.
%
% Settings choice (NW = 4):
%   At 17 min, mtm_full with NW=4 → 7 tapers, ~14 DOF per bin, W = 0.0039 Hz.
%   At 1 hour, mtm_full with NW=4 → 7 tapers, ~14 DOF per bin, W = 0.0011 Hz.
% Same DOF, finer effective bandwidth — better peak resolution, same noise
% per bin. If the comparison shows we want smoother spectra at constant
% bandwidth instead, bump NW to ~14 (gives K=27, DOF~54, W matches 17-min).
% Author: Holden Leslie-Bole, 2026

startup_puv

deployment_name = 'TBR23';
labelsToRun     = {'MOP586_5m', 'MOP586_7m'};

cfg = TBR23_config();
l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);

outDir = fullfile(cfg.outputDir, 'L2_hourly', cfg.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

opts = struct();
opts.segLen         = 7200;        % 1 hour @ 2 Hz
opts.spectralMethod = 'mtm_full';  % match production
opts.NW             = 4;           % match production NW

fprintf('\n=== L2 1-hour Reprocess: %s ===\n', deployment_name);
fprintf('  segLen = %d (%.1f min), method = %s, NW = %d\n', ...
    opts.segLen, opts.segLen/cfg.fs/60, opts.spectralMethod, opts.NW);
fprintf('  Output: %s\n', outDir);

allLabels = {cfg.instruments.label};

for iI = 1:numel(labelsToRun)
    label = labelsToRun{iI};
    k = find(strcmp(allLabels, label), 1);
    if isempty(k)
        warning('reprocess:unknown', '%s not in TBR23 config — skipping.', label);
        continue
    end
    instr = cfg.instruments(k);

    l1File = fullfile(l1Dir, [label '_processed.mat']);
    if ~isfile(l1File)
        warning('reprocess:noL1', 'Missing %s', l1File);
        continue
    end

    fprintf('\n[%d/%d] %s\n', iI, numel(labelsToRun), label);
    loaded = load(l1File, 'PUV');

    tic
    L2 = PUV_L2_spectral(loaded.PUV, instr, opts);
    elapsed = toc;

    outFile = fullfile(outDir, [label '_L2.mat']);
    save(outFile, 'L2', '-v7.3');
    nValid = sum(L2.segValid);
    nTotal = numel(L2.segValid);
    fprintf('  Saved: %s   (%d/%d valid hours, %.1f min wall)\n', ...
        outFile, nValid, nTotal, elapsed/60);
    fprintf('  Hs range: %.2f-%.2f m, df = %.5f Hz, nf = %d\n', ...
        min(L2.Hs(L2.segValid)), max(L2.Hs(L2.segValid)), ...
        L2.f(2)-L2.f(1), numel(L2.f));
end

fprintf('\nDone. 1-hour L2 written to %s\n', outDir);
