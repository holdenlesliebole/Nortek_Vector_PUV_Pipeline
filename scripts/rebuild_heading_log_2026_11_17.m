% REBUILD_HEADING_LOG_2026_11_17  L1-L4 rebuild of the 12 formerly disputed-
% heading records on their field-logged headings (HLB decision 2026-11-16).
%
% Built on the beam-step catalog (2026-11-17.1, commit 30cbe00). The ONLY
% intended change is the config heading of these 12 records, compass median ->
% logged value. In the XYZ branch the true bearing of +x is heading + D, so a
% heading change Delta moves every velocity sample's bearing by exactly Delta
% (declination D is unchanged: same LATLON and dates) and L2 meanDir by -Delta.
% Nothing that does not depend on velocity direction may change. The gates
% below were written, with their tolerances, BEFORE any of these records was
% rebuilt. The beam-step L1 gate (rebuild_beamstep_2026_11_13.m) would refuse
% this change by design, because a rotation changes U, V and rotation.sensor.
%
% Run ONE stage at a time from the repo root (outputs/ -> the local catalog):
%   stage = 'preflight'  check config headings, current L1 headings against the
%                        predictions, the mount and code paths; writes nothing
%   stage = 'raw'        cache ONLY these 12 instruments' raw files in rawRoot,
%                        each verified against the server by size
%   stage = 'L1'         rebuild L1; gate G1 (below); a record failing it is not saved
%   stage = 'L2L4'       L2, L3, L4 per record, all-or-nothing; gates G2-G4
%   stage = 'gapL4'      L4-only rebuild of every record in the 12 deployments of
%                        docs/catalog_changes/2026-11-17_l4_velocity_gaps.md that is
%                        NOT one of the 12 heading records (their L4 is built in
%                        'L2L4'); gate G5 (below)
%   stage = 'xspec'      L4_xspec with provenance for TOR24W, TOR25S, RUBY22,
%                        SOL23 and TOR23W (every deployment with an xspec whose
%                        L4 parents this release rebuilds)
%   onlyRecs = {dep, label; ...}  restricts L1 / L2L4 (resume); skipDone = true
%                        drops records already PASS in that stage's log.
%   gateBreakShift = x   (L1 only, never saves) adds x deg to the predicted
%                        shift: the break test. G1 must FAIL for x = 0.01.
%
% PREDICTIONS (deg magnetic; old = rotation.sensor of the 2026-11-17.1 L1, read
% 2026-11-17 by h5read; new = config; shift = new - old = bearing shift of
% every velocity sample; L2 meanDir shift = -shift):
%   TOR17D MOP591_9m  100.5 ->  66.7  -33.8      CDF15A MOP677_9m   47.6 -> 62.2  +14.6
%   TOR14C MOP591_9m   76.0 -> 101.5  +25.5      CDF15C MOP677_9m   47.5 -> 62.2  +14.7
%   TOR17B MOP591_9m   87.6 ->  66.7  -20.9      COR17D MOP158_9m   49.1 -> 28.9  -20.2
%   TOR15D MOP591_9m   26.7 ->  43.0  +16.3      TOR24W MOP586_10m  71.9 -> 59.5  -12.4
%   TOR15A MOP591_9m   48.7 ->  63.6  +14.9      TOR25S MOP586_15m  46.1 -> 34.2  -11.9
%   TOR14B MOP591_9m   90.0 -> 101.5  +11.5      SIO25E SIO_6m      99.3 -> 88.0  -11.3
%
% GATES (fixed 2026-11-17 before any rebuild; never loosened after a failure)
%   G1 L1: time, P, T, W, InstrCoord U/V, doffp, LATLON, head, every qc field,
%      every rotation field but sensor, and every other top-level field
%      bitwise identical (isequaln); rotation.sensor == config heading; old
%      sensor within 0.05 deg of the listed prediction; NaN pattern of U, V
%      identical; on samples with old speed > 0.01 m/s, max|bearing shift -
%      predicted| <= 1e-6 deg; max|speed change| <= 1e-9 m/s.
%   G2 L2: time, segValid, shorenormal identical; every field outside DIR2
%      equal within TOL (below); meanDir shift = -predicted within 1e-6 deg on
%      valid segments; (uMean, vMean) bearing shift = predicted within 1e-6 deg
%      where speed > 1e-4 m/s, and speed equal within TOL; Suu+Svv, Sxx+Syy,
%      a1^2+b1^2, a2^2+b2^2 equal within TOL (rotation invariants).
%   G3 L3: full rebuild; every field outside {uMean, vMean, tidal, subtidal,
%      prov} equal within TOL, including the storm events (L2 Hs is unchanged,
%      so the events must be too); tidal and subtidal fields other than the
%      velocity ones equal within TOL; tidal.depth_source == 'NOAA'; the CDIP
%      storm reference equal. REPORTED, not gated: the tidal and subtidal (u, v)
%      bearing shift and speed change, and the number of velocity constituents
%      with SNR > 2. Reason (decided before any rebuild): t_tide fits u + iv
%      linearly, but its prediction keeps only constituents with SNR > 2, and
%      the bootstrap noise is estimated per axis, so a rotation can move a
%      borderline constituent across that threshold. Exact equivariance is
%      therefore not guaranteed by the rotation alone.
%   G4 L4: identity alignment, eta.depth == L2.depth to 1e-9 m, every L4WANT
%      field present, no NEW Z flag; eta and bispectra equal within TOL.
%      ref, pdf, boundwave, reflection_free and moments depend on velocity
%      direction and are reported, not gated.
%   G5 gapL4 (added 2026-11-17 before any rebuild, with the scope widening to
%      the L4 velocity-gap fix of 8295c13): identity alignment, eta.depth ==
%      L2.depth to 1e-9 m, every L4WANT field present, no NEW Z flag; eta,
%      bispectra and moments equal within TOL; on a record with ZERO gap
%      samples, ref, pdf, boundwave and reflection_free also equal within TOL.
%      On a record with gap samples, the largest change of every numeric leaf
%      of those four modules is reported, not gated.
%   L4 velocity gaps: build_L4 applies shared/l1_velocity_gap_mask.m to L1 U,
%      V, W before the four velocity modules, as PUV_L4_driver does since
%      8295c13, so the code that builds every L4 here matches the committed
%      driver. This applies to the 12 heading records too (TOR14C has 1 gap
%      sample, TOR24W MOP586_10m 15).
%   Parallel pool: at most one pool, 6 workers (a Paper 1 session runs MATLAB
%      alongside); the stage opens it, and refuses an existing larger pool.
%   TOL: |a - b| <= 1e-9 max(|a|, |b|) + 1e-12 max|a| over the array (a
%      rotation changes velocity at rounding level, ~1e-16 m/s, so invariant
%      sums move at about 1e-15 relative; a real change is many orders larger).
%
% Backups: none in bytes. The server copy of catalog 2026-11-17.1 and the
% sha256 manifest of these 48 + 2 files (docs/archive_snapshot_manifests/
% pre_heading_log_2026-11-17_manifest.csv, written before stage L1) stand in.
% Raw cache: rawRoot below, ~13.9 GB; deleted when the push is verified.
%
% 2026-11-17.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup_puv.m'));
if ~exist('stage', 'var'), error('set stage = ''preflight'' | ''raw'' | ''L1'' | ''L2L4'' | ''xspec'''); end
outRoot = fullfile(repoRoot, 'outputs');
if ~exist('rawRoot', 'var'), rawRoot = '/Users/holden/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_heading_20261117'; end
if ~exist('gateBreakShift', 'var'), gateBreakShift = 0; end
L4WANT = {'eta','ref','bispectra','boundwave','moments','reflection_free','pdf', ...
          'label','deploymentName','LATLON','doffp','shorenormal'};
