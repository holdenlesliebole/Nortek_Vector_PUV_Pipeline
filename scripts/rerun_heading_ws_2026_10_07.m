% RERUN_HEADING_WS_2026_10_07  Catalog fixes after the heading and settling-
% velocity changes of 2026-10-07. Run one STAGE at a time:
%
%   stage = 'heading'   L1-L4 for the 9 records whose config heading changed
%                       (logged mount heading where the compass drifts), and
%                       a STAGED L1 for SIO24A (now decoded from .VEC). SIO24A's
%                       new L1 goes to outputs/_staging_SIO24A_2026-10-07/ and
%                       is NOT promoted by this stage.
%   stage = 'sio24a'    promote the staged SIO24A L1 and build its L2-L4
%                       (only after its old-vs-new comparison was accepted).
%   stage = 'xspec'     L4_xspec for TOR24S (two of its instruments changed).
%   stage = 'L3'        L3-only regeneration (PUV_L3_transport on the existing
%                       L3) for every registered record still carrying the
%                       pre-2026-08-13 smooth-sphere (C2 = 0.4) ws.
%   dryRun = true       stop after PREFLIGHT; nothing is backed up or written.
%
% Heading changes (config, magnetic deg; old = PUV.rotation.sensor in the L1
% on disk before this run): COR16B 5.2 -> 21.6, TOR16A 88.8 -> 82.3, TOR16B
% 87.3 -> 82.3, TOR16C 88.4 -> 82.3, TOR16D 85.2 -> 82.3, TOR17A 93.9 -> 66.7,
% TOR17C 120.7 -> 66.7, TOR24S/MOP586_5m 98.8 -> 85.0, TOR24S/MOP586_7m
% 78.7 -> 94.5. In the XYZ branch the true bearing of +x is heading + D, so a
% heading change Delta moves every velocity sample's bearing by exactly
% Delta (plus any change in the IGRF declination D) and L2 meanDir by -Delta.
% Nothing else in L1 may change; the L1 check enforces that before saving.
%
% Backups (delete after the server push is verified): outputs/_pre_heading_ws_
% backup_2026-10-07/, ~11.3 GB for the heading stage, 7.5 MB xspec, ~0.03 GB L3.
%
%   Run from PUV_Pipeline/ (outRoot/rawRoot may be set first):
%     >> stage = 'heading'; dryRun = true; run scripts/rerun_heading_ws_2026_10_07

repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup_puv.m'));
if ~exist('stage', 'var'), error('set stage = ''heading'' | ''sio24a'' | ''xspec'' | ''L3'''); end
if ~exist('dryRun', 'var'), dryRun = false; end
if ~exist('outRoot', 'var'), outRoot = fullfile(repoRoot, 'outputs'); end
if ~exist('rawRoot', 'var'), rawRoot = fullfile(fileparts(outRoot), 'raw_cache'); end
bkRoot = fullfile(outRoot, '_pre_heading_ws_backup_2026-10-07');
stRoot = fullfile(outRoot, '_staging_SIO24A_2026-10-07');
fprintf('stage = %s, dryRun = %d\noutRoot = %s\nrawRoot = %s\nbkRoot = %s\n', ...
    stage, dryRun, outRoot, rawRoot, bkRoot);

% dep, label, new heading (config), old heading (L1 rotation.sensor, 1 dp)
HDG = {'COR16B','MOP158_9m', 21.6,   5.2;
       'TOR16A','MOP591_9m', 82.3,  88.8;
       'TOR16B','MOP591_9m', 82.3,  87.3;
       'TOR16C','MOP591_9m', 82.3,  88.4;
       'TOR16D','MOP591_9m', 82.3,  85.2;
       'TOR17A','MOP591_9m', 66.7,  93.9;
       'TOR17C','MOP591_9m', 66.7, 120.7;
       'TOR24S','MOP586_5m', 85.0,  98.8;
       'TOR24S','MOP586_7m', 94.5,  78.7};
SIO = {'SIO24A','SIO_6m'};

%% ===================== PREFLIGHT (aborts the whole run) =====================
fprintf('\nPREFLIGHT\n  code root = %s\n', repoRoot);
for fnName = {'PUV_raw_process','l1_qc_opts','PUV_L2_spectral','PUV_L3_transport', ...
              'settling_velocity','rouse_number','site_grain_size','PUV_L4_bispectra', ...
              'PUV_L4_xspec','l4_l2_index_map','deployment_registry','TorreyOffshore_config', ...
              'Coronado_config','TOR24S_config','SIO_Pier_config','copy_raw_to_local'}
    w = which(fnName{1});
    fprintf('  which %-22s %s\n', fnName{1}, w);
    if isempty(w) || ~startsWith(w, [repoRoot filesep])
        error('PREFLIGHT: %s resolves to "%s", not into %s', fnName{1}, w, repoRoot);
    end
