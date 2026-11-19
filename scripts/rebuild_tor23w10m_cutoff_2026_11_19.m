% REBUILD_TOR23W10M_CUTOFF_2026_11_19  Move the TOR23W MOP586_10m velocity cutoff
% (instr.velInvalidFrom) from 2023-12-30 15:29 UTC to 2023-12-30 03:00 UTC and
% rebuild that record's L2, L3, L4 and the TOR23W L4_xspec (HLB decision 2026-11-19).
%
% Why: the 2026-11-13 cutoff came from the ratio of sea-swell Ub at 10 m to 15 m
% (reference median 1.377, 5-95% band 1.287-1.463 over 1,029 hours; failure 0.39).
% Applying the same rule to the six paired hours of 30 December before 15:29
% (Paper_2/docs/RESULTS_puv_alt_rerun_2026-11-19.md, addendum) gives 1.31-1.38 for the
% segments centred 00:30-02:30 and 0.24-0.27 for those centred 04:30-06:30; 03:30 has
% no 15 m pair. L2 segments are one hour (7200 samples at 2 Hz) centred on :30, so a
% cutoff at 03:00 keeps the last good segment (02:00-03:00) whole and removes 03:00 on.
% L1 is not rebuilt: the cutoff is applied in L2 (PUV_L2_spectral) and, for the L4
% modules that read L1 velocity, by shared/l1_velocity_gap_mask.m.
%
% Run from the repo root, one stage at a time:
%   stage = 'L2L4'                 build, gate, then save L2, L3, L4 with provenance
%   stage = 'L2L4'; breakEarly=1   break test: cutoff at 02:00 instead; G2 MUST FAIL;
%                                  never saves
%   stage = 'xspec'                rebuild outputs/L4_xspec/TOR23W/xspec.mat with provenance
%
% GATES (fixed 2026-11-19 before any rebuild; never loosened after a failure)
%   G0 the config cutoff is 2023-12-30 03:00:00 UTC (skipped for the break test).
%   G2 L2: time, shorenormal, segValid and segValid_p identical. On every segment
%      centred before 02:31 (span ending by 03:00) every L2 field, sliced on its
%      segment dimension, equal within TOL. No segment changes segValid_vel
%      false -> true. Every segment that changes true -> false is centred between
%      03:00 and 15:30, and at least one does. Every segment centred after 03:00 has
%      segValid_vel false.
%   G3 L3: every field outside {uMean, vMean, tidal, subtidal, prov} equal within TOL
%      (storm events included: L2 Hs is pressure-based and unchanged).
%   G4 L4: identity alignment; eta and bispectra (pressure-based) equal within TOL.
%      ref, pdf, boundwave, reflection_free and moments are reported, not gated.
%   TOL: |a - b| <= 1e-9 max(|a|,|b|) + 1e-12 max|a|, identical NaN and Inf placement.
%   POST HOC G3 AMENDMENT (HLB 2026-11-19, after the first real run failed G3): L2.Tmean is
%      computed for velocity-only segments, so two segments of 30 December (04:30, 05:30;
%      13.1 and 10.9 degC from the failed sensor, inside Tvalid [9 26]) left the record-
%      median fallback temperature when they lost segValid_vel (17.0471 -> 17.0476 degC).
%      The fallback reaches T_used, nu, ws, theta_cr and tau_cr on 484 segments, all with
%      segValid = 0. Amended G3: those five fields equal within TOL on every segValid
%      segment; the fallback may move by < 0.01 degC; every other T_source and
%      transport_params field, the storm events and every other L3 field equal as before.
%      A diagnostic rebuild of L3 from the unchanged L2 with current code reproduced the
%      stored L3 exactly (no drift). The events/mop difference in the first run did not
%      recur in that diagnostic; it is attributed to CDIP flaking just after its outage,
%      and the gate on events is unchanged.
%   POST HOC G2 CORRECTION (2026-11-19, found by the break test before any real run):
%      L2.velGap.nCutoff and L2.velGap.velInvalidFrom store the cutoff itself, so
%      comparing them on the before-cutoff segments made G2 impossible to pass. They
%      are excluded from that comparison and checked exactly instead: velInvalidFrom
%      equals the cutoff applied, nCutoff grows, nUnconfirmed is unchanged. Not a
%      loosening of any tolerance. The same break-test run failed G2 also on
%      shorenormal, because CDIP THREDDS returned 504 and L2 fell back to buoy
%      coordinates; the rebuild waits for CDIP (G2 refuses any shorenormal change).
%
% Backup before saving: outputs/_pre_tor23w10m_cutoff_backup_2026-11-19/ (L2, L3, L4,
% xspec; about 975 MB). EXPIRES: delete once the rebuild is verified and pushed to
% reefbreak, and record the deletion in the catalog-change entry.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup_puv.m'));
if ~exist('stage', 'var'), error('set stage = ''L2L4'' | ''xspec'''); end
if ~exist('breakEarly', 'var'), breakEarly = 0; end
outRoot = fullfile(repoRoot, 'outputs');
dep = 'TOR23W'; lab = 'MOP586_10m';
newCut = datetime(2023,12,30,3,0,0,'TimeZone','UTC');
oldCut = datetime(2023,12,30,15,29,0,'TimeZone','UTC');
bkRoot = fullfile(outRoot, '_pre_tor23w10m_cutoff_backup_2026-11-19');
logF = fullfile(outRoot, '_logs', 'tor23w10m_cutoff_2026-11-19.log');

