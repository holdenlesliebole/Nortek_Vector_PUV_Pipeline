% REBUILD_BEAMSTEP_2026_11_13  Full catalog rebuild, HLB decision 5 of 2026-11-13.
%
% One code version for all 66 records: the L1 beam-step correction, the time-
% varying XYZ heading and spectral near-bed period T_b (tb-period-20261105), the
% Swart rough-flow friction factor (swart-amplitude-20261111), L2 velocity gaps
% from beam-step-unconfirmed samples and instr.velInvalidFrom (TOR23W/MOP586_10m),
% and the corrected TOR24W/MOP586_15m serial. Decisions and declared sizes:
% docs/SPEC_L1_beam_step_correction_2026-11-13.md section 11.
%
% Run ONE stage at a time, from the repo root (outputs/ must link to the local
% catalog copy; rawRoot defaults below):
%   stage = 'preflight'  list the records (expect 66), check paths and the mount
%   stage = 'raw'        copy_raw_to_local for every deployment into rawRoot
%   stage = 'L1'         rebuild L1 per record; GATE: the new L1 equals the old
%                        one except velocity at samples with vel_beamstep_k ~= 0
%                        (and the new fields); a record failing the gate is NOT
%                        saved. Writes outputs/_logs/beamstep_L1_table_2026-11-13.csv
%   stage = 'L2L4'       rebuild_combined(..., 'L2L3L4') per record, no byte
%                        backups (the pre-rebuild manifest and the server copy
%                        stand in); the October gates apply
%   stage = 'xspec'      L4_xspec with provenance for the 9 deployments
%   onlyRecs = {dep, label; ...} restricts L1 / L2L4 to a subset (resume).
%
% Before 'L1': the manifest of outputs/ (path, bytes, sha256) is written by the
% shell (see the spec, sec. 12) and TBR23's L1 and L2 are snapshotted to
% outputs/_pre_beamstep_TBR23_2026-11-13/ for the Paper 1 closure diff (2.9 GB;
% delete when that diff is accepted and the push verified).
%
% 2026-11-13. EXPLORATORY until HLB accepts the closure diff.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup_puv.m'));
if ~exist('stage', 'var'), error('set stage = ''preflight'' | ''raw'' | ''L1'' | ''L2L4'' | ''xspec'''); end
outRoot = fullfile(repoRoot, 'outputs');
if ~exist('rawRoot', 'var'), rawRoot = '/Users/holden/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_rebuild_20261113'; end
L4WANT = {'eta','ref','bispectra','boundwave','moments','reflection_free','pdf', ...
          'label','deploymentName','LATLON','doffp','shorenormal'};
XSPEC = {'IB18W','IB19S','RUBY22','SOL23','TBR23','TOR23W','TOR24S','TOR24W','TOR25S'};
fprintf('stage = %s\noutRoot = %s (-> %s)\nrawRoot = %s\n', stage, outRoot, ...
    char(java.io.File(outRoot).getCanonicalPath()), rawRoot);

%% ---- PREFLIGHT (every stage) ----
for fnName = {'PUV_raw_process','vector_beam_step_correct','vector_head_matrix','PUV_L2_spectral', ...
              'near_bed_period','bed_stress_ks','xyz_to_buoy_frame','PUV_L3_transport','PUV_L4_xspec', ...
              'save_with_provenance','build_provenance','deployment_registry','copy_raw_to_local'}
    w = which(fnName{1});
    if isempty(w) || ~startsWith(w, [repoRoot filesep])
        error('PREFLIGHT: %s resolves to "%s", not into %s', fnName{1}, w, repoRoot);
    end
end
reg = deployment_registry();
keysR = sort(keys(reg));  RECS = cell(0, 2);  names = {};
for d = 1:numel(keysR)
    fh = reg(keysR{d}); cfg = fh();
    if ismember(cfg.name, names), continue, end          % registry aliases (TOR23S -> TBR23)
    names{end+1} = cfg.name; %#ok<SAGROW>
    for k = 1:numel(cfg.instruments)
        if known_failed(cfg.instruments(k)), continue, end
        RECS(end+1, :) = {cfg.name, cfg.instruments(k).label}; %#ok<SAGROW>
    end