end
reg = deployment_registry();
l1path = @(root, d, l) fullfile(root, 'L1', d, [l '_processed.mat']);

if strcmp(stage, 'heading')
    for r = 1:size(HDG,1)
        [dep, lab, hNew, hOld] = HDG{r,:};
        fn = reg(dep); cfg = fn(); ii = find(strcmp({cfg.instruments.label}, lab), 1);
        if isempty(ii), error('PREFLIGHT: %s/%s not in config', dep, lab); end
        instr = cfg.instruments(ii);
        % the L1 that will be compared against: the backup if one exists, else the live file
        src = l1path(bkRoot, dep, lab); if ~isfile(src), src = l1path(outRoot, dep, lab); end
        q = load(src, 'PUV'); O = q.PUV; clear q
        qo = l1_qc_opts(cfg);
        okH = isequal(instr.heading, hNew);
        okO = abs(round(O.rotation.sensor, 1) - hOld) < 1e-9;   % listed to 1 dp
        okS = ~isfield(O.rotation, 'declinationApplied');
        okQ = isequaln(qo, O.qc.opts);
        fprintf('  %-7s %-10s config hdg %6.1f (expect %6.1f) | old L1 sensor %7.3f (expect %5.1f) | qc.opts match old L1 %d | old L1 unstamped %d\n', ...
            dep, lab, instr.heading, hNew, O.rotation.sensor, hOld, okQ, okS);
        if ~(okH && okO && okQ && okS)
            error('PREFLIGHT: %s/%s failed (heading %d, old sensor %d, qc.opts %d, unstamped %d)', ...
                dep, lab, okH, okO, okQ, okS);
        end
        rd = fullfile(cfg.rawDataRoot, instr.rawSubfolder);
        dd = dir(fullfile(rd, '*')); dd = dd(~[dd.isdir]);
        if isempty(dd), error('PREFLIGHT: no raw files at %s (is /Volumes/group mounted?)', rd); end
        fprintf('      raw %s: %d files, %.2f GB\n', rd, numel(dd), sum([dd.bytes])/1e9);
    end
end
if any(strcmp(stage, {'heading','sio24a'}))
    % SIO24A
    fn = reg(SIO{1}); cfg = fn(); instr = cfg.instruments(strcmp({cfg.instruments.label}, SIO{2}));
    q = load(l1path(outRoot, SIO{1}, SIO{2}), 'PUV'); O = q.PUV; clear q
    if isfield(O, 'qc') && isfield(O.qc, 'opts'), qs = sprintf('%d', isequaln(l1_qc_opts(cfg), O.qc.opts));
    else, qs = 'n/a (old L1 predates qc.opts)'; end
    fprintf('  %-7s %-10s rawFormat %s, filePrefix %s, heading %g | qc.opts match old L1 %s (not required: new ingest path)\n', ...
        SIO{1}, SIO{2}, instr.rawFormat, instr.filePrefix, instr.heading, qs);
    dd = dir(fullfile(cfg.rawDataRoot, [instr.filePrefix '*']));
    if isempty(dd), error('PREFLIGHT: no raw files at %s/%s* (is /Volumes/group mounted?)', cfg.rawDataRoot, instr.filePrefix); end
    fprintf('      raw %s/%s*: %d files, %.2f GB\n', cfg.rawDataRoot, instr.filePrefix, numel(dd), sum([dd.bytes])/1e9);
end

if strcmp(stage, 'L3')
    LIST = stale_L3_list(reg, outRoot, HDG, SIO);
    fprintf('  %d registered L3 files carry the stale (C2 = 0.4) ws and will be regenerated\n', size(LIST,1));
    for r = 1:size(LIST,1), fprintf('    %-8s %-12s ws %.6f -> %.6f\n', LIST{r,:}); end
end
fprintf('PREFLIGHT passed (stage %s)\n', stage);
if dryRun
    fprintf('dryRun: stopping after PREFLIGHT; nothing backed up, copied or written.\n');
    return
end

