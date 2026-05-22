% RERUN_RUBY22_L2_AND_PHASE2  Re-run L2 for all 3 RUBY22 instruments with
% the new HsMaxToHRatio filter, then re-run Phase 2 to see clean alpha fits.
% Author: Holden Leslie-Bole, 2026

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

cfg = RUBY22_config();

%% Re-run L2 for each instrument
for k = 1:numel(cfg.instruments)
    instr = cfg.instruments(k);
    L1file = fullfile('outputs','L1','RUBY22', [instr.label '_processed.mat']);
    if ~isfile(L1file)
        fprintf('skip %s (no L1)\n', instr.label);
        continue
    end
    fprintf('\n--- L2 for %s ---\n', instr.label);
    S = load(L1file); PUV = S.PUV;
    L2 = PUV_L2_spectral(PUV, instr, struct());
    outDir = fullfile('outputs','L2','RUBY22');
    if ~exist(outDir,'dir'), mkdir(outDir); end
    save(fullfile(outDir, [instr.label '_L2.mat']), 'L2', '-v7.3');
    v = L2.segValid;
    fprintf('  segValid: %d/%d (%.1f%%)\n', sum(v), numel(v), 100*sum(v)/numel(v));
    if sum(v) > 0
        fprintf('  Hs:    median=%.2f m, q05=%.2f q95=%.2f, max=%.2f\n', ...
            median(L2.Hs(v)), quantile(L2.Hs(v),0.05), quantile(L2.Hs(v),0.95), max(L2.Hs(v)));
        fprintf('  depth: median=%.2f m, range %.2f-%.2f\n', ...
            median(L2.depth(v)), min(L2.depth(v)), max(L2.depth(v)));
        fprintf('  Hs/h ratio: max=%.3f\n', max(L2.Hs(v) ./ L2.depth(v)));
    end
end

%% Phase 2 re-run
fprintf('\n=== Phase 2 Test 1 for RUBY22 (post-Hs-filter) ===\n');
labels = {'MOP579_6m','MOP578_10m','MOP582_30m'};
opts = struct('figDir', fullfile('outputs','validation','mean_flow','RUBY22'), 'HsMin', 0.2);
res1 = test1_Hs2_scaling('RUBY22', labels, opts);

fprintf('\n=== Per-instrument summary ===\n');
fn = fieldnames(res1);
for k = 1:numel(fn)
    r = res1.(fn{k});
    if isstruct(r) && isfield(r,'alpha')
        fprintf('  %-15s  h=%.2f m  N=%d\n', fn{k}, r.h_med, r.N);
        fprintf('    alpha=%+.5f [%+.5f,%+.5f]\n', r.alpha, r.alpha_CI(1), r.alpha_CI(2));
        fprintf('    beta=%+.5f  R2=%.3f\n', r.beta, r.R2);
        if isfield(r,'alpha_theory')
            fprintf('    alpha_theory=%+.5f  ratio=%+.2f\n', r.alpha_theory, r.alpha / r.alpha_theory);
        end
    end
end
