% RERUN_RUBY22_MOP579_6m  Re-run L1 + L2 for the 16737 / MOP579 6m record
% after the saturation-robust pressure QC fix in PUV_raw_process.m. Compares
% the re-processed L1 P statistics to the legacy Athina pipeline.
% Author: Holden Leslie-Bole, 2026

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

cfg = RUBY22_config();
% Pick the 6m instrument (3rd in cfg)
instr = cfg.instruments(3);
fprintf('Re-processing %s/%s (depth_nominal=%.1f m)...\n', cfg.name, instr.label, instr.depth_nominal);

% Use local cache if available
localCache = fullfile(fileparts(mfilename('fullpath')), '..', 'raw_cache', cfg.name);
if isfolder(localCache)
    cfg.localDataRoot = localCache;
    fprintf('Using local cache: %s\n', localCache);
end

PUV = PUV_raw_process(instr, cfg);

%% Save L1
outDir = fullfile(cfg.outputDir, 'L1', cfg.name);
if ~exist(outDir,'dir'), mkdir(outDir); end
outFile = fullfile(outDir, [instr.label '_processed.mat']);
save(outFile, 'PUV', '-v7.3');
fprintf('Saved L1: %s\n', outFile);

%% Quick L1 sanity check
P = PUV.P; pV = P(~isnan(P));
fprintf('\n=== Re-processed L1 P ===\n');
fprintf('total=%d, valid=%d (%.1f%%), median=%.3f dBar, range %.3f-%.3f\n', ...
    numel(P), numel(pV), 100*numel(pV)/numel(P), median(pV), min(pV), max(pV));
qs = quantile(pV, [0.05 0.25 0.50 0.75 0.95]);
fprintf('quantiles: q05=%.2f q25=%.2f q50=%.2f q75=%.2f q95=%.2f\n', qs);

%% Compare to legacy
fprintf('\n=== Legacy Ruby2D L1 (reference) ===\n');
LFile = '/Volumes/group/Ruby2D/PUV/Level1_QC/Torrey_Ruby2D_579_6m_processed.mat';
if isfile(LFile)
    Lg = load(LFile);
    if isfield(Lg,'PUV') && isfield(Lg.PUV,'P')
        Pl = Lg.PUV.P; pVl = Pl(~isnan(Pl));
        fprintf('Legacy P: total=%d, valid=%d, median=%.3f dBar\n', ...
            numel(Pl), numel(pVl), median(pVl));
    end
end

%% Run L2
fprintf('\n=== Running L2 spectral ===\n');
opts = struct();
L2 = PUV_L2_spectral(PUV, instr, opts);

outDirL2 = fullfile(cfg.outputDir, 'L2', cfg.name);
if ~exist(outDirL2,'dir'), mkdir(outDirL2); end
outFileL2 = fullfile(outDirL2, [instr.label '_L2.mat']);
save(outFileL2, 'L2', '-v7.3');
fprintf('Saved L2: %s\n', outFileL2);

v = L2.segValid;
fprintf('\n=== L2 summary (post-fix) ===\n');
fprintf('segValid: %d/%d (%.1f%%)\n', sum(v), numel(v), 100*sum(v)/numel(v));
if sum(v) > 0
    fprintf('depth: median=%.2f m, range %.2f-%.2f\n', ...
        median(L2.depth(v)), min(L2.depth(v)), max(L2.depth(v)));
    fprintf('Hs:    median=%.3f m, range %.3f-%.3f\n', ...
        median(L2.Hs(v)), min(L2.Hs(v)), max(L2.Hs(v)));
    fprintf('Tp:    median=%.2f s, range %.2f-%.2f\n', ...
        median(L2.Tp(v)), min(L2.Tp(v)), max(L2.Tp(v)));
end