XSPEC = {'TOR24W','TOR25S','RUBY22','SOL23','TOR23W'};
% deployments of docs/catalog_changes/2026-11-17_l4_velocity_gaps.md
GAPDEPS = {'CAT21A','COR16B','RUBY22','SOL23','TOR14A','TOR14C','TOR15B','TOR16B','TOR16C','TOR17C','TOR23W','TOR24W'};
logG = fullfile(outRoot, '_logs', 'heading_log_gapL4_2026-11-17.log');
% dep, label, old heading (L1 on disk, 1 dp), new heading (config)
HDG = {'TOR17D','MOP591_9m', 100.5,  66.7;
       'TOR14C','MOP591_9m',  76.0, 101.5;
       'TOR17B','MOP591_9m',  87.6,  66.7;
       'TOR15D','MOP591_9m',  26.7,  43.0;
       'TOR15A','MOP591_9m',  48.7,  63.6;
       'TOR14B','MOP591_9m',  90.0, 101.5;
       'COR17D','MOP158_9m',  49.1,  28.9;
       'CDF15A','MOP677_9m',  47.6,  62.2;
       'CDF15C','MOP677_9m',  47.5,  62.2;
       'TOR24W','MOP586_10m', 71.9,  59.5;
       'TOR25S','MOP586_15m', 46.1,  34.2;
       'SIO25E','SIO_6m',     99.3,  88.0};
logL1 = fullfile(outRoot, '_logs', 'heading_log_L1_2026-11-17.log');
logL2 = fullfile(outRoot, '_logs', 'heading_log_L2L4_2026-11-17.log');
fprintf('stage = %s\noutRoot = %s (-> %s)\nrawRoot = %s\n', stage, outRoot, ...
    char(java.io.File(outRoot).getCanonicalPath()), rawRoot);

