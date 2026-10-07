% RERUN_ENU_DECLINATION_2026_10_07  Rebuild L1-L4 for the three ENU records
% after adding magnetic declination to the ENU branch of PUV_raw_process.m.
%
%   The Nortek Vector forms ENU on board from its MAGNETIC compass and has no
%   declination setting, so ENU velocities are in magnetic coordinates. The
%   ENU branch never added declination D while the XYZ branch did, leaving
%   these three records D (~11.0 deg) counterclockwise of every XYZ record:
%
%     SOL24/MOP654_7m   (VEC17036)   LPL24/LPL_8m (VEC12412)   LPL25A/LPL_8m (VEC12412)
%
%   Evidence before the fix (same-site ENU minus XYZ, predicted -11.0/-11.1):
%   first-moment direction vs MOP -8.5 (Solana) / -10.3 (LPL), velocity
%   principal axis -8.7 / -10.1, Sxy b2-rotation scan -8.9 / -10.3 deg.
%   Closure test: validation/test_enu_declination_closure.m.
%
%   L1 is rebuilt from raw. Rotation changes only BuoyCoord.U/V, so the
%   check below requires every other L1 field to be unchanged, every
%   velocity sample to keep its speed, and every sample's bearing to move
%   by exactly +D (clockwise). Then L2 -> L3 -> L4 as in
%   rerun_clock_fix_2026_07_27.m.
%
%   Everything it overwrites is copied first to
%   outputs/_pre_enu_decl_backup_2026-10-07/ (delete once the server copy is
%   verified). Raw is cached in raw_cache/<DEP>/ (delete after the run).
%
%   outRoot can be set before running (e.g. a worktree writing into the
%   main checkout); default is this repo's outputs/.
%   Run from PUV_Pipeline/:  >> run scripts/rerun_enu_declination_2026_10_07

% Load THIS repo's code. A bare `startup_puv` resolves to whichever checkout
% is first on the MATLAB path (e.g. the main checkout when this runs from a
% worktree), which silently ran the unfixed PUV_raw_process on 2026-10-07.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup_puv.m'));
% PREFLIGHT, before any backup, raw copy or write. Aborts the whole run.
% (1) Every function must resolve into this checkout. l1_qc_opts arrives with
%     the Tvalid-in-config change; until that is merged this check fails.
fprintf('code root = %s\n', repoRoot);
for fnName = {'PUV_raw_process', 'l1_qc_opts', 'enu_to_buoy_frame', 'PUV_L2_spectral', ...
              'PUV_L3_transport', 'rouse_number', 'PUV_L4_bispectra'}
    w = which(fnName{1});
    fprintf('  which %-18s %s\n', fnName{1}, w);
    if isempty(w) || ~startsWith(w, [repoRoot filesep])
        error('PREFLIGHT: %s resolves to "%s", not into %s', fnName{1}, w, repoRoot);
    end
end

if ~exist('outRoot', 'var')
    outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
end
if ~exist('rawRoot', 'var')
    rawRoot = fullfile(fileparts(outRoot), 'raw_cache');
end
bkRoot = fullfile(outRoot, '_pre_enu_decl_backup_2026-10-07');
fprintf('outRoot = %s\nrawRoot = %s\n', outRoot, rawRoot);

REC = {'SOL24','MOP654_7m'; 'LPL24','LPL_8m'; 'LPL25A','LPL_8m'};
if exist('onlyRecs', 'var'), REC = REC(ismember(REC(:,1), onlyRecs), :); end
if isempty(REC), error('PREFLIGHT: no records selected'); end

% (2) Tvalid must come from the CONFIG and be the catalog's [9 26]. No
%     injection: the SOL24 overwrite of 2026-10-07 came from a config that
%     left it unset, which silently fell back to the [-2 40] default.
reg = deployment_registry();
for r = 1:size(REC,1)
    fn = reg(REC{r,1}); c = fn();
    tv = [];
    if isfield(c,'qcOpts') && isfield(c.qcOpts,'Tvalid'), tv = c.qcOpts.Tvalid; end
    fprintf('  %s config qcOpts.Tvalid = %s\n', REC{r,1}, mat2str(tv));
    if ~isequal(tv, [9 26])
        error('PREFLIGHT: %s config Tvalid is %s, expected [9 26]', REC{r,1}, mat2str(tv));
    end
