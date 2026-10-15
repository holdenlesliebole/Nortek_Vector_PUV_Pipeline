% RERUN_RUBY22_PHASE2  Re-run Test 1 (Hs^2 scaling) for RUBY22 with all 3
% instruments, now that MOP579_6m has been re-processed with the fixed L1.
% Author: Holden Leslie-Bole, 2026

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

dep = 'RUBY22';
labels = {'MOP579_6m','MOP578_10m','MOP582_30m'};

opts = struct();
opts.figDir = fullfile('outputs','validation','mean_flow', dep);
opts.HsMin  = 0.2;

fprintf('\n=== Test 1: Hs^2 scaling for RUBY22 (post-fix) ===\n');
res1 = test1_Hs2_scaling(dep, labels, opts);

fprintf('\n=== Per-instrument summary ===\n');
fn = fieldnames(res1);
for k = 1:numel(fn)
    r = res1.(fn{k});
    if isstruct(r) && isfield(r,'alpha')
        fprintf('  %-15s  h=%.2f m  alpha=%+.5f [%+.5f,%+.5f]  beta=%+.5f  R2=%.3f  N=%d\n', ...
            fn{k}, r.h_med, r.alpha, r.alpha_CI(1), r.alpha_CI(2), r.beta, r.R2_Hs2, r.N);
        if isfield(r,'alpha_theory')
            fprintf('                   alpha_theory=%+.5f  ratio=%+.2f\n', ...
                r.alpha_theory, r.alpha / r.alpha_theory);
        end
    end
end

fprintf('\n=== Test 4: Reynolds consistency ===\n');
try
    res4 = test4_reynolds_consistency(dep, labels, opts);
    fn4 = fieldnames(res4);
    for k = 1:numel(fn4)
        r = res4.(fn4{k});
        fprintf('  %-15s  alpha_uw=%+.5f  R(uMean,uw)=%+.3f  N=%d\n', ...
            fn4{k}, r.alpha_uw, r.R_uMean_uw, r.N);
    end
catch ME
    fprintf('  test4 failed: %s\n', ME.message);
end
