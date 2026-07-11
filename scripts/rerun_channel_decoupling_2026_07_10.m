function rerun_channel_decoupling_2026_07_10()
%RERUN_CHANNEL_DECOUPLING  Re-run L1+L2 for TOR23W and TBR23 with the per-channel QC and the
% San Diego site bound (Tvalid = [9 26]), reading from the LOCAL raw cache.
%
% Writes to a PARALLEL output tree (outputs/rerun_2026-07-10/{L1,L2}/) so nothing canonical
% is touched. Compare against outputs/L2/ before promoting (compare_rerun_2026_07_10.m).
%
% The raw is already cached locally, but under a different folder name than cfg.name, so we
% point cfg.localDataRoot at the actual cache path per deployment rather than use
% copy_raw_to_local (which would re-copy from the slow mount).
%
% 2026-07-10.

startup_puv;
root    = fileparts(fileparts(mfilename('fullpath')));
outbase = fullfile(root, 'outputs', 'rerun_2026-07-10');

deps = { ...
  'TOR23W', fullfile(root,'raw_cache','NN24'); ...
  'TBR23',  fullfile(root,'raw_cache','TBR23') };

for d = 1:size(deps,1)
    name = deps{d,1};  localRoot = deps{d,2};
    cfg = feval([name '_config']);
    cfg.localDataRoot = localRoot;             % read from local cache
    if ~isfield(cfg,'qcOpts') || ~isfield(cfg.qcOpts,'Tvalid')
        cfg.qcOpts.Tvalid = [9 26];            % belt-and-suspenders; config already sets it
    end
    l1dir = fullfile(outbase,'L1',name);  if ~isfolder(l1dir), mkdir(l1dir); end
    l2dir = fullfile(outbase,'L2',name);  if ~isfolder(l2dir), mkdir(l2dir); end

    fprintf('\n########## %s (%d instruments, Tvalid=[%g %g]) ##########\n', ...
        name, numel(cfg.instruments), cfg.qcOpts.Tvalid(1), cfg.qcOpts.Tvalid(2));
    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);
        fprintf('\n--- %s / %s ---\n', name, instr.label); tic
        try
            PUV = PUV_raw_process(instr, cfg);
        catch ME
            fprintf('  L1 FAILED: %s\n', ME.message);
            continue
        end
        save(fullfile(l1dir, [instr.label '_processed.mat']), 'PUV', '-v7.3');
        try
            L2 = PUV_L2_spectral(PUV, instr, struct());
        catch ME
            fprintf('  L2 FAILED: %s\n', ME.message);
            continue
        end
        save(fullfile(l2dir, [instr.label '_L2.mat']), 'L2', '-v7.3');
        fprintf('  done in %.1f min: %d/%d segValid, %d segValid_vel, %d segValid_p\n', ...
            toc/60, sum(L2.segValid), numel(L2.segValid), sum(L2.segValid_vel), sum(L2.segValid_p));
    end
end
fprintf('\nRERUN_DONE\n');
end