reg = deployment_registry(); fh = reg(dep); cfg = fh();
instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
f1 = fullfile(outRoot,'L1',dep,[lab '_processed.mat']); f2 = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
f3 = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);        f4 = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
fx = fullfile(outRoot,'L4_xspec',dep,'xspec.mat');

switch stage
case 'L2L4'
    if breakEarly
        instr.velInvalidFrom = datetime(2023,12,30,2,0,0,'TimeZone','UTC');
        fprintf('BREAK TEST: cutoff 02:00 UTC; G2 must fail; nothing is saved\n');
    else
        if ~isequal(instr.velInvalidFrom, newCut)
            error('G0: config velInvalidFrom is %s, expected %s', string(instr.velInvalidFrom), string(newCut));
        end
    end
    Tvalid = l1_qc_opts(cfg).Tvalid;
    q = load(f1,'PUV'); PUV = q.PUV;
    q = load(f2,'L2'); L2o = q.L2; q = load(f3,'L3'); L3o = q.L3; q = load(f4,'L4'); L4o = q.L4; clear q
    msgs = {};
    try
        % ---- G2 ----
        L2 = PUV_L2_spectral(PUV, instr, struct());
        bad = {};
        if ~isequal(L2.time, L2o.time), bad{end+1} = 'time'; end
        if ~isequaln(L2.shorenormal, L2o.shorenormal), bad{end+1} = 'shorenormal'; end
        if ~isequal(L2.segValid, L2o.segValid), bad{end+1} = 'segValid'; end
        if ~isequal(L2.segValid_p, L2o.segValid_p), bad{end+1} = 'segValid_p'; end
        t = L2.time(:); if isempty(t.TimeZone), t.TimeZone = 'UTC'; end
        nSeg = numel(t);
        A = find(t < datetime(2023,12,30,2,31,0,'TimeZone','UTC'));
        bad = [bad, cmp_subset(L2o, L2, A, nSeg, {'prov','velGap'}, 'L2.')];
        if ~isequal(L2.velGap.velInvalidFrom, instr.velInvalidFrom), bad{end+1} = 'velGap.velInvalidFrom is not the cutoff applied'; end
        if ~(L2.velGap.nCutoff > L2o.velGap.nCutoff), bad{end+1} = 'velGap.nCutoff did not grow'; end
        if ~isequal(L2.velGap.nUnconfirmed, L2o.velGap.nUnconfirmed), bad{end+1} = 'velGap.nUnconfirmed changed'; end
        vo = logical(L2o.segValid_vel(:)); vn = logical(L2.segValid_vel(:));
        gained = find(~vo & vn); lost = find(vo & ~vn);
        if ~isempty(gained), bad{end+1} = sprintf('%d segments gained segValid_vel', numel(gained)); end
        if isempty(lost), bad{end+1} = 'no segment lost segValid_vel'; end
        if any(t(lost) < newCut | t(lost) > datetime(2023,12,30,15,30,0,'TimeZone','UTC'))
            bad{end+1} = 'a lost segment lies outside 03:00-15:30'; end
        if any(vn(t > newCut)), bad{end+1} = 'velocity-valid segment after 03:00'; end
        if ~isempty(bad), error('G2 L2 gate: %s', strjoin(bad, ', ')); end
        if breakEarly, error('BREAK TEST PASSED G2 (it must not)'); end
        msgs{end+1} = sprintf('G2 ok: %d segments unchanged before 02:31 UTC; %d lost segValid_vel (%s to %s); segValid unchanged (%d valid)', ...
            numel(A), numel(lost), string(t(lost(1))), string(t(lost(end))), sum(L2.segValid));

        % ---- G3 ----
        L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2, struct('Tvalid', Tvalid)); L3 = PUV_L3_currents(L3, L2, l3_currents_opts(cfg));
        TF = {'T_used','nu','ws','theta_cr','tau_cr'};
        bad = cmp_tol(L3o, L3, [{'uMean','vMean','tidal','subtidal','prov','transport_params'}, TF], 'L3.');
        bad = [bad, cmp_tol(rmfield(L3o.transport_params,'T_source'), rmfield(L3.transport_params,'T_source'), {}, 'L3.transport_params.')];
        bad = [bad, cmp_tol(L3o.transport_params.T_source, L3.transport_params.T_source, {'record_fallback_value'}, 'L3.transport_params.T_source.')];
        dFb = abs(L3.transport_params.T_source.record_fallback_value - L3o.transport_params.T_source.record_fallback_value);
        if ~(dFb < 0.01), bad{end+1} = sprintf('fallback T moved %.4f degC', dFb); end
        sv = find(L2.segValid(:)); nInv = 0;
        for j = 1:numel(TF)
            a = L3o.(TF{j})(:); c = L3.(TF{j})(:);
            if ~isequal(size(a), size(c)) || ~within_tol(a(sv), c(sv)), bad{end+1} = ['L3.' TF{j} ' on valid segments']; end %#ok<AGROW>
            nInv = max(nInv, nnz(~(a == c | (isnan(a) & isnan(c)))));
        end
        if ~isempty(bad), error('G3 L3 gate: %s', strjoin(bad, ', ')); end
        msgs{end+1} = sprintf('G3 temperature fields: fallback T %.4f -> %.4f degC; %d invalid segments moved; %d valid segments equal', ...
            L3o.transport_params.T_source.record_fallback_value, L3.transport_params.T_source.record_fallback_value, nInv, numel(sv));
        movedL3 = cmp_tol(L3o, L3, {'prov'}, 'L3.');
        msgs{end+1} = sprintf('G3 ok; L3 velocity fields moved: %s', strjoin(movedL3, ','));

        % ---- G4 ----
        L4 = build_L4(PUV, L2, instr);
        [~, info] = l4_l2_index_map(L2, L4);
        bad = {};
        if ~info.identity, bad{end+1} = 'not identity-aligned'; end
        bad = [bad, cmp_tol(struct('eta', L4o.eta, 'bispectra', L4o.bispectra), struct('eta', L4.eta, 'bispectra', L4.bispectra), {}, 'L4.')];
        if ~isempty(bad), error('G4 L4 gate: %s', strjoin(bad, ', ')); end
        movedL4 = cmp_tol(L4o, L4, {'eta','bispectra','builtAt','prov'}, '');
        msgs{end+1} = sprintf('G4 ok; L4 fields moved (velocity modules, reported): %s', strjoin(unique(regexprep(movedL4, '\..*', '')), ','));
    catch ME
        s = sprintf('%s %s cutoff L2L3L4 FAILED: %s', dep, lab, ME.message);
        fprintf(2, '%s\n', s);
        if ~breakEarly, append_log(logF, s); end
        return
    end

    % ---- backup, then save parents first ----
    for f = {f2, f3, f4, fx}
        rel = extractAfter(f{1}, [outRoot filesep]); dst = fullfile(bkRoot, rel);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        if ~isfile(dst), copyfile(f{1}, dst); copyfile([f{1} '.prov.json'], [dst '.prov.json']); end
    end
    stamp_save(f2, 'L2', L2, struct('level','L1','path',f1), instr);
    stamp_save(f3, 'L3', L3, struct('level','L2','path',f2), instr);
    stamp_save(f4, 'L4', L4, struct('level','L2','path',f2), instr);
    s = sprintf('%s %s cutoff L2L3L4 PASS | %s', dep, lab, strjoin(msgs, ' | '));
    fprintf('%s\n', s); append_log(logF, s);