end
fprintf('PREFLIGHT passed: %s\n', strjoin(REC(:,1)', ', '));
if exist('dryRun', 'var') && dryRun
    fprintf('dryRun: stopping after PREFLIGHT; nothing backed up, copied or written.\n');
    return
end

if isempty(gcp('nocreate')), parpool('Processes'); end
tAll = tic; nOk = 0; nFail = 0;
summary = cell(size(REC,1),1);

for r = 1:size(REC,1)
    dep = REC{r,1}; lab = REC{r,2};
    fprintf('\n[%d/%d] %s/%s\n', r, size(REC,1), dep, lab);
    try
        fn = reg(dep); cfg = fn();
        cfg.outputDir = outRoot;                      % L1 diagnostics land beside the outputs
        % Tvalid comes from the config and was checked to be [9 26] in
        % PREFLIGHT. That matches the canonical L1, which
        % rerun_parameterized_configs_2026_07_11.m built by injecting it.
        ii = find(strcmp({cfg.instruments.label}, lab), 1);
        if isempty(ii), error('label %s not in %s config', lab, dep); end
        instr = cfg.instruments(ii);

        l1Path = fullfile(outRoot,'L1',dep,[lab '_processed.mat']);
        l2Path = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        l3Path = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);
        l4Path = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
        for f = {l1Path,l2Path,l3Path,l4Path}
            if ~isfile(f{1}), error('missing %s', f{1}); end
            rel = extractAfter(f{1}, [outRoot filesep]);
            dst = fullfile(bkRoot, rel);
            if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
            % Verify only a copy made now. An existing backup is the pre-fix
            % original, and the live file may already be a rebuilt one on a re-run.
            if ~isfile(dst)
                copyfile(f{1}, dst);
                d0 = dir(f{1}); d1 = dir(dst);
                if d0.bytes ~= d1.bytes, error('backup size mismatch for %s', f{1}); end
            end
        end
        % From here on, compare against the BACKUP (immune to a partial rerun).
        q = load(fullfile(bkRoot,'L1',dep,[lab '_processed.mat']),'PUV'); OLD = q.PUV; clear q
        if isfield(OLD.rotation,'declinationApplied')
            error('backup L1 already carries the declination stamp; refusing to rotate twice');
        end

        % ---- L1 from raw ----
        cfg = copy_raw_to_local(cfg, rawRoot);
        t0 = tic;
        PUV = PUV_raw_process(instr, cfg);
        if ~strcmp(PUV.rotation.coordSystem,'ENU') || ~PUV.rotation.declinationApplied
            error('new L1 is not stamped ENU + declinationApplied');
        end

        % ---- L1 check: only U/V may change, and only by a rotation of +D ----
        D = PUV.rotation.mag;
        if ~isequal(PUV.time, OLD.time), error('time vector changed'); end
        same = {'P','T'};
        for s = same
            if ~isequaln(PUV.(s{1}), OLD.(s{1})), error('L1 %s changed', s{1}); end
        end
        if ~isequaln(PUV.BuoyCoord.W, OLD.BuoyCoord.W), error('W changed'); end
        for s = {'valid_vel','valid_p','valid_tilt','valid_T','opts'}
            if ~isequaln(PUV.qc.(s{1}), OLD.qc.(s{1})), error('L1 qc.%s changed', s{1}); end
        end
        % The old L1 stored D but never applied it, so the shift must equal the
        % NEW D. A changed stored D (e.g. LATLON corrected since) is reported only.
        if abs(D - OLD.rotation.mag) > 1e-12
            fprintf('  note: stored D %+.4f -> %+.4f (LATLON %s -> %s)\n', OLD.rotation.mag, D, ...
                mat2str(OLD.LATLON, 8), mat2str(PUV.LATLON, 8));
        end
        spdN = hypot(PUV.BuoyCoord.U, PUV.BuoyCoord.V);
        spdO = hypot(OLD.BuoyCoord.U, OLD.BuoyCoord.V);
        m = isfinite(spdN) & isfinite(spdO) & spdO > 0.01;      % bearing undefined near zero
        brgN = atan2d(-PUV.BuoyCoord.U(m), PUV.BuoyCoord.V(m)); % +x is WEST, so East = -U
        brgO = atan2d(-OLD.BuoyCoord.U(m), OLD.BuoyCoord.V(m));
        dB   = mod(brgN - brgO + 180, 360) - 180;
        maxSpd = max(abs(spdN - spdO), [], 'omitnan');
        maxRot = max(abs(dB - D));
        fprintf('  L1 (%.1f min): D = %+.4f deg | bearing shift median %+.6f, max |shift-D| %.2e deg | max |dspeed| %.2e m/s | n=%d\n', ...
            toc(t0)/60, D, median(dB), maxRot, maxSpd, sum(m));
        if maxRot > 1e-6 || maxSpd > 1e-9
            error('L1 change is not a pure +D rotation');
        end
        save(l1Path, 'PUV', '-v7.3'); clear OLD

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

        [~, ainfo] = l4_l2_index_map(L2, L4);
        qcz = ztest_record_flag(L2.ztest_SS, L2.segValid);
        summary{r} = sprintf('%-7s %-10s D %+.2f | max|shift-D| %.1e | %d/%d valid | aligned=%d | Z %s', ...
            dep, lab, D, maxRot, sum(L2.segValid), numel(L2.time), ainfo.identity, qcz.status);
        fprintf('  %s\n', summary{r});
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
fprintf('\nNext: validation/audit_registry_loads, validation/audit_L4_coverage, rescore, copy_to_server.\n');