%% ---- PREFLIGHT (every stage) ----
for fnName = {'PUV_raw_process','vector_beam_step_correct','xyz_to_buoy_frame','PUV_L2_spectral', ...
              'PUV_L3_transport','PUV_L3_currents','PUV_L4_xspec','save_with_provenance', ...
              'build_provenance','deployment_registry','copy_raw_to_local','heading_disputed_records'}
    w = which(fnName{1});
    if isempty(w) || ~startsWith(w, [repoRoot filesep])
        error('PREFLIGHT: %s resolves to "%s", not into %s', fnName{1}, w, repoRoot);
    end
end
[st, gs] = system(sprintf('git -C "%s" status --porcelain -- config shared L1_raw_to_qc L2_spectral L3_forcing L4_ig scripts', repoRoot));
if st ~= 0 || ~isempty(strtrim(gs)), error('PREFLIGHT: uncommitted code or config:\n%s', gs); end
reg = deployment_registry();
[~, ~, TBLd] = heading_disputed_records();
if height(TBLd) ~= 0, error('PREFLIGHT: the disputed list is not empty (%d)', height(TBLd)); end
for r = 1:size(HDG, 1)
    [dep, lab, hOld, hNew] = HDG{r,:};
    fh = reg(dep); cfg = fh(); ii = strcmp({cfg.instruments.label}, lab);
    if sum(ii) ~= 1, error('PREFLIGHT: %s/%s not in config', dep, lab); end
    instr = cfg.instruments(ii);
    if ~isequal(instr.heading, hNew), error('PREFLIGHT: %s/%s config heading %g, expected %g', dep, lab, instr.heading, hNew); end
    if isfield(instr, 'headingSmoothHours') && ~isempty(instr.headingSmoothHours), error('PREFLIGHT: %s/%s has headingSmoothHours', dep, lab); end
    f1 = fullfile(outRoot, 'L1', dep, [lab '_processed.mat']);
    s0 = h5read(f1, '/PUV/rotation/sensor');
    fprintf('  %-7s %-11s config %6.1f | L1 on disk %8.3f (listed %5.1f) | predicted shift %+6.1f\n', dep, lab, instr.heading, s0, hOld, hNew - hOld);
end
if exist('onlyRecs', 'var') && ~isempty(onlyRecs)
    RUN = HDG(ismember(string(HDG(:,1)) + "|" + string(HDG(:,2)), string(onlyRecs(:,1)) + "|" + string(onlyRecs(:,2))), :);
else
    RUN = HDG;
end
if strcmp(stage, 'gapL4')
    isH = @(d, l) any(strcmp(HDG(:,1), d) & strcmp(HDG(:,2), l));
    RUN = cell(0, 2);
    for d = 1:numel(GAPDEPS)
        fl = dir(fullfile(outRoot, 'L4', GAPDEPS{d}, '*_L4.mat'));
        for k = 1:numel(fl)
            lab = erase(fl(k).name, '_L4.mat');
            if ~isH(GAPDEPS{d}, lab), RUN(end+1, :) = {GAPDEPS{d}, lab}; end %#ok<AGROW>
        end
    end
    if exist('onlyRecs', 'var') && ~isempty(onlyRecs)
        RUN = RUN(ismember(string(RUN(:,1)) + "|" + string(RUN(:,2)), string(onlyRecs(:,1)) + "|" + string(onlyRecs(:,2))), :);
    end
    fprintf('gapL4: %d records (12 deployments, heading records excluded)\n', size(RUN, 1));
end
if exist('skipDone', 'var') && skipDone
    lf = ternary(strcmp(stage, 'L1'), logL1, ternary(strcmp(stage, 'gapL4'), logG, logL2));
    if isfile(lf)
        txt = regexprep(splitlines(string(fileread(lf))), '\s+', ' ');
        tag = ternary(strcmp(stage, 'L1'), " L1 PASS", ternary(strcmp(stage, 'gapL4'), " gapL4 PASS", " L2L3L4 PASS"));
        key = string(RUN(:,1)) + " " + string(RUN(:,2)) + tag;
        keep = true(size(RUN, 1), 1);
        for r = 1:size(RUN, 1), keep(r) = ~any(contains(txt, key(r))); end
        RUN = RUN(keep, :);
    end
    fprintf('skipDone: %d records to run\n', size(RUN, 1));
