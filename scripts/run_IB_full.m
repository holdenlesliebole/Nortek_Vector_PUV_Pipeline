% RUN_IB_FULL  L1 → L2 → Phase 2 for the 4 new Imperial Beach records:
% IB18W/MOP055_7m, IB18W/MOP045_7m, IB19S/MOP055_7m, IB19S/MOP045_7m.
% Author: Holden Leslie-Bole, 2026

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

reg = deployment_registry();
deps = {'IB18W','IB19S'};

%% L1 + L2 for each instrument
for d = 1:numel(deps)
    dep = deps{d};
    cfgFn = reg(dep);
    cfg = cfgFn();
    fprintf('\n========== %s (%d instruments) ==========\n', dep, numel(cfg.instruments));

    outDirL1 = fullfile('outputs','L1', dep);
    outDirL2 = fullfile('outputs','L2', dep);
    if ~exist(outDirL1,'dir'), mkdir(outDirL1); end
    if ~exist(outDirL2,'dir'), mkdir(outDirL2); end

    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);
        fprintf('\n--- L1: %s/%s ---\n', dep, instr.label);
        try
            PUV = PUV_raw_process(instr, cfg);
            save(fullfile(outDirL1,[instr.label '_processed.mat']), 'PUV', '-v7.3');
            P = PUV.P; pV = P(~isnan(P));
            fprintf('  L1 saved: %d/%d valid (%.1f%%), pMed=%.2f dBar\n', ...
                numel(pV), numel(P), 100*numel(pV)/numel(P), median(pV));
        catch ME
            warning('IB:L1Failed','%s/%s L1 failed: %s', dep, instr.label, ME.message);
            continue
        end
        fprintf('--- L2: %s/%s ---\n', dep, instr.label);
        try
            L2 = PUV_L2_spectral(PUV, instr, struct());
            save(fullfile(outDirL2,[instr.label '_L2.mat']), 'L2', '-v7.3');
            v = L2.segValid;
            fprintf('  L2 saved: %d/%d segments valid (%.1f%%)\n', sum(v), numel(v), 100*mean(v));
            if sum(v) > 0
                fprintf('  Hs median=%.2f m, depth median=%.2f m\n', ...
                    median(L2.Hs(v)), median(L2.depth(v)));
            end
        catch ME
            warning('IB:L2Failed','%s/%s L2 failed: %s', dep, instr.label, ME.message);
        end
    end
end

%% Phase 2 for the new IB records (just Test 1)
fprintf('\n========== Phase 2 Test 1 — IB ==========\n');
for d = 1:numel(deps)
    dep = deps{d};
    cfgFn = reg(dep);
    cfg = cfgFn();
    labels = {cfg.instruments.label};
    opts = struct('figDir', fullfile('outputs','validation','mean_flow', dep), 'HsMin', 0.2);
    try
        res = test1_Hs2_scaling(dep, labels, opts);
        fn = fieldnames(res);
        for k = 1:numel(fn)
            r = res.(fn{k});
            if isstruct(r) && isfield(r,'alpha')
                fprintf('  %s/%-15s  h=%.2f m  N=%d  alpha=%+.5f  R2=%.3f', ...
                    dep, fn{k}, r.h_med, r.N, r.alpha, r.R2);
                if isfield(r,'alpha_theory')
                    fprintf('  ratio=%+.2f', r.alpha / r.alpha_theory);
                end
                fprintf('\n');
            end
        end
    catch ME
        fprintf('  %s test1 failed: %s\n', dep, ME.message);
    end
end