%% ============================== STAGES =====================================
if isempty(gcp('nocreate')) && any(strcmp(stage, {'heading','sio24a'})), parpool('Processes'); end
summary = {};
switch stage
case 'heading'
    for r = 1:size(HDG,1)
        [dep, lab, hNew] = HDG{r,1:3};
        summary{end+1} = rebuild_heading_record(reg, dep, lab, hNew, outRoot, rawRoot, bkRoot); %#ok<SAGROW>
    end
    summary{end+1} = stage_sio24a(reg, SIO{1}, SIO{2}, outRoot, rawRoot, bkRoot, stRoot);
case 'sio24a'
    summary{end+1} = promote_sio24a(reg, SIO{1}, SIO{2}, outRoot, bkRoot, stRoot);
case 'xspec'
    summary{end+1} = rebuild_xspec('TOR24S', outRoot, bkRoot);
case 'L3'
    for r = 1:size(LIST,1)
        summary{end+1} = regen_L3(LIST{r,1}, LIST{r,2}, outRoot, bkRoot); %#ok<SAGROW>
    end
otherwise
    error('unknown stage %s', stage);
end
fprintf('\n=== stage %s summary ===\n', stage);
fprintf('  %s\n', summary{:});


%% ============================ local functions ==============================
function backup_files(files, outRoot, bkRoot)
% Copy each existing file to the same relative path under bkRoot. A copy made
% now is size-checked; an existing backup is the pre-change original and kept.
    for f = files
        if ~isfile(f{1}), continue, end
        dst = fullfile(bkRoot, extractAfter(f{1}, [outRoot filesep]));
        if isfile(dst), continue, end
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        copyfile(f{1}, dst);
        a = dir(f{1}); b = dir(dst);
        if a.bytes ~= b.bytes, error('backup size mismatch for %s', f{1}); end
    end
end