end
hungF = fullfile(outRoot, '_logs', ternary(strcmp(stage, 'gapL4'), 'heading_log_gapL4_hung.txt', 'heading_log_L2L4_hung.txt'));
if any(strcmp(stage, {'L2L4','gapL4'})) && isfile(hungF)
    hung = strtrim(splitlines(string(fileread(hungF)))); hung = hung(hung ~= "");
    key = string(RUN(:,1)) + "|" + string(RUN(:,2));
    if exist('retryHung', 'var') && retryHung
        RUN = RUN(ismember(key, hung), :); serialL4 = true; %#ok<NASGU>
        fprintf('retryHung: %d record(s), serial bispectra\n', size(RUN, 1));
    else
        RUN = RUN(~ismember(key, hung), :);
    end
end

switch stage
case 'preflight'
    [~, m] = system('mount | grep /Volumes/group'); fprintf('mount: %s\n', strtrim(m));
case 'raw'
    for r = 1:size(RUN, 1)
        fh = reg(RUN{r,1}); cfg = fh(); instr = cfg.instruments(strcmp({cfg.instruments.label}, RUN{r,2}));
        try, copy_raw_one(cfg, instr, rawRoot);
        catch ME, fprintf(2, 'RAW FAIL %s/%s: %s\n', RUN{r,1}, RUN{r,2}, ME.message); end
    end
case 'L1'
    for r = 1:size(RUN, 1)
        s = rebuild_L1(reg, RUN(r,:), outRoot, rawRoot, gateBreakShift);
        if gateBreakShift == 0, append_log(logL1, s); end
    end
case 'gapL4'
    ensure_pool(6); okN = 0;
    for r = 1:size(RUN, 1)
        [s, okRec] = rebuild_gapL4(RUN{r,1}, RUN{r,2}, reg, outRoot, L4WANT);
        okN = okN + okRec; append_log(logG, s);
    end
    fprintf('gapL4: %d/%d records PASS\n', okN, size(RUN, 1));
case 'L2L4'
    ensure_pool(6); okN = 0;
    for r = 1:size(RUN, 1)
        [s, okRec] = rebuild_L2L4(reg, RUN(r,:), outRoot, L4WANT);
        okN = okN + okRec; append_log(logL2, s);
    end
    fprintf('L2L4: %d/%d records PASS\n', okN, size(RUN, 1));
case 'xspec'
    for k = 1:numel(XSPEC)
        append_log(logL2, rebuild_xspec_prov(XSPEC{k}, outRoot));
    end
otherwise
    error('unknown stage %s', stage);
end

