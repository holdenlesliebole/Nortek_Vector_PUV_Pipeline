% run_L3_IB_RUBY22.m
% Generate L3 for IB18W, IB19S (first run) and RUBY22 (refresh after L2
% pMed-inversion bugfix). Same logic as PUV_L3_driver, but iterates a
% small explicit list instead of one hardcoded deployment.
% Author: Holden Leslie-Bole, 2026

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

deps = {'IB18W','IB19S','RUBY22'};
registry = deployment_registry();

for d = 1:numel(deps)
    dName = deps{d};
    fprintf('\n=== [%d/%d] %s ===\n', d, numel(deps), dName);

    configFn = registry(dName);
    cfg = configFn();
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    outDir = fullfile(cfg.outputDir, 'L3', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);
        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l2File)
            fprintf('  [%d/%d] %s: no L2 file, skip\n', k, numel(cfg.instruments), instr.label);
            continue
        end

        fprintf('  [%d/%d] %s\n', k, numel(cfg.instruments), instr.label);
        try
            S = load(l2File, 'L2'); L2 = S.L2;
            L3 = PUV_L3_bands(L2);
            L3 = PUV_L3_storms(L3, L2);
            L3 = PUV_L3_transport(L3, L2);
            L3 = PUV_L3_currents(L3, L2);
            outFile = fullfile(outDir, [instr.label '_L3.mat']);
            save(outFile, 'L3', '-v7.3');
            fprintf('    saved %s (%d segments, %d valid)\n', ...
                outFile, numel(L3.time), sum(L3.segValid));
        catch ME
            warning('L3 failed for %s/%s: %s', dName, instr.label, ME.message);
            for s = 1:length(ME.stack)
                fprintf('      %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
            end
        end
    end
end

fprintf('\nDone.\n');