function s = rebuild_heading_record(reg, dep, lab, hNew, outRoot, rawRoot, bkRoot)
    fprintf('\n[heading] %s/%s\n', dep, lab);
    try
        fn = reg(dep); cfg = fn(); cfg.outputDir = outRoot;
        instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        P = {fullfile(outRoot,'L1',dep,[lab '_processed.mat']), fullfile(outRoot,'L2',dep,[lab '_L2.mat']), ...
             fullfile(outRoot,'L3',dep,[lab '_L3.mat']),        fullfile(outRoot,'L4',dep,[lab '_L4.mat']), ...
             fullfile(outRoot,'L1','diagnostics',[dep '_' lab '_L1_QC.png'])};
        backup_files(P, outRoot, bkRoot);
        q = load(fullfile(bkRoot,'L1',dep,[lab '_processed.mat']),'PUV'); O = q.PUV; clear q
        if isfield(O.rotation,'declinationApplied'), error('backup L1 is already a rebuilt one'); end

        cfg = copy_raw_to_local(cfg, rawRoot);
        t0 = tic; PUV = PUV_raw_process(instr, cfg);

        % ---- L1 check: only U/V may change, by the heading (+ any IGRF) change ----
        expShift = (PUV.rotation.sensor + PUV.rotation.mag) - (O.rotation.sensor + O.rotation.mag);
        chk = {};
        if ~strcmp(PUV.rotation.coordSystem,'XYZ') || ~PUV.rotation.declinationApplied, chk{end+1} = 'stamp'; end
        if ~isequal(PUV.rotation.sensor, hNew), chk{end+1} = sprintf('sensor %.4f ~= %.4f', PUV.rotation.sensor, hNew); end
        dMag = PUV.rotation.mag - O.rotation.mag;
        if abs(dMag) > 0.01, chk{end+1} = sprintf('declination moved %.4f deg', dMag); end
        if ~isequal(PUV.time, O.time), chk{end+1} = 'time'; end
        for f = {'P','T'}, if ~isequaln(PUV.(f{1}), O.(f{1})), chk{end+1} = f{1}; end, end %#ok<AGROW>
        if ~isequaln(PUV.BuoyCoord.W, O.BuoyCoord.W), chk{end+1} = 'W'; end
        for f = {'valid_vel','valid_p','valid_tilt','valid_T','opts'}
            if ~isequaln(PUV.qc.(f{1}), O.qc.(f{1})), chk{end+1} = ['qc.' f{1}]; end %#ok<AGROW>
        end
        if ~isequaln(PUV.InstrCoord.U, O.InstrCoord.U) || ~isequaln(PUV.InstrCoord.V, O.InstrCoord.V), chk{end+1} = 'InstrCoord'; end
        [maxRot, maxSpd, nB, medShift] = bearing_shift(PUV, O, expShift);
        if maxRot > 1e-6 || maxSpd > 1e-9, chk{end+1} = sprintf('rotation not pure (%.1e deg, %.1e m/s)', maxRot, maxSpd); end
        fprintf('  L1 (%.1f min): heading %.3f -> %.3f, D %+.4f -> %+.4f, expected bearing shift %+.4f, median %+.6f, max|shift-exp| %.1e deg, max|dspeed| %.1e m/s, n=%d\n', ...
            toc(t0)/60, O.rotation.sensor, PUV.rotation.sensor, O.rotation.mag, PUV.rotation.mag, expShift, medShift, maxRot, maxSpd, nB);
        if ~isempty(chk), error('L1 check failed: %s', strjoin(chk, '; ')); end
        save(P{1}, 'PUV', '-v7.3');

        [L2, L3, L4] = build_L2_L4(PUV, instr, P);
        s = verify_L2_L4(dep, lab, fullfile(bkRoot,'L2',dep,[lab '_L2.mat']), L2, L4, -expShift, PUV.rotation.mag);
    catch ME
        s = sprintf('%-7s %-10s FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
        for k = 1:numel(ME.stack), fprintf(2,'    %s (line %d)\n', ME.stack(k).name, ME.stack(k).line); end
    end
end

function [maxRot, maxSpd, n, med] = bearing_shift(N, O, expShift)
    spN = hypot(N.BuoyCoord.U, N.BuoyCoord.V); spO = hypot(O.BuoyCoord.U, O.BuoyCoord.V);
    m = isfinite(spN) & isfinite(spO) & spO > 0.01;     % bearing undefined near zero
    dB = mod(atan2d(-N.BuoyCoord.U(m), N.BuoyCoord.V(m)) - atan2d(-O.BuoyCoord.U(m), O.BuoyCoord.V(m)) + 180, 360) - 180;
    maxRot = max(abs(mod(dB - expShift + 180, 360) - 180)); maxSpd = max(abs(spN - spO), [], 'omitnan');
    n = sum(m); med = median(dB);
end

function [L2, L3, L4] = build_L2_L4(PUV, instr, P)
    t0 = tic;
    L2 = PUV_L2_spectral(PUV, instr, struct()); save(P{2}, 'L2', '-v7.3');
    L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
    L3 = PUV_L3_transport(L3, L2); L3 = PUV_L3_currents(L3, L2); save(P{3}, 'L3', '-v7.3');
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
    L4.builtAt = datetime('now'); save(P{4}, 'L4', '-v7.3');
    fprintf('  L2-L4 built (%.1f min), %d/%d valid\n', toc(t0)/60, sum(L2.segValid), numel(L2.time));
end

function s = verify_L2_L4(dep, lab, bkL2, B, L4, expDir, D)
    q = load(bkL2, 'L2'); A = q.L2;
    ok1 = isequal(A.time, B.time) && isequal(A.segValid, B.segValid);
    v = A.segValid & B.segValid;
    inv = {'Hs','Hs_SS','Hs_IG','Tp','Tm02','depth','Ub','tau_b','Ef'}; nInv = 0; worst = 0;
    for k = 1:numel(inv)
        x = double(A.(inv{k})(v)); y = double(B.(inv{k})(v));
        rel = max(abs(x - y) ./ max(abs(x), eps), [], 'omitnan');
        worst = max(worst, rel); nInv = nInv + (rel <= 1e-12);
        if rel > 1e-12, fprintf('    MOVED %-6s max rel %.2e on %d segments\n', inv{k}, rel, sum(abs(x-y)./max(abs(x),eps) > 1e-12)); end
    end
    dd = mod(double(B.meanDir(v)) - double(A.meanDir(v)) + 180, 360) - 180;
    mm = max(abs(mod(dd - expDir + 180, 360) - 180));
    [~, ai] = l4_l2_index_map(B, L4); qz = ztest_record_flag(B.ztest_SS, B.segValid);
    pass = ok1 && nInv == numel(inv) && mm < 1e-6 && ai.identity && strcmp(qz.status,'ok');
    s = sprintf('%-7s %-10s %s | grid %d | invariants %d/%d (worst %.1e) | meanDir shift exp %+.3f max|err| %.1e | D %+.4f | %d/%d valid | aligned %d | Z %s', ...
        dep, lab, ternary(pass,'PASS','CHECK'), ok1, nInv, numel(inv), worst, expDir, mm, D, sum(B.segValid), numel(B.segValid), ai.identity, qz.status);
    fprintf('  %s\n', s);
end

function s = stage_sio24a(reg, dep, lab, outRoot, rawRoot, bkRoot, stRoot)
% Build the new L1 into a staging folder and compare it with the live L1.
% Nothing in the catalog is overwritten; L2-L4 wait for stage 'sio24a'.
    fprintf('\n[staging] %s/%s\n', dep, lab);
    try
        fn = reg(dep); cfg = fn(); cfg.outputDir = stRoot;   % diagnostics png goes to staging too
        instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        P = {fullfile(outRoot,'L1',dep,[lab '_processed.mat']), fullfile(outRoot,'L2',dep,[lab '_L2.mat']), ...
             fullfile(outRoot,'L3',dep,[lab '_L3.mat']),        fullfile(outRoot,'L4',dep,[lab '_L4.mat']), ...
             fullfile(outRoot,'L1','diagnostics',[dep '_' lab '_L1_QC.png'])};
        backup_files(P, outRoot, bkRoot);
        cfg = copy_raw_to_local(cfg, rawRoot);
        PUV = PUV_raw_process(instr, cfg);
        dst = fullfile(stRoot,'L1',dep,[lab '_processed.mat']);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        save(dst, 'PUV', '-v7.3');
        s = sprintf('%-7s %-10s STAGED at %s (not promoted); compare with compare_sio24a.m', dep, lab, dst);
        fprintf('  %s\n', s);
    catch ME
        s = sprintf('%-7s %-10s FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
end

function s = promote_sio24a(reg, dep, lab, outRoot, bkRoot, stRoot)
    fprintf('\n[promote] %s/%s\n', dep, lab);
    try
        src = fullfile(stRoot,'L1',dep,[lab '_processed.mat']);
        if ~isfile(src), error('no staged L1 at %s', src); end
        if ~isfile(fullfile(bkRoot,'L1',dep,[lab '_processed.mat'])), error('no backup of the live L1'); end
        fn = reg(dep); cfg = fn(); instr = cfg.instruments(strcmp({cfg.instruments.label}, lab));
        q = load(src, 'PUV'); PUV = q.PUV; clear q
        P = {fullfile(outRoot,'L1',dep,[lab '_processed.mat']), fullfile(outRoot,'L2',dep,[lab '_L2.mat']), ...
             fullfile(outRoot,'L3',dep,[lab '_L3.mat']),        fullfile(outRoot,'L4',dep,[lab '_L4.mat'])};
        copyfile(src, P{1});
        png = fullfile(stRoot,'L1','diagnostics',[dep '_' lab '_L1_QC.png']);
        if isfile(png), copyfile(png, fullfile(outRoot,'L1','diagnostics',[dep '_' lab '_L1_QC.png'])); end
        [L2, ~, L4] = build_L2_L4(PUV, instr, P);
        [~, ai] = l4_l2_index_map(L2, L4); qz = ztest_record_flag(L2.ztest_SS, L2.segValid);
        s = sprintf('%-7s %-10s promoted | %d/%d valid | aligned %d | Z %s', dep, lab, ...
            sum(L2.segValid), numel(L2.segValid), ai.identity, qz.status);
        fprintf('  %s\n', s);
    catch ME
        s = sprintf('%-7s %-10s FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
end

function s = rebuild_xspec(dep, outRoot, bkRoot)
    fprintf('\n[xspec] %s\n', dep);
    try
        xf = fullfile(outRoot,'L4_xspec',dep,'xspec.mat');
        backup_files({xf}, outRoot, bkRoot);
        q = load(fullfile(bkRoot,'L4_xspec',dep,'xspec.mat'),'L4xs'); oldXs = q.L4xs;
        l4 = dir(fullfile(outRoot,'L4',dep,'*_L4.mat'));
        L4xs = PUV_L4_xspec(arrayfun(@(z) fullfile(z.folder,z.name), l4, 'UniformOutput', false), struct());
        save(xf, 'L4xs', '-v7.3');
        fprintf('  %-26s %8s %8s   %9s %9s\n', 'pair', 'sep_old', 'sep_new', 'coh2IG_old', 'coh2IG_new');
        for p = 1:numel(L4xs.pairs)
            pn = L4xs.pairs(p);
            oi = find(arrayfun(@(z) isequal(sort(z.labels), sort(pn.labels)), oldXs.pairs), 1);
            po = oldXs.pairs(oi);
            fprintf('  %-26s %8.1f %8.1f   %9.4f %9.4f\n', sprintf('%s-%s', pn.labels{:}), ...
                po.sep_total, pn.sep_total, po.mean_coh2_IG, pn.mean_coh2_IG);
        end
        s = sprintf('%-7s xspec rebuilt, %d pairs (old %d)', dep, numel(L4xs.pairs), numel(oldXs.pairs));
    catch ME
        s = sprintf('%-7s xspec FAILED: %s', dep, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
end

function LIST = stale_L3_list(reg, outRoot, HDG, SIO)
% Registered records whose L3 ws is the smooth-sphere value for its own D50.
    skip = [strcat(HDG(:,1), '/', HDG(:,2)); {[SIO{1} '/' SIO{2}]}];
    LIST = {};
    ks = reg.keys;
    for i = 1:numel(ks)
        fn = reg(ks{i}); cfg = fn();
        for j = 1:numel(cfg.instruments)
            lab = cfg.instruments(j).label; key = [cfg.name '/' lab];
            if ~strcmp(cfg.name, ks{i}), continue, end            % alias (e.g. TOR23S -> TBR23)
            if any(strcmp(skip, key)), continue, end
            f3 = fullfile(outRoot,'L3',cfg.name,[lab '_L3.mat']);
            if ~isfile(f3), continue, end
            q = load(f3,'L3'); tp = q.L3.transport_params;
            wsN = settling_velocity(tp.D50, tp.rho_s, 1025, 1e-6);
            wsS = settling_velocity(tp.D50, tp.rho_s, 1025, 1e-6, 'shape', 'sphere');
            if abs(tp.ws - wsS) / wsS < 1e-12
                LIST(end+1,:) = {cfg.name, lab, tp.ws, wsN}; %#ok<AGROW>
            elseif abs(tp.ws - wsN) / wsN > 1e-12
                error('PREFLIGHT: %s ws %.6f is neither the natural nor the sphere value', key, tp.ws);
            end
        end
    end
end

function s = regen_L3(dep, lab, outRoot, bkRoot)
% L3-only: PUV_L3_transport on the existing L3. Verified BEFORE saving: ws is
% the natural-grain value, rouse scales by exactly ws_new/ws_old, and every
% other field is unchanged to 1e-12 relative. Any failure leaves the file alone.
    try
        f3 = fullfile(outRoot,'L3',dep,[lab '_L3.mat']); f2 = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        backup_files({f3}, outRoot, bkRoot);
        q = load(fullfile(bkRoot,'L3',dep,[lab '_L3.mat']),'L3'); A = q.L3;
        q = load(f2,'L2'); L2 = q.L2; clear q
        evalc('B = PUV_L3_transport(A, L2);');
        tpA = A.transport_params; tpB = B.transport_params;
        wsN = settling_velocity(tpB.D50, tpB.rho_s, 1025, 1e-6);
        okWs = abs(tpB.ws - wsN)/wsN <= 1e-12 && tpB.ws_C2 == 1;
        okD = isequal(tpA.D50, tpB.D50);
        r = B.rouse ./ A.rouse; m = isfinite(r);
        okR = isequal(isnan(A.rouse), isnan(B.rouse)) && max(abs(r(m) - tpB.ws/tpA.ws)) / (tpB.ws/tpA.ws) <= 1e-12;
        [nf, bad] = compare_struct(A, B, {'rouse','transport_params'}, '');
        [~, badTP] = compare_struct(tpA, tpB, {'ws','ws_C2','code_version'}, 'transport_params.');
        bad = [bad badTP];
        if okWs && okD && okR && isempty(bad)
            L3 = B; save(f3, 'L3', '-v7.3');
            s = sprintf('%-8s %-12s PASS saved | ws %.6f -> %.6f (x%.4f) | rouse ratio exact | %d other fields unchanged', ...
                dep, lab, tpA.ws, tpB.ws, tpB.ws/tpA.ws, nf);
        else
            s = sprintf('%-8s %-12s NOT SAVED | ws ok %d, D50 same %d, rouse ok %d, changed: %s', ...
                dep, lab, okWs, okD, okR, strjoin(bad, ', '));
        end
        fprintf('  %s\n', s);
    catch ME
        s = sprintf('%-8s %-12s FAILED: %s', dep, lab, ME.message);
        fprintf(2, '  FAIL: %s\n', ME.message);
    end
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

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
