function rerun_parameterized_configs_2026_07_11()
%RERUN_PARAMETERIZED_CONFIGS  Supplement to rerun_all_deployments_2026_07_11 for the two
% configs that bundle multiple sub-deployments behind a name argument (LPL, SIO_Pier), which
% the main loop's feval([name '_config']) could not call. Same staging tree, same resumable
% behavior; staging subfolder is named by the SUB-deployment (e.g. SIO24A) to avoid label
% collisions between sub-deployments.
%
% Run AFTER the main job finishes (avoid two heavy SMB readers contending on the mount).
% 2026-07-11.

startup_puv;
root    = fileparts(fileparts(mfilename('fullpath')));
outbase = fullfile(root, 'outputs', 'rerun_all_2026-07-11');
if ~isfolder(outbase), mkdir(outbase); end
logf = fullfile(outbase, 'progress.log');
lg = @(varargin) append_log(logf, sprintf(varargin{:}));

jobs = { ...
  'LPL',      {'LPL23','LPL24','LPL25A','LPL25B'}; ...
  'SIO_Pier', {'SIO24A','SIO24B','SIO24C','SIO25A','SIO25B','SIO25C','SIO25D','SIO25E'}; ...
  'Solana',   {'SOL24','SOL25A','SOL25B'} };

lg('==== rerun_parameterized START ====');
nOK=0; nFail=0; nSkip=0;
for j = 1:size(jobs,1)
    fn = jobs{j,1}; subs = jobs{j,2};
    for s = 1:numel(subs)
        sub = subs{s};
        try, cfg = feval([fn '_config'], sub); catch ME, lg('%s(%s) CONFIG FAILED: %s', fn, sub, ME.message); continue; end
        cfg = rmfieldsafe(cfg,'localDataRoot');
        if ~isfield(cfg,'qcOpts')||~isfield(cfg.qcOpts,'Tvalid')||isempty(cfg.qcOpts.Tvalid)
            cfg.qcOpts.Tvalid = [9 26];
        end
        l1dir = fullfile(outbase,'L1',sub); if ~isfolder(l1dir), mkdir(l1dir); end
        l2dir = fullfile(outbase,'L2',sub); if ~isfolder(l2dir), mkdir(l2dir); end
        lg('---- %s/%s: %d instruments, Tvalid=[%g %g] ----', fn, sub, numel(cfg.instruments), cfg.qcOpts.Tvalid(1), cfg.qcOpts.Tvalid(2));
        for k = 1:numel(cfg.instruments)
            instr = cfg.instruments(k);
            l2file = fullfile(l2dir, [instr.label '_L2.mat']);
            if isfile(l2file), lg('  SKIP %s/%s (L2 exists)', sub, instr.label); nSkip=nSkip+1; continue; end
            t0=tic;
            try
                PUV = PUV_raw_process(instr, cfg);
                save(fullfile(l1dir,[instr.label '_processed.mat']),'PUV','-v7.3');
            catch ME, lg('  L1 FAIL %s/%s: %s', sub, instr.label, ME.message); nFail=nFail+1; continue; end
            try
                L2 = PUV_L2_spectral(PUV, instr, struct());
                save(l2file,'L2','-v7.3');
            catch ME, lg('  L2 FAIL %s/%s: %s', sub, instr.label, ME.message); nFail=nFail+1; continue; end
            nv=sum(L2.segValid); nt=numel(L2.segValid);
            vv=ternfield(L2,'segValid_vel'); vp=ternfield(L2,'segValid_p');
            q3=0; if isfield(L2,'qc_flag'), q3=sum(L2.qc_flag==3); end
            lg('  OK   %s/%s  %.1f min  %d/%d segValid  vel+%d p+%d  qc3=%d', sub, instr.label, toc(t0)/60, nv, nt, max(vv-nv,0), max(vp-nv,0), q3);
            nOK=nOK+1;
        end
    end
end
lg('==== rerun_parameterized DONE: %d ok, %d fail, %d skip ====', nOK, nFail, nSkip);
fprintf('RERUN_PARAM_DONE ok=%d fail=%d skip=%d\n', nOK, nFail, nSkip);
end

function append_log(f, msg)
fid=fopen(f,'a'); if fid>0, fprintf(fid,'%s  %s\n', char(datetime('now','Format','HH:mm:ss')), msg); fclose(fid); end
fprintf('%s\n', msg);
end
function cfg=rmfieldsafe(cfg,fn), if isfield(cfg,fn), cfg=rmfield(cfg,fn); end, end
function n=ternfield(L2,fn), if isfield(L2,fn), n=sum(L2.(fn)); else, n=sum(L2.segValid); end, end