% ======================================================================
function append_log(f, s)
    fid = fopen(f, 'a'); fprintf(fid, '%s  %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), s); fclose(fid);
end

function cfg = copy_raw_one(cfg, instr, rawRoot)
% Cache only this instrument's raw files, then require every cached file to
% match the server by size, so a copy cut short by a dropped mount is never used.
    one = cfg; one.instruments = instr;
    one = copy_raw_to_local(one, rawRoot);
    cfg.localDataRoot = one.localDataRoot;
    src = fullfile(cfg.rawDataRoot, instr.rawSubfolder);
    dst = fullfile(cfg.localDataRoot, instr.rawSubfolder);
    S = dir(src); S = S(~[S.isdir]);
    if ~isempty(instr.filePrefix) && isempty(instr.rawSubfolder)
        S = S(startsWith({S.name}, instr.filePrefix));
    end
    if isempty(S), error('no raw files on the server at %s', src); end
    for k = 1:numel(S)
        d = dir(fullfile(dst, S(k).name));
        if isempty(d) || d(1).bytes ~= S(k).bytes
            error('raw cache mismatch for %s (server %d bytes)', S(k).name, S(k).bytes);
        end
    end
    fprintf('  %s/%s raw cache verified: %d/%d files match the server by size (%.2f GB)\n', ...
        cfg.name, instr.label, numel(S), numel(S), sum([S.bytes])/1e9);
end

function s = rebuild_L1(reg, rec, outRoot, rawRoot, brk)
    [dep, lab, hOld, hNew] = rec{:};
    fprintf('\n[L1] %s/%s\n', dep, lab);
    try
        fh = reg(dep); cfg = fh(); instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        cfg.localDataRoot = fullfile(rawRoot, cfg.name);
        if ~isfolder(cfg.localDataRoot), error('no raw cache %s', cfg.localDataRoot); end
        f1 = fullfile(outRoot, 'L1', dep, [lab '_processed.mat']);
        q = load(f1, 'PUV'); O = q.PUV; clear q
        t0 = tic; N = PUV_raw_process(instr, cfg);
        bad = {};
        for f = setdiff(union(fieldnames(N), fieldnames(O)), {'BuoyCoord','rotation','prov'})'
            if ~isfield(N, f{1}) || ~isfield(O, f{1}) || ~isequaln(N.(f{1}), O.(f{1})), bad{end+1} = f{1}; end %#ok<AGROW>
        end
        if ~isequaln(N.BuoyCoord.W, O.BuoyCoord.W), bad{end+1} = 'W'; end
        for f = setdiff(union(fieldnames(N.rotation), fieldnames(O.rotation)), {'sensor'})'
            if ~isfield(N.rotation, f{1}) || ~isfield(O.rotation, f{1}) || ~isequaln(N.rotation.(f{1}), O.rotation.(f{1}))
                bad{end+1} = ['rotation.' f{1}]; %#ok<AGROW>
            end
        end
        if ~isequal(N.rotation.sensor, hNew), bad{end+1} = sprintf('sensor %.4f ~= config %.4f', N.rotation.sensor, hNew); end
        if abs(O.rotation.sensor - hOld) > 0.05, bad{end+1} = sprintf('old sensor %.4f, listed %.1f', O.rotation.sensor, hOld); end
        expShift = N.rotation.sensor - O.rotation.sensor + brk;
        if ~isequal(isnan(N.BuoyCoord.U), isnan(O.BuoyCoord.U)) || ~isequal(isnan(N.BuoyCoord.V), isnan(O.BuoyCoord.V)), bad{end+1} = 'U/V NaN pattern'; end
        [maxRot, maxSpd, nB, medShift] = bearing_shift(N.BuoyCoord.U, N.BuoyCoord.V, O.BuoyCoord.U, O.BuoyCoord.V, expShift, 0.01);
        if ~(maxRot <= 1e-6), bad{end+1} = sprintf('bearing shift off prediction by up to %.2e deg', maxRot); end
        if ~(maxSpd <= 1e-9), bad{end+1} = sprintf('speed changed by up to %.2e m/s', maxSpd); end
        msg = sprintf('heading %.3f -> %.3f, predicted shift %+.4f (break %+g), median shift %+.6f, max|shift-pred| %.1e deg, max|dspeed| %.1e m/s, n %d, %.1f min', ...
            O.rotation.sensor, N.rotation.sensor, expShift, brk, medShift, maxRot, maxSpd, nB, toc(t0)/60);
        if ~isempty(bad), error('G1 L1 gate: %s | %s: not saved', strjoin(bad, '; '), msg); end
        if brk ~= 0, error('break test passed the gate (it must not): %s', msg); end
        save_with_provenance(f1, 'L1', 'PUV', N, [], instr);
        s = sprintf('%-7s %-11s L1 PASS | %s', dep, lab, msg);
    catch ME
        s = sprintf('%-7s %-11s L1 FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    fprintf('  %s\n', s);
end

function [maxRot, maxSpd, n, med] = bearing_shift(uN, vN, uO, vO, expShift, minSpd)
% Bearing atan2d(-U, V) (buoy frame, +x WEST, +y NORTH); a heading change Delta
% moves it by +Delta. Speeds below minSpd are excluded (bearing undefined).
    spN = hypot(uN, vN); spO = hypot(uO, vO);
    m = isfinite(spN) & isfinite(spO) & spO > minSpd;
    dB = mod(atan2d(-uN(m), vN(m)) - atan2d(-uO(m), vO(m)) + 180, 360) - 180;
    maxRot = max([abs(mod(dB - expShift + 180, 360) - 180); 0]);
    ok = isfinite(spN) & isfinite(spO);
    maxSpd = max([abs(spN(ok) - spO(ok)); 0]);
    n = sum(m); med = median(dB);
end

function bad = cmp_tol(A, B, skip, prefix)
% Fields of structs A and B outside skip that differ beyond TOL (numeric) or
% at all (anything else); recurses into scalar structs.
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
    m = ~isnan(a); a = a(m); b = b(m);
    if isempty(a), ok = true; return, end
    ok = all(abs(a - b) <= 1e-9 * max(abs(a), abs(b)) + 1e-12 * max(abs(a)));
end

function [s, okRec] = rebuild_L2L4(reg, rec, outRoot, L4WANT)
% All-or-nothing per record: L2, L3 and L4 are built and gated in memory first,
% then saved parents first with provenance.
    [dep, lab] = rec{1:2};
    fprintf('\n[heading L2L3L4] %s/%s\n', dep, lab); okRec = false;
    try
        fh = reg(dep); cfg = fh(); instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        Tvalid = l1_qc_opts(cfg).Tvalid;
        f1 = fullfile(outRoot,'L1',dep,[lab '_processed.mat']); f2 = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        f3 = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);        f4 = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
        q = load(f1,'PUV'); PUV = q.PUV;
        q = load(f2,'L2'); L2o = q.L2; q = load(f3,'L3'); L3o = q.L3; q = load(f4,'L4'); L4o = q.L4; clear q
        if ~isequal(PUV.rotation.sensor, instr.heading), error('L1 on disk is not the rebuilt one (sensor %.3f, config %.3f)', PUV.rotation.sensor, instr.heading); end
        % the old L1 heading is not on disk any more: take the exact predicted
        % shift G1 used from the L1 rebuild log
        expShift = l1_logged_shift(outRoot, dep, lab);
        msgs = {sprintf('pred shift %+.4f', expShift)};

        % ---- G2: L2 ----
        L2 = PUV_L2_spectral(PUV, instr, struct());
        if ~isequal(L2.time, L2o.time) || ~isequal(L2.segValid, L2o.segValid), error('G2: L2 time grid or segValid changed'); end
        if ~isequaln(L2.shorenormal, L2o.shorenormal), error('G2: L2 shorenormal %.4g vs %.4g (CDIP fetch failed?)', L2.shorenormal, L2o.shorenormal); end
        DIR2 = {'a1','b1','a2','b2','Suu','Svv','Sxx','Syy','Sxy','meanDir','uMean','vMean','uBed_rms','vBed_rms', ...
                'phase_PU','qtest_PU','vmom','reynolds','prov'};
        bad = cmp_tol(L2o, L2, DIR2, 'L2.');
        bad = [bad, cmp_tol(L2o.reynolds, L2.reynolds, {'uw','vw','uv','u_rms','v_rms'}, 'L2.reynolds.')];
        v = L2.segValid(:);
        dd = mod(double(L2.meanDir(v)) - double(L2o.meanDir(v)) + 180, 360) - 180;
        ok = isfinite(dd); mDir = max([abs(mod(dd(ok) + expShift + 180, 360) - 180); 0]);
        if ~(mDir <= 1e-6), bad{end+1} = sprintf('meanDir shift off -pred by %.2e deg', mDir); end
        [mRot, mSpd] = bearing_shift(L2.uMean(v), L2.vMean(v), L2o.uMean(v), L2o.vMean(v), expShift, 1e-4);
        if ~(mRot <= 1e-6), bad{end+1} = sprintf('mean-current bearing off pred by %.2e deg', mRot); end
        if ~within_tol(hypot(L2.uMean, L2.vMean), hypot(L2o.uMean, L2o.vMean)), bad{end+1} = sprintf('mean-current speed (%.1e)', mSpd); end
        inv = {L2.Suu + L2.Svv, L2o.Suu + L2o.Svv, 'Suu+Svv'; L2.Sxx + L2.Syy, L2o.Sxx + L2o.Syy, 'Sxx+Syy'; ...
               L2.a1.^2 + L2.b1.^2, L2o.a1.^2 + L2o.b1.^2, 'a1^2+b1^2'; L2.a2.^2 + L2.b2.^2, L2o.a2.^2 + L2o.b2.^2, 'a2^2+b2^2'};
        for j = 1:size(inv, 1), if ~within_tol(inv{j,1}, inv{j,2}), bad{end+1} = ['invariant ' inv{j,3}]; end, end %#ok<AGROW>
        if ~isempty(bad), error('G2 L2 gate: %s', strjoin(bad, ', ')); end
        dSxy = median(abs(L2.Sxy(v) - L2o.Sxy(v)), 'omitnan');
        msgs{end+1} = sprintf('G2 ok: meanDir shift -pred within %.1e deg, current bearing within %.1e deg, median|dSxy| %.3g', mDir, mRot, dSxy);

        % ---- G3: L3 (full rebuild) ----
        L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2, struct('Tvalid', Tvalid)); L3 = PUV_L3_currents(L3, L2, l3_currents_opts(cfg));
        bad = cmp_tol(L3o, L3, {'uMean','vMean','tidal','subtidal','prov'}, 'L3.');
        bad = [bad, cmp_tol(L3o.tidal, L3.tidal, {'u','v','vel_constituents'}, 'L3.tidal.')];
        bad = [bad, cmp_tol(L3o.subtidal, L3.subtidal, {'u','v'}, 'L3.subtidal.')];
        if ~strcmp(L3.tidal.depth_source, 'NOAA'), bad{end+1} = ['tidal.depth_source ' L3.tidal.depth_source]; end
        if ~isempty(bad), error('G3 L3 gate: %s', strjoin(bad, ', ')); end
        rep3 = {};
        for P = {'tidal','subtidal'}
            a = L3.(P{1}); b = L3o.(P{1});
            [mR, mS] = bearing_shift(a.u, a.v, b.u, b.v, expShift, 1e-4);
            rep3{end+1} = sprintf('%s bearing off pred max %.1e deg, speed change max %.1e m/s', P{1}, mR, mS); %#ok<AGROW>
        end
        rep3{end+1} = sprintf('vel constituents SNR>2 %d -> %d', n_snr2(L3o.tidal.vel_constituents), n_snr2(L3.tidal.vel_constituents));
        msgs{end+1} = ['G3 ok (non-velocity L3 unchanged) | REPORTED: ' strjoin(rep3, '; ')];

        % ---- G4: L4 ----
        L4 = build_L4(PUV, L2, instr);
        [l4map, info] = l4_l2_index_map(L2, L4);
        ok = ~isnan(l4map(:)) & L2.segValid(:);
        dDep = max(abs(L4.eta.depth(l4map(ok)) - L2.depth(ok)));
        miss = setdiff(L4WANT, fieldnames(L4));
        qz = ztest_record_flag(L2.ztest_SS, L2.segValid); qzO = ztest_record_flag(L2o.ztest_SS, L2o.segValid);
        bad = {};
        if ~info.identity, bad{end+1} = 'not identity-aligned'; end
        if ~(dDep <= 1e-9), bad{end+1} = sprintf('eta.depth vs L2.depth %.2e m', dDep); end
        if ~isempty(miss), bad{end+1} = ['missing ' strjoin(miss, ',')]; end
        if strcmp(qz.status, 'FLAG') && ~strcmp(qzO.status, 'FLAG'), bad{end+1} = 'new Z flag'; end
        bad = [bad, cmp_tol(struct('eta', L4o.eta, 'bispectra', L4o.bispectra), struct('eta', L4.eta, 'bispectra', L4.bispectra), {}, 'L4.')];
        if ~isempty(bad), error('G4 L4 gate: %s', strjoin(bad, ', ')); end
        movedL4 = cmp_tol(L4o, L4, {'eta','bispectra','builtAt','prov'}, '');
        msgs{end+1} = sprintf('G4 ok (Z %s); L4 fields moved (expected, velocity-direction dependent): %s', qz.status, strjoin(unique(regexprep(movedL4, '\..*', '')), ','));

        stamp_save(f2, 'L2', L2, struct('level','L1','path',f1), instr);
        stamp_save(f3, 'L3', L3, struct('level','L2','path',f2), instr);
        stamp_save(f4, 'L4', L4, struct('level','L2','path',f2), instr);
        okRec = true;
        s = sprintf('%-7s %-11s L2L3L4 PASS | %s', dep, lab, strjoin(msgs, ' | '));
    catch ME
        s = sprintf('%-7s %-11s L2L3L4 FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    fprintf('  %s\n', s);
end

function [s, okRec] = rebuild_gapL4(dep, lab, reg, outRoot, L4WANT)
% L4 only, from the current L1 and L2 (neither changes), with the L1 velocity
% gaps applied. Gate G5 before saving.
    fprintf('\n[gapL4] %s/%s\n', dep, lab); okRec = false;
    try
        fh = reg(dep); cfg = fh(); instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        f1 = fullfile(outRoot,'L1',dep,[lab '_processed.mat']); f2 = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        f4 = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
        q = load(f1,'PUV'); PUV = q.PUV; q = load(f2,'L2'); L2 = q.L2; q = load(f4,'L4'); L4o = q.L4; clear q
        [velGap, gi] = l1_velocity_gap_mask(PUV, instr); nGap = sum(velGap);
        t0 = tic; L4 = build_L4(PUV, L2, instr);
        [l4map, info] = l4_l2_index_map(L2, L4);
        ok = ~isnan(l4map(:)) & L2.segValid(:);
        dDep = max(abs(L4.eta.depth(l4map(ok)) - L2.depth(ok)));
        miss = setdiff(L4WANT, fieldnames(L4));
        qz = ztest_record_flag(L2.ztest_SS, L2.segValid);
        bad = {};
        if ~info.identity, bad{end+1} = 'not identity-aligned'; end
        if ~(dDep <= 1e-9), bad{end+1} = sprintf('eta.depth vs L2.depth %.2e m', dDep); end
        if ~isempty(miss), bad{end+1} = ['missing ' strjoin(miss, ',')]; end
        % L2 is not rebuilt, so the Z status is the one already published
        % (RUBY22/MOP582_30m is FLAG and excluded); reported, not gated.
        FIX = {'eta','bispectra','moments'}; VEL = {'ref','pdf','boundwave','reflection_free'};
        bad = [bad, cmp_tol(keep_fields(L4o, FIX), keep_fields(L4, FIX), {}, 'L4.')];
        if nGap == 0
            bad = [bad, cmp_tol(keep_fields(L4o, VEL), keep_fields(L4, VEL), {}, 'L4.')];
            rpt = 'no gap samples: velocity modules unchanged within TOL';
        else
            D = leaf_changes(keep_fields(L4o, VEL), keep_fields(L4, VEL), 'L4.');
            nMoved = sum(D.maxAbs > 0 | D.nanChanged > 0);
            rpt = sprintf('%d gap samples (%d unconfirmed, %d after cutoff): %d/%d velocity-module leaves moved; largest: %s', ...
                nGap, gi.nUnconfirmed, gi.nCutoff, nMoved, height(D), leaf_summary(D));
        end
        if ~isempty(bad), error('G5 gapL4 gate: %s', strjoin(bad, ', ')); end
        stamp_save(f4, 'L4', L4, struct('level','L2','path',f2), instr);
        okRec = true;
        s = sprintf('%-7s %-11s gapL4 PASS | eta/bispectra/moments unchanged within TOL | %s | Z %s | %.1f min', dep, lab, rpt, qz.status, toc(t0)/60);
    catch ME
        s = sprintf('%-7s %-11s gapL4 FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
    fprintf('  %s\n', s);
end

function S = keep_fields(S, F)
    S = rmfield(S, setdiff(fieldnames(S), F));
end

function D = leaf_changes(A, B, prefix)
% One row per numeric leaf: largest |a - b| (finite pairs), largest relative
% change, and the number of elements whose NaN status changed.
    D = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), 'VariableNames', {'leaf','maxAbs','maxRel','nanChanged'});
    for f = union(fieldnames(A), fieldnames(B))'
        k = f{1};
        if ~isfield(A, k) || ~isfield(B, k), continue, end
        a = A.(k); b = B.(k);
        if isstruct(a) && isstruct(b) && isscalar(a) && isscalar(b)
            D = [D; leaf_changes(a, b, [prefix k '.'])]; %#ok<AGROW>
        elseif isnumeric(a) && isnumeric(b) && isequal(size(a), size(b))
            a = double(a(:)); b = double(b(:)); m = isfinite(a) & isfinite(b);
            da = abs(a(m) - b(m)); dr = da ./ max(abs(a(m)), eps);
            D = [D; {string([prefix k]), max([da; 0]), max([dr; 0]), sum(isnan(a) ~= isnan(b))}]; %#ok<AGROW>
        end
    end
