function rerun_all_deployments_2026_07_11()
%RERUN_ALL_DEPLOYMENTS  Reprocess every archived PUV deployment with the per-channel QC
% (channel decoupling + sound-speed rescale) into a STAGING tree, reading raw from the lab
% server. Nothing canonical or on reefbreak is touched; promotion is a separate reviewed
% step (per deployment, because failures differ -- toppled frames vs recoverable sensor-block
% failures -- and each needs eyes, cf. MOP580_7m vs MOP586_10m in TOR23W).
%
% Output: outputs/rerun_all_2026-07-11/{L1,L2}/<dep>/<instr>_{processed,L2}.mat
% Progress log: outputs/rerun_all_2026-07-11/progress.log (one line per instrument)
%
% RESUMABLE: an instrument whose L2 already exists in the staging tree is skipped, so the
% job can be relaunched after a mount drop and it continues where it left off.
%
% San Diego County coastal sites all share the same water mass, so Tvalid=[9 26] is applied
% wherever a config does not already set it (the thermistor-plausibility bound that separates
% a dead sensor block from a live one).
%
% TOR23W and TBR23 are excluded (already reprocessed + promoted 2026-07-10).
% 2026-07-11.

startup_puv;
root    = fileparts(fileparts(mfilename('fullpath')));
outbase = fullfile(root, 'outputs', 'rerun_all_2026-07-11');
if ~isfolder(outbase), mkdir(outbase); end
logf = fullfile(outbase, 'progress.log');
lg = @(varargin) append_log(logf, sprintf(varargin{:}));

deps = {'CAT21A','CAT21B','IB18W','IB19S','LPL','RUBY22', ...
        'SIO_Pier','SOL23','Solana','TOR24S','TOR24W','TOR25S'};

lg('==== rerun_all START (%d deployments) ====', numel(deps));
nOK=0; nFail=0; nSkip=0;
for d = 1:numel(deps)
    name = deps{d};
    try, cfg = feval([name '_config']); catch ME, lg('%s CONFIG FAILED: %s', name, ME.message); continue; end
    cfg = rmfieldsafe(cfg,'localDataRoot');                  % force read from rawDataRoot (server)
    if ~isfield(cfg,'qcOpts')||~isfield(cfg.qcOpts,'Tvalid')||isempty(cfg.qcOpts.Tvalid)
        cfg.qcOpts.Tvalid = [9 26];
    end
    l1dir = fullfile(outbase,'L1',name); if ~isfolder(l1dir), mkdir(l1dir); end
    l2dir = fullfile(outbase,'L2',name); if ~isfolder(l2dir), mkdir(l2dir); end
    lg('---- %s: %d instruments, Tvalid=[%g %g] ----', name, numel(cfg.instruments), cfg.qcOpts.Tvalid(1), cfg.qcOpts.Tvalid(2));
    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);
        l2file = fullfile(l2dir, [instr.label '_L2.mat']);
        if isfile(l2file), lg('  SKIP %s/%s (L2 exists)', name, instr.label); nSkip=nSkip+1; continue; end
        t0=tic;
        try
            PUV = PUV_raw_process(instr, cfg);
            save(fullfile(l1dir,[instr.label '_processed.mat']),'PUV','-v7.3');
        catch ME
            lg('  L1 FAIL %s/%s: %s', name, instr.label, ME.message); nFail=nFail+1; continue;
        end
        try
            L2 = PUV_L2_spectral(PUV, instr, struct());
            save(l2file,'L2','-v7.3');
        catch ME
            lg('  L2 FAIL %s/%s: %s', name, instr.label, ME.message); nFail=nFail+1; continue;
        end
        nv=sum(L2.segValid); nt=numel(L2.segValid);
        vv = ternfield(L2,'segValid_vel'); vp = ternfield(L2,'segValid_p');
        q3 = 0; if isfield(L2,'qc_flag'), q3=sum(L2.qc_flag==3); end
        lg('  OK   %s/%s  %.1f min  %d/%d segValid  vel+%d p+%d  qc3=%d', ...
            name, instr.label, toc(t0)/60, nv, nt, max(vv-nv,0), max(vp-nv,0), q3);
        nOK=nOK+1;
    end
end
lg('==== rerun_all DONE: %d ok, %d fail, %d skip ====', nOK, nFail, nSkip);
fprintf('RERUN_ALL_DONE ok=%d fail=%d skip=%d\n', nOK, nFail, nSkip);
end

function append_log(f, msg)
fid=fopen(f,'a'); if fid>0, fprintf(fid,'%s  %s\n', char(datetime('now','Format','HH:mm:ss')), msg); fclose(fid); end
fprintf('%s\n', msg);
end
function cfg=rmfieldsafe(cfg,fn), if isfield(cfg,fn), cfg=rmfield(cfg,fn); end, end
function n=ternfield(L2,fn), if isfield(L2,fn), n=sum(L2.(fn)); else, n=sum(L2.segValid); end, end