end
nHave = sum(cellfun(@(d, l) isfile(fullfile(outRoot,'L1',d,[l '_processed.mat'])), RECS(:,1), RECS(:,2)));
fprintf('PREFLIGHT: %d deployments, %d records (not known-failed), %d with an L1 on disk\n', ...
    numel(names), size(RECS,1), nHave);
if exist('onlyRecs', 'var') && ~isempty(onlyRecs), RUN = onlyRecs; else, RUN = RECS; end
% skipDone = true: drop records already PASS in this stage's log (resume)
if exist('skipDone', 'var') && skipDone
    switch stage
        case 'L1'
            lf = fullfile(outRoot, '_logs', 'beamstep_L1_table_2026-11-13.csv');
            if isfile(lf)
                Tl = readtable(lf, 'TextType', 'string', 'Delimiter', ',');
                done = Tl.dep(Tl.result == "PASS") + "|" + Tl.label(Tl.result == "PASS");
                RUN = RUN(~ismember(string(RUN(:,1)) + "|" + string(RUN(:,2)), done), :);
            end
        case 'L2L4'
            lf = fullfile(outRoot, '_logs', 'beamstep_L2L4_2026-11-13.log');
            if isfile(lf)
                txt = splitlines(string(fileread(lf)));
                txt = txt(contains(txt, " L2L3L4 PASS"));
                done = arrayfun(@(t) strjoin(split(strtrim(extractBefore(t, " L2L3L4")))', "|"), txt);
                RUN = RUN(~ismember(string(RUN(:,1)) + "|" + string(RUN(:,2)), done), :);
            end
    end
    fprintf('skipDone: %d records to run\n', size(RUN, 1));
end
% Records the watchdog marked HUNG (outputs/_logs/beamstep_L2L4_hung.txt, "dep|label" per
% line) are skipped unless retryHung = true, which runs ONLY them, with serial bispectra.
hungF = fullfile(outRoot, '_logs', 'beamstep_L2L4_hung.txt');
if strcmp(stage, 'L2L4') && isfile(hungF)
    hung = strtrim(splitlines(string(fileread(hungF))));  hung = hung(hung ~= "");
    key = string(RUN(:,1)) + "|" + string(RUN(:,2));
    if exist('retryHung', 'var') && retryHung
        RUN = RUN(ismember(key, hung), :);  serialL4 = true; %#ok<NASGU>
        fprintf('retryHung: %d record(s), serial bispectra\n', size(RUN, 1));
    else
        RUN = RUN(~ismember(key, hung), :);
        fprintf('skipping %d HUNG record(s)\n', numel(hung));
    end
end

switch stage
case 'preflight'
    [st, m] = system('mount | grep /Volumes/group'); fprintf('mount: %s\n', strtrim(m));
    disp(RECS)

case 'raw'
    for d = 1:numel(names)
        fh = reg(names{d}); cfg = fh();
        try, copy_raw_to_local(cfg, rawRoot);
        catch ME, fprintf(2, 'RAW FAIL %s: %s\n', names{d}, ME.message); end
    end

case 'L1'
    logf = fullfile(outRoot, '_logs', 'beamstep_L1_table_2026-11-13.csv');
    if ~isfile(logf)
        fid = fopen(logf, 'w');
        fprintf(fid, 'dep,label,result,status,Delta_mps,nDeltaEdges,nRuns,nSamples,ppm_valid,nUnconfirmed,nRejected,nUnclosed,head,headSource,coordSystem,note\n');
        fclose(fid);
    end
    for r = 1:size(RUN, 1)
        s = rebuild_L1(reg, RUN{r,1}, RUN{r,2}, outRoot, rawRoot, logf);
        fprintf('  %s\n', s);
    end

case 'L2L4'
    okN = 0;
    for r = 1:size(RUN, 1)
        [s, okRec] = rebuild_combined(reg, RUN{r,1}, RUN{r,2}, 'L2L3L4', outRoot, '', L4WANT);
        okN = okN + okRec;
        fid = fopen(fullfile(outRoot, '_logs', 'beamstep_L2L4_2026-11-13.log'), 'a'); fprintf(fid, '%s\n', s); fclose(fid);
    end
    fprintf('L2L4: %d/%d records PASS\n', okN, size(RUN, 1));

case 'xspec'
    for k = 1:numel(XSPEC)
        s = rebuild_xspec_prov(XSPEC{k}, outRoot, '');
        fid = fopen(fullfile(outRoot, '_logs', 'beamstep_L2L4_2026-11-13.log'), 'a'); fprintf(fid, '%s\n', s); fclose(fid);
    end
otherwise
    error('unknown stage %s', stage);
end

% ======================================================================
function s = rebuild_L1(reg, dep, lab, outRoot, rawRoot, logf)
% Build one L1 in memory, gate it against the L1 on disk, save with provenance.
    fprintf('\n[L1] %s/%s\n', dep, lab);
    note = '';  res = 'FAIL';  bs = struct('status','','Delta',NaN,'nDeltaEdges',0,'counts',struct());
    hd = struct('headSerial','','source','');  cs = '';
    try
        fh = reg(dep); cfg = fh(); instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        cfg.localDataRoot = fullfile(rawRoot, cfg.name);
        if ~isfolder(cfg.localDataRoot), error('no raw cache %s', cfg.localDataRoot); end
        f1 = fullfile(outRoot, 'L1', dep, [lab '_processed.mat']);
        N = PUV_raw_process(instr, cfg);
        bs = N.qc.beamstep;  hd = N.head.info;  cs = N.rotation.coordSystem;
        if isfile(f1)
            q = load(f1, 'PUV'); O = q.PUV; clear q
            hit = any(N.qc.vel_beamstep_k ~= 0, 2);
            bad = {};
            if ~isequal(N.time, O.time), bad{end+1} = 'time'; end
            for f = {'P', 'T', 'doffp', 'LATLON'}
                if ~isequaln(N.(f{1}), O.(f{1})), bad{end+1} = f{1}; end %#ok<AGROW>
            end
            for f = fieldnames(O.qc)'
                if ~isequaln(N.qc.(f{1}), O.qc.(f{1})), bad{end+1} = ['qc.' f{1}]; end %#ok<AGROW>
            end
            for f = fieldnames(O.rotation)'
                if ~isfield(N.rotation, f{1}) || ~isequaln(N.rotation.(f{1}), O.rotation.(f{1})), bad{end+1} = ['rotation.' f{1}]; end %#ok<AGROW>
            end
            vv = {N.BuoyCoord.U, O.BuoyCoord.U; N.BuoyCoord.V, O.BuoyCoord.V; N.BuoyCoord.W, O.BuoyCoord.W; ...
                  N.InstrCoord.U, O.InstrCoord.U; N.InstrCoord.V, O.InstrCoord.V};
            nm = {'U','V','W','IU','IV'};
            for j = 1:5
                a = vv{j,1};  b = vv{j,2};
                if numel(a) ~= numel(b) || ~isequaln(a(~hit), b(~hit))
                    bad{end+1} = sprintf('%s outside corrected samples', nm{j}); %#ok<AGROW>
                end
            end
            % ---- DECLINATION / ROUNDING EXTENSION (added 2026-11-14 after the first full
            % L1 pass; spec sec. 12). Accepted ONLY if every difference is in
            % rotation.mag, a LATLON that now equals the config value (or differs from it
            % only in shape), and buoy-frame U, V; instrument-frame velocity, W and all
            % else identical; and every buoy-frame change no larger than a rotation by the
            % measured declination change: |du_h| <= |u_h| |dmag| (1 + 1e-6) + 1e-14 m/s.
            % gateBreakHalfDmag = true halves dmag in the check (break test: must fail).
            okSet = {'rotation.mag', 'LATLON', 'U outside corrected samples', 'V outside corrected samples'};
            if ~isempty(bad) && all(ismember(bad, okSet)) && numel(N.time) == numel(O.time)
                dmag = N.rotation.mag - O.rotation.mag;
                if evalin('base', 'exist(''gateBreakHalfDmag'',''var'') && gateBreakHalfDmag'), dmag = dmag/2; end
                okLL = ~ismember('LATLON', bad) || (isequal(N.LATLON(:), instr.latlon(:)));
                ok = ~hit & isfinite(O.BuoyCoord.U);
                dU = hypot(N.BuoyCoord.U(ok) - O.BuoyCoord.U(ok), N.BuoyCoord.V(ok) - O.BuoyCoord.V(ok));
                lim = hypot(O.BuoyCoord.U(ok), O.BuoyCoord.V(ok)) * abs(dmag) * pi/180 * (1 + 1e-6) + 1e-14;
                okNaN = isequal(isnan(N.BuoyCoord.U), isnan(O.BuoyCoord.U));
                if okLL && okNaN && abs(dmag) <= 0.1 && all(dU <= lim)
                    note = sprintf('gate pass (declination refresh: dmag %.3g deg, LATLON changed %d, max|du_h| %.3g m/s), %d samples changed by beam steps', ...
                        N.rotation.mag - O.rotation.mag, ismember('LATLON', bad), max([dU; 0]), sum(hit));
                    bad = {};
                end
            end
            if ~isempty(bad)
                % numbers for the diagnosis (no decision is taken on them here)
                dm = NaN; ds = NaN; du = NaN; rr = NaN; dI = NaN; nN = numel(N.time); nO = numel(O.time);
                if isfield(N.rotation,'mag') && isfield(O.rotation,'mag'), dm = N.rotation.mag - O.rotation.mag; end
                if isfield(N.rotation,'sensor') && isfield(O.rotation,'sensor') && isscalar(N.rotation.sensor) && isscalar(O.rotation.sensor)
                    ds = N.rotation.sensor - O.rotation.sensor; end
                if nN == nO
                    ok = ~hit & isfinite(N.BuoyCoord.U) & isfinite(O.BuoyCoord.U);
                    d = hypot(N.BuoyCoord.U(ok) - O.BuoyCoord.U(ok), N.BuoyCoord.V(ok) - O.BuoyCoord.V(ok));
                    sp = hypot(O.BuoyCoord.U(ok), O.BuoyCoord.V(ok));
                    du = max([d; 0]);  rr = max([d ./ max(sp, 1e-9); 0]);
                    dI = max([abs(N.InstrCoord.U(ok) - O.InstrCoord.U(ok)); 0]);
                end
                note = sprintf('gate: %s | n %d vs %d, dmag %.3g deg, dsensor %.3g deg, max|du_h| %.3g m/s, max|du_h|/|u_h| %.3g (rotation by dmag predicts %.3g), max|dIU| %.3g m/s', ...
                    strjoin(bad, ';'), nN, nO, dm, ds, du, rr, abs(dm + ternary(isnan(ds), 0, ds))*pi/180, dI);
                error('L1 GATE: differs from the L1 on disk (%s): not saved', note);
            end
            if isempty(note), note = sprintf('gate pass, %d samples changed', sum(hit)); end
        else
            note = 'no previous L1';
        end
        if evalin('base', 'exist(''reportOnly'',''var'') && reportOnly')
            res = 'REPORT';  s = sprintf('%-7s %-11s L1 REPORT-ONLY (not saved) | %s', dep, lab, note);
            log_row(logf, dep, lab, res, bs, hd, cs, note, N);  return
        end
        save_with_provenance(f1, 'L1', 'PUV', N, [], instr);
        res = 'PASS';
        s = sprintf('%-7s %-11s L1 PASS | %s | %s', dep, lab, bs.status, note);
    catch ME
        if isempty(note), note = ME.message; end
        s = sprintf('%-7s %-11s L1 FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    if ~exist('N', 'var'), N = []; end
    log_row(logf, dep, lab, res, bs, hd, cs, note, N);
end

function log_row(logf, dep, lab, res, bs, hd, cs, note, N)
    c = bs.counts;  g = @(f) ternary(isstruct(c) && isfield(c, f), getf(c, f, NaN), NaN);
    nv = NaN;  if isstruct(N), nv = sum(N.qc.valid_vel); end
    fid = fopen(logf, 'a');
    fprintf(fid, '%s,%s,%s,%s,%.4f,%d,%g,%g,%.2f,%g,%g,%g,%s,%s,%s,"%s"\n', dep, lab, res, bs.status, ...
        bs.Delta, getf(bs, 'nDeltaEdges', 0), g('nRuns'), g('nSamples'), 1e6*g('nSamples')/nv, ...
        g('nUnconfirmedSamples'), g('nRejectedOneZeroEdge'), g('nLongOffsets'), ...
        getf(hd, 'headSerial', ''), getf(hd, 'source', ''), cs, strrep(note, '"', ''''));
    fclose(fid);
end

function [s, okRec] = rebuild_combined(reg, dep, lab, lv, outRoot, bk, L4WANT)
% One record of the combined pass, all-or-nothing: every level is built and
% checked in memory first; only if all pass are they saved (parents first),
% stamped (embedded prov + sidecar with file_sha256) and reloaded.
    fprintf('\n[combined %s] %s/%s\n', lv, dep, lab); okRec = false;
    try
        fn = reg(dep); cfg = fn(); instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        Tvalid = l1_qc_opts(cfg).Tvalid;
        f1 = fullfile(outRoot,'L1',dep,[lab '_processed.mat']); f2 = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        f3 = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);        f4 = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
        todo = {f3}; if contains(lv,'L2'), todo{end+1} = f2; end; if contains(lv,'L4'), todo{end+1} = f4; end
        backup_files(todo, outRoot, bk);
        q = load(f2,'L2'); L2old = q.L2; q = load(f3,'L3'); L3old = q.L3; clear q
        PUV = [];
        if contains(lv,'L2') || contains(lv,'L4'), q = load(f1,'PUV'); PUV = q.PUV; clear q, end
        msgs = {};

        % ---- L2 (fillmissing-affected records) ----
        if contains(lv,'L2')
            L2 = PUV_L2_spectral(PUV, instr, struct());
            if ~isequal(L2.time, L2old.time), error('L2 time grid changed: not saved'); end
            if ~isequaln(L2.shorenormal, L2old.shorenormal), error('L2 shorenormal %.4g vs %.4g (CDIP fetch failed?): not saved', L2.shorenormal, L2old.shorenormal); end
            v = L2.segValid & L2old.segValid; dHs = abs(L2.Hs(v) - L2old.Hs(v));
            msgs{end+1} = sprintf('L2 segValid %d->%d, Hs moved on %d segs (max %.3g m)', sum(L2old.segValid), sum(L2.segValid), sum(dHs > 1e-12), max([dHs; 0]));
        else
            L2 = L2old;
        end

        % ---- L3: ALWAYS a full rebuild (bands, storms, transport, currents), so every
        %      catalog L3 comes from one code version with seeded t_tide and NOAA depth ----
        L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2, struct('Tvalid', Tvalid)); L3 = PUV_L3_currents(L3, L2, l3_currents_opts(cfg));
        [okRef, why, evMsg] = same_storm_reference(L3, L3old, contains(lv,'L2'));
        if ~okRef, error('L3 storm reference differs from before (%s): not saved', why); end
        if ~isempty(evMsg), msgs{end+1} = evMsg; end
        if ~contains(lv,'L2')
            % L2 unchanged, so bands, storms and the L2-derived transport fields
            % (Fb, shields, tau_*, Ub, uMean, vMean, Fb_cum) must not move. Allowed to
            % change: the settling-velocity-dependent transport fields, and the
            % tidal/subtidal fits (t_tide is seeded from 2026-10-09).
            [~, bad] = compare_struct(L3old, L3, {'transport_params','rouse','rouse_D16','rouse_D50','rouse_D84', ...
                'ws','theta_cr','tau_cr','nu','T_used','mobilized','tidal','subtidal','mop','events','prov'}, '');
            if ~isempty(bad), error('L3 fields that must not move did (bands/storms/L2-derived): %s: not saved', strjoin(bad, ', ')); end
            dT = max(abs(L3.tidal.depth_pred(:) - L3old.tidal.depth_pred(:)), [], 'omitnan');
            msgs{end+1} = sprintf('bands/storms unchanged; tidal.depth_pred max change %.3g m (seeded t_tide)', dT);
        end
        % the tidal depth fit must come from the NOAA predictions (as in every
        % existing L3 but TOR24W/MOP586_10m); 't_tide' means the download failed
        if ~isfield(L3, 'tidal') || ~isfield(L3.tidal, 'depth_source') || ~strcmp(L3.tidal.depth_source, 'NOAA')
            error('L3 tidal depth_source is %s, not NOAA (download failed?): not saved', ...
                char(string(getf(getf(L3,'tidal',struct()),'depth_source','absent'))));
        end
        tp = L3.transport_params; vv = L2.segValid(:) & isfinite(L3.ws(:));
        wsChk = settling_velocity(tp.D50, tp.rho_s, 1025, L3.nu(:));
        nuChk = seawater_nu(L3.T_used(:));
        [~, c1d, c2d] = settling_velocity(2.5e-4, 2650, 1025, 1e-6);
        e1 = max(abs(L3.ws(vv) - wsChk(vv)) ./ wsChk(vv)); e2 = max(abs(L3.nu(vv) - nuChk(vv)) ./ nuChk(vv));
        if ~(e1 <= 1e-12 && e2 <= 1e-12 && tp.ws_C1 == c1d && tp.ws_C2 == c2d && all(isfinite(L3.T_used(vv))))
            error('L3 gate failed: ws closure %.1e, nu closure %.1e, C1 %g C2 %g: not saved', e1, e2, tp.ws_C1, tp.ws_C2);
        end
        mobOld = mean(L3old.mobilized(L2.segValid)); mobNew = mean(L3.mobilized(L2.segValid));
        msgs{end+1} = sprintf('L3 ws %.5f->%.5f (x%.4f), theta_cr %.5f->%.5f, mobilized %.1f%%->%.1f%%, nu med %.3e (T: %d seg, %d fallback), D_source %s', ...
            L3old.transport_params.ws, tp.ws, tp.ws / L3old.transport_params.ws, L3old.transport_params.theta_cr, tp.theta_cr, ...
            100*mobOld, 100*mobNew, tp.nu_median, tp.T_source.segment_Tmean, tp.T_source.record_fallback, tp.D_source);

        % ---- L4 ----
        if contains(lv,'L4')
            L4 = build_L4(PUV, L2);
            [l4map, info] = l4_l2_index_map(L2, L4);
            ok = ~isnan(l4map(:)) & L2.segValid(:);
            dd = max(abs(L4.eta.depth(l4map(ok)) - L2.depth(ok)));
            miss = setdiff(L4WANT, fieldnames(L4)); qz = ztest_record_flag(L2.ztest_SS, L2.segValid);
            % Fail on a NEW Z flag only: a record already flagged before this run
            % (e.g. RUBY22/MOP582_30m, dead transducer, in excluded_records) stays
            % flagged. (Approved by HLB 2026-10-13.)
            qzOld = ztest_record_flag(L2old.ztest_SS, L2old.segValid);
            zNew = strcmp(qz.status, 'FLAG') && ~strcmp(qzOld.status, 'FLAG');
            if ~info.identity || ~(dd <= 1e-9) || ~isempty(miss) || zNew
                error('L4 gate failed: aligned %d, eta.depth %.1e, missing %s, Z %s: not saved', info.identity, dd, strjoin(miss, ','), qz.status);
            end
            msgs{end+1} = sprintf('L4 aligned, eta.depth=L2 (%.0e), Z %s', dd, qz.status);
        end

        % ---- every level passed its gate: save, parents first, so each stamp
        %      records its parent's NEW build_id (all-or-nothing per record) ----
        if contains(lv,'L2'), stamp_save(f2, 'L2', L2, struct('level','L1','path',f1), instr); end
        stamp_save(f3, 'L3', L3, struct('level','L2','path',f2), instr);
        if contains(lv,'L4'), stamp_save(f4, 'L4', L4, struct('level','L2','path',f2), instr); end
        okRec = true;
        s = sprintf('%-7s %-11s %-6s PASS | %s', dep, lab, lv, strjoin(msgs, ' | '));
    catch ME
        s = sprintf('%-7s %-11s %-6s FAILED: %s', dep, lab, lv, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    fprintf('  %s\n', s);
end


function stamp_save(f, varName, S, parents, instr)
% stamp (embedded + sidecar), save, reload-check
    S = rmfield_safe(S, 'prov');
    prov = build_provenance(varName, S, parents, instr);
    S.prov = prov;
    tmpS.(varName) = S; %#ok<STRNU>
    save(f, '-struct', 'tmpS', '-v7.3');
    q = load(f, varName);
    if ~isequaln(q.(varName), S), error('reloaded %s differs from the one saved: %s', varName, f); end
    write_prov_sidecar(f, prov);
end


function s = rebuild_xspec_prov(dep, outRoot, bk)
    fprintf('\n[xspec+prov] %s\n', dep);
    try
        xf = fullfile(outRoot,'L4_xspec',dep,'xspec.mat');
        backup_files({xf}, outRoot, bk);
        l4 = dir(fullfile(outRoot,'L4',dep,'*_L4.mat'));
        paths = arrayfun(@(z) fullfile(z.folder,z.name), l4, 'UniformOutput', false);
        L4xs = PUV_L4_xspec(paths, struct());
        prov = build_provenance('L4_xspec', L4xs, struct('level', repmat({'L4'},1,numel(paths)), 'path', paths'));
        L4xs.prov = prov; save(xf, 'L4xs', '-v7.3');
        q = load(xf, 'L4xs'); if ~isequaln(q.L4xs, L4xs), error('reload mismatch'); end
        write_prov_sidecar(xf, prov);
        s = sprintf('%-7s xspec rebuilt with provenance, %d pairs', dep, numel(L4xs.pairs));
    catch ME
        s = sprintf('%-7s xspec FAILED: %s', dep, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    fprintf('  %s\n', s);
end


function [ok, why, evMsg] = same_storm_reference(N, O, l2Rebuilt)
% The CDIP storm reference must carry the same DATA as before (a silent CDIP
% fallback drops or changes L3.mop). Compared field by field on the data, so a
% field added by newer code (e.g. mop.source) is not a difference.
% The storm EVENTS are computed from L2.Hs. When L2 was rebuilt (l2Rebuilt) they
% may legitimately change (2026-10-13: the edge-gap fill fix moves Hs at storm
% peaks), so they are reported, not gated; the reference data stays a hard gate.
% When L2 was not rebuilt, the events must be identical. (Approved by HLB 2026-10-13.)
    if nargin < 3, l2Rebuilt = false; end
    ok = true; why = ''; evMsg = '';
    if isfield(O, 'mop') && ~isfield(N, 'mop'), ok = false; why = 'reference missing (CDIP fetch failed?)'; return, end
    if isfield(O, 'mop')
        for f = {'time','Hs','Tp','Dp','station','depth'}
            if isfield(O.mop, f{1}) && (~isfield(N.mop, f{1}) || ~isequaln(N.mop.(f{1}), O.mop.(f{1})))
                ok = false; why = ['mop.' f{1} ' differs']; return
            end
        end
    end
    if l2Rebuilt
        evMsg = sprintf('storm events %d -> %d (recomputed from rebuilt L2)', numel(O.events), numel(N.events));
        if numel(N.events) == numel(O.events) && ~isempty(O.events) && isfield(O.events, 'peak_Hs')
            d = abs([N.events.peak_Hs] - [O.events.peak_Hs]);
            evMsg = sprintf('%s, peak_Hs changed on %d (max %.3g m)', evMsg, sum(d > 1e-12), max([d 0]));
        end
        return
    end
    if numel(N.events) ~= numel(O.events), ok = false; why = sprintf('%d events, was %d', numel(N.events), numel(O.events)); return, end
    if ~isempty(O.events)
        for f = fieldnames(O.events)'
            if ~isequaln({N.events.(f{1})}, {O.events.(f{1})}), ok = false; why = ['events.' f{1} ' differs']; return, end
        end
    end
end


function L4 = build_L4(PUV, L2)
    L4 = struct();
    L4.eta = PUV_L4_eta(PUV, L2);
    L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
    % serialL4 (base workspace, set by retryHung): bispectra without the parfor that hangs
    usePar = ~evalin('base', 'exist(''serialL4'',''var'') && serialL4');
    L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, struct('useParallel', usePar));
    L4.moments = PUV_L4_moments(L2);
    L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
    L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);
    L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
    L4.label = PUV.label; L4.deploymentName = PUV.deploymentName;
    L4.LATLON = PUV.LATLON; L4.doffp = PUV.doffp; L4.shorenormal = L2.shorenormal;
    if isfield(L2,'mopStation'), L4.mopStation = L2.mopStation; end
    L4.builtAt = datetime('now');
end


function [n, bad] = compare_struct(A, B, skip, prefix)
% Count fields compared and list any (outside skip) that differ by > 1e-12
% relative, or differ in presence, class or size.
    n = 0; bad = {};
    fa = fieldnames(A); fb = fieldnames(B);
    for f = setdiff(union(fa, fb), skip)'
        k = f{1}; n = n + 1;
        if ~isfield(A,k) || ~isfield(B,k), bad{end+1} = [prefix k ' (presence)']; continue, end %#ok<AGROW>
        a = A.(k); b = B.(k);
        if isnumeric(a) && isnumeric(b) && isequal(size(a), size(b))
            a = double(a); b = double(b);
            same = isequal(isnan(a), isnan(b)) && ...
                   all(abs(a(~isnan(a)) - b(~isnan(b))) <= 1e-12 * max(abs(a(~isnan(a))), 1e-300));
        else
            same = isequaln(a, b);
        end
        if ~same, bad{end+1} = [prefix k]; end %#ok<AGROW>
    end
end


function S = rmfield_safe(S, f), if isfield(S, f), S = rmfield(S, f); end, end

function v = getf(s, f, d), if isstruct(s) && isfield(s, f), v = s.(f); else, v = d; end, end

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end

function backup_files(files, outRoot, bkRoot)
% Copy each existing file to the same relative path under bkRoot. A copy made
% now is size-checked; an existing backup is the pre-change original and kept.
% 2026-11-13 (beam-step rebuild): an EMPTY bkRoot means no byte backup; the
% pre-rebuild manifest (path, bytes, sha256) and the server copy stand in.
    if isempty(bkRoot), return, end
    for f = files
        if ~isfile(f{1}), continue, end
        dst = fullfile(bkRoot, extractAfter(f{1}, [outRoot filesep]));
        if isfile(dst), continue, end
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        % copy to a temporary name and rename only when complete, so a run
        % killed mid-copy can never leave a partial file that a later run
        % would accept as the pre-change original
        tmp = [dst '.part'];
        if isfile(tmp), delete(tmp); end
        copyfile(f{1}, tmp);
        a = dir(f{1}); b = dir(tmp);
        if a.bytes ~= b.bytes, error('backup size mismatch for %s', f{1}); end
        movefile(tmp, dst);
    end
end