end

function t = leaf_summary(D)
    D = D(D.maxAbs > 0 | D.nanChanged > 0, :);
    if isempty(D), t = 'none'; return, end
    D = sortrows(D, 'maxRel', 'descend');
    n = min(5, height(D));
    t = strjoin(arrayfun(@(i) sprintf('%s |d| %.3g (rel %.3g, NaN-changed %d)', D.leaf(i), D.maxAbs(i), D.maxRel(i), D.nanChanged(i)), 1:n, 'UniformOutput', false), '; ');
end

function ensure_pool(nMax)
    p = gcp('nocreate');
    if isempty(p), parpool('Processes', nMax);
    elseif p.NumWorkers > nMax, error('a parallel pool with %d workers is open; at most %d allowed', p.NumWorkers, nMax);
    end
end

function x = l1_logged_shift(outRoot, dep, lab)
% The predicted shift used by G1 for this record, read back from the L1 log.
    lf = fullfile(outRoot, '_logs', 'heading_log_L1_2026-11-17.log');
    txt = splitlines(string(fileread(lf)));
    t = txt(contains(txt, sprintf('%-7s %-11s L1 PASS', dep, lab)));
    if isempty(t), error('no L1 PASS line for %s/%s in %s', dep, lab, lf); end
    tok = regexp(t(end), 'predicted shift ([+-][0-9.]+)', 'tokens', 'once');
    x = str2double(tok{1});
