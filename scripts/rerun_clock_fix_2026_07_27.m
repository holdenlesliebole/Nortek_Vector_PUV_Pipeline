% RERUN_CLOCK_FIX_2026_07_27  Rebuild L1-L4 for the records whose filename
% clock was Pacific local time being read as UTC.
%
%   `vec_clock_from_filenames.m` recovers the clock the recorder was SET to and
%   says in its own header that it "cannot tell you whether that was UTC or
%   local", asking for a check against the L3 tidal comparison. That check was
%   run on 2026-07-27 and every clockSource='filename' record failed it:
%   cross-correlating L2 depth against the NOAA-referenced L3 tidal prediction
%   gives R ~ -0.55 at lag 0 and 0.76-0.996 at a lag of -7 or -8 hours.
%
%   The offset is FIXED per deployment, not a timezone conversion: TOR15D,
%   TOR16D, TOR17D and COR17D all sit entirely in daylight time and still want
%   -8, so the recorders were set to PST and left there. The 2014-15 season is
%   the exception at -7, measured and stable across thirds of each record.
%
%   TOR14A is INFERRED, not measured -- 1.9 days of valid data, its own best
%   lags (-6 R=0.557, -7 R=0.542) are inside 0.015 of each other. It takes -7
%   from its season-mates. Flag it if it ever matters.
%
%   L1 MUST be rebuilt: the offset changes PUV.time, which is baked in at L1.
%   Raw is cached locally (raw_cache/<deployment>, ~3 GB total), so this does
%   not touch the SMB mount.
%
%   VALIDATION. Afterwards, rerun the lag audit; every record must come back at
%   lag 0. That is the check the clock recovery asked for and never got.
%
%   Backups to outputs/_pre_clockfix_backup_2026-07-27/.
%
%   Run from PUV_Pipeline/ (~3 h):
%     >> run scripts/rerun_clock_fix_2026_07_27

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_clockfix_backup_2026-07-27');

REC = {'TOR14A','TOR14B','TOR14C','TOR15A','TOR15B','TOR15D', ...
       'TOR16A','TOR16B','TOR16C','TOR16D','TOR17A','TOR17B', ...
       'TOR17C','TOR17D','CDF15A','CDF15C','COR16B','COR17D'};

if isempty(gcp('nocreate')), parpool('Processes'); end
p = gcp('nocreate');
fprintf('\n=== clock fix: %d records (pool %d workers) ===\n', numel(REC), p.NumWorkers);
tAll = tic; reg = deployment_registry(); nOk = 0; nFail = 0;
summary = cell(numel(REC),1);

for r = 1:numel(REC)
    dep = REC{r};
    fprintf('\n[%d/%d] %s\n', r, numel(REC), dep);
    try
        fn = reg(dep); cfg = fn();
        instr = cfg.instruments(1);
        lab   = instr.label;
        fprintf('  clockOffsetHours = %+g\n', instr.clockOffsetHours);

        l1Path = fullfile(outRoot,'L1',dep,[lab '_processed.mat']);
        l2Path = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        l3Path = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);
        l4Path = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
        for f = {l1Path,l2Path,l3Path,l4Path}
            if ~isfile(f{1}), continue, end
            rel = extractAfter(f{1}, [outRoot filesep]);
            dst = fullfile(bkRoot, rel);
            if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
            if ~isfile(dst), copyfile(f{1}, dst); end
        end

        tOld = NaT;
        if isfile(l1Path)
            q = load(l1Path,'PUV'); tOld = q.PUV.time(1);
        end

        % ---- L1 from raw (cached) ----
        t0 = tic;
        PUV = PUV_raw_process(instr, cfg);
        if ~isfolder(fileparts(l1Path)), mkdir(fileparts(l1Path)); end
        save(l1Path, 'PUV', '-v7.3');
        fprintf('  L1 rebuilt (%.1f min): %s -> %s  (start moved %s)\n', ...
            toc(t0)/60, string(tOld), string(PUV.time(1)), ...
            string(PUV.time(1) - tOld));

        % ---- L2 / L3 / L4 ----
        t0 = tic;
        L2 = PUV_L2_spectral(PUV, instr, struct());
        save(l2Path,'L2','-v7.3');
        fprintf('  L2 (%.1f min) %d/%d valid\n', toc(t0)/60, sum(L2.segValid), numel(L2.time));

        L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2); L3 = PUV_L3_currents(L3, L2);
        save(l3Path,'L3','-v7.3');

        t0 = tic;
        L4 = struct();
        L4.eta = PUV_L4_eta(PUV, L2);
        L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
        L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, struct('useParallel',true));
        L4.moments = PUV_L4_moments(L2);
        L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
        L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);
        L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
        L4.label = PUV.label; L4.deploymentName = PUV.deploymentName;
        L4.LATLON = PUV.LATLON; L4.doffp = PUV.doffp; L4.shorenormal = L2.shorenormal;
        if isfield(L2,'mopStation'), L4.mopStation = L2.mopStation; end
        L4.builtAt = datetime('now');
        save(l4Path,'L4','-v7.3');
        fprintf('  L4 (%.1f min)\n', toc(t0)/60);

        % ---- the validation that matters: tidal lag must now be 0 ----
        d = L2.depth(:); pr = L3.tidal.depth_pred(:); sv = L2.segValid(:);
        m = sv & isfinite(d) & isfinite(pr);
        lagStr = 'n/a';
        if sum(m) > 200
            a = d; b = pr; a(~m)=NaN; b(~m)=NaN;
            a = a-mean(a,'omitnan'); b = b-mean(b,'omitnan');
            a(isnan(a))=0; b(isnan(b))=0;
            bl=0; br=-2;
            for L = -14:14
                x = circshift(b,L); s = dot(a,x)/(norm(a)*norm(x)+eps);
                if s>br, br=s; bl=L; end
            end
            lagStr = sprintf('lag %+d h R=%.3f %s', bl, br, ...
                string(bl==0 && br>0.7));
        end
        summary{r} = sprintf('%-7s off %+g h | %d/%d valid | %s', ...
            dep, instr.clockOffsetHours, sum(L2.segValid), numel(L2.time), lagStr);
        fprintf('  VALIDATION: %s\n', lagStr);
        nOk = nOk + 1;
    catch ME
        fprintf(2,'  FAIL: %s\n', ME.message);
        for s = 1:numel(ME.stack), fprintf(2,'    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line); end
        summary{r} = sprintf('%-7s FAILED: %s', dep, ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\n=== Done in %.2f h: %d ok, %d failed ===\n', toc(tAll)/3600, nOk, nFail);
for r = 1:numel(summary)
    if ~isempty(summary{r}), fprintf('  %s\n', summary{r}); end
end
fprintf('\nEvery record above should read "lag +0 h ... true".\n');