case 'xspec'
    lg = fileread(logF);
    if ~contains(lg, 'cutoff L2L3L4 PASS'), error('xspec stage refused: no L2L3L4 PASS in %s', logF); end
    s = rebuild_xspec_prov(dep, outRoot);
    append_log(logF, s);
otherwise
    error('unknown stage %s', stage);
end

% ======================================================================
function append_log(f, s)
    fid = fopen(f, 'a'); fprintf(fid, '%s  %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), s); fclose(fid);
end

function bad = cmp_subset(A, B, idx, nSeg, skip, prefix)
% Like cmp_tol, but numeric arrays and cells with a dimension of length nSeg are
% compared only on the segments idx along that dimension.
    bad = {};
    for f = setdiff(union(fieldnames(A), fieldnames(B)), skip)'
        k = f{1};
        if ~isfield(A, k) || ~isfield(B, k), bad{end+1} = [prefix k ' (presence)']; continue, end %#ok<AGROW>
        a = A.(k); b = B.(k);
        if isstruct(a) && isstruct(b) && isscalar(a) && isscalar(b)
            bad = [bad, cmp_subset(a, b, idx, nSeg, {}, [prefix k '.'])]; %#ok<AGROW>
            continue
        end
        if ~isequal(size(a), size(b)), bad{end+1} = [prefix k ' (size)']; continue, end %#ok<AGROW>
        d = find(size(a) == nSeg, 1, 'last');
        if ~isempty(d) && (isnumeric(a) || islogical(a) || iscell(a))
            sub = repmat({':'}, 1, ndims(a)); sub{d} = idx;
            a = a(sub{:}); b = b(sub{:});
        end
        if (isnumeric(a) || islogical(a)) && (isnumeric(b) || islogical(b))
            if ~isequal(class(a), class(b)) || ~within_tol(a, b), bad{end+1} = [prefix k]; end %#ok<AGROW>
        elseif ~isequaln(a, b)
            bad{end+1} = [prefix k]; %#ok<AGROW>
        end
    end
end

function bad = cmp_tol(A, B, skip, prefix)
    bad = {};
    for f = setdiff(union(fieldnames(A), fieldnames(B)), skip)'
        k = f{1};
        if ~isfield(A, k) || ~isfield(B, k), bad{end+1} = [prefix k ' (presence)']; continue, end %#ok<AGROW>
        a = A.(k); b = B.(k);
        if isstruct(a) && isstruct(b) && isscalar(a) && isscalar(b)
            bad = [bad, cmp_tol(a, b, {}, [prefix k '.'])]; %#ok<AGROW>
        elseif (isnumeric(a) || islogical(a)) && (isnumeric(b) || islogical(b))
            if ~isequal(size(a), size(b)) || ~isequal(class(a), class(b)) || ~within_tol(a, b), bad{end+1} = [prefix k]; end %#ok<AGROW>
        elseif ~isequaln(a, b)
            bad{end+1} = [prefix k]; %#ok<AGROW>
        end
    end
end

function ok = within_tol(a, b)
    a = double(a(:)); b = double(b(:));
    if ~isequal(isnan(a), isnan(b)), ok = false; return, end
    ia = isinf(a); ib = isinf(b);
    if ~isequal(ia, ib) || ~isequal(a(ia), b(ib)), ok = false; return, end
    m = isfinite(a); a = a(m); b = b(m);
    if isempty(a), ok = true; return, end
    ok = all(abs(a - b) <= 1e-9 * max(abs(a), abs(b)) + 1e-12 * max(abs(a)));
end

function stamp_save(f, varName, S, parents, instr)
    if isfield(S, 'prov'), S = rmfield(S, 'prov'); end
    prov = build_provenance(varName, S, parents, instr);
    S.prov = prov;
    tmpS.(varName) = S; %#ok<STRNU>
    fp = [f(1:end-4) '.partial.mat'];
    save(fp, '-struct', 'tmpS', '-v7.3');
    q = load(fp, varName);
    if ~isequaln(q.(varName), S), delete(fp); error('reloaded %s differs from the one saved: %s', varName, fp); end
    clear q
    [ok, msg] = movefile(fp, f, 'f');
    if ~ok, error('rename %s -> %s failed: %s', fp, f, msg); end
    write_prov_sidecar(f, prov);
end

function L4 = build_L4(PUV, L2, instr)
% As PUV_L4_driver since 8295c13 (copied from rebuild_heading_log_2026_11_17.m).
    velGap = l1_velocity_gap_mask(PUV, instr);
    if any(velGap)
        PUV.BuoyCoord.U(velGap) = NaN; PUV.BuoyCoord.V(velGap) = NaN; PUV.BuoyCoord.W(velGap) = NaN;
    end
    L4 = struct();
    L4.eta = PUV_L4_eta(PUV, L2);
    L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
    L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, struct('useParallel', false));
    L4.moments = PUV_L4_moments(L2);
    L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
    L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);
    L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
    L4.label = PUV.label; L4.deploymentName = PUV.deploymentName;
    L4.LATLON = PUV.LATLON; L4.doffp = PUV.doffp; L4.shorenormal = L2.shorenormal;
    if isfield(L2,'mopStation'), L4.mopStation = L2.mopStation; end
    L4.builtAt = datetime('now');