end

function stamp_save(f, varName, S, parents, instr)
    if isfield(S, 'prov'), S = rmfield(S, 'prov'); end
    prov = build_provenance(varName, S, parents, instr);
    S.prov = prov;
    tmpS.(varName) = S; %#ok<STRNU>
    save(f, '-struct', 'tmpS', '-v7.3');
    q = load(f, varName);
    if ~isequaln(q.(varName), S), error('reloaded %s differs from the one saved: %s', varName, f); end
    write_prov_sidecar(f, prov);
end

function L4 = build_L4(PUV, L2, instr)
% As PUV_L4_driver since 8295c13: the L2 velocity gaps are applied to L1 U, V, W
% before the modules that read L1 velocity directly.
    velGap = l1_velocity_gap_mask(PUV, instr);
    if any(velGap)
        PUV.BuoyCoord.U(velGap) = NaN; PUV.BuoyCoord.V(velGap) = NaN; PUV.BuoyCoord.W(velGap) = NaN;
    end
    L4 = struct();
    L4.eta = PUV_L4_eta(PUV, L2);
    L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
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

function s = rebuild_xspec_prov(dep, outRoot)
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

function n = n_snr2(t)
% t_tide constituents with SNR > 2 (complex input: SNR = (fmaj/emaj)^2)
    if isstruct(t) && isfield(t, 'tidecon') && ~isempty(t.tidecon)
        n = sum((t.tidecon(:,1) ./ max(t.tidecon(:,2), eps)).^2 > 2);
    else
        n = NaN;
    end
end

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