end

function s = rebuild_xspec_prov(dep, outRoot)
% Copied from rebuild_heading_log_2026_11_17.m.
    fprintf('\n[xspec+prov] %s\n', dep);
    try
        xf = fullfile(outRoot,'L4_xspec',dep,'xspec.mat');
        q = load(xf, 'L4xs'); old = q.L4xs; clear q
        l4 = dir(fullfile(outRoot,'L4',dep,'*_L4.mat'));
        paths = arrayfun(@(z) fullfile(z.folder,z.name), l4, 'UniformOutput', false);
        L4xs = PUV_L4_xspec(paths, struct());
        moved = cmp_tol(rmfield(old, intersect(fieldnames(old), {'prov','builtAt'})), ...
                        rmfield(L4xs, intersect(fieldnames(L4xs), {'prov','builtAt'})), {}, '');
        prov = build_provenance('L4_xspec', L4xs, struct('level', repmat({'L4'},1,numel(paths)), 'path', paths'));
        L4xs.prov = prov; save(xf, 'L4xs', '-v7.3');
        q = load(xf, 'L4xs'); if ~isequaln(q.L4xs, L4xs), error('reload mismatch'); end
        write_prov_sidecar(xf, prov);
        s = sprintf('%-7s xspec PASS rebuilt with provenance, %d pairs; fields moved: %s', dep, numel(L4xs.pairs), ternary(isempty(moved), 'none', strjoin(moved, ',')));
    catch ME
        s = sprintf('%-7s xspec FAILED: %s', dep, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    fprintf('  %s\n', s);
end

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
