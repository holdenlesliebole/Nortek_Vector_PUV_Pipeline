% RUN_HARMONIC_CLOSURE_SUFFICIENT  The sufficient condition for the harmonic
% mechanism, computed through the established matched-shape code path.
%
% THE QUESTION. findings_harmonic_closure_2026-07-29.md closed the mechanism's
% NECESSARY condition: the nonlinearity dependence of the OBSERVED spectral
% shape statistic nu lives entirely in the second-harmonic band (truncating
% below 1.5 fp reverses rho(Ursell, nu) from +0.294 to -0.406). That is a
% statement about the PUV spectrum alone. The paper's claim concerns the
% model-observation DISCREPANCY, so the sufficient condition needs the same
% fp-relative truncation applied to BOTH sides:
%
%   does the nu RATIO collapse toward unity when the band stops below 2 fp?
%
% WHY THIS DRIVER RATHER THAN test_harmonic_closure_ratio.m. That standalone
% attempt returned a full-band nu ratio of 0.842 where the matched-shape sweep
% gives 1.045 -- same statistic, opposite sign of departure -- and its rho was
% non-monotonic in the cut. Diagnosed 2026-07-29: it fed the PUV side L2.Spp,
% the raw PRESSURE spectrum, where the established path uses L2.S_eta, the
% surface spectrum. Since S_pp = Kp^2 * S_eta with Kp = cosh(kd)/cosh(kh), the
% missing 1/Kp^2 suppresses the high-frequency tail -- roughly 4x more at
% 0.20 Hz than at a 0.08 Hz peak -- which deflates m2 and hence nu_puv. It also
% explains the non-monotonicity: the contamination grows with band width, so
% the full band was its worst case. The estimator was correctly eliminated as a
% cause; the input was the problem.
%
% Computing the truncation inside compare_shape_matched.m (opts.fpMultList)
% removes that whole class of error: same S_eta, same shoaled model spectrum,
% same shape_coarse, same ratio-of-medians estimator, same band on both sides.
%
% BUILT-IN CLOSURE CHECK. The Inf multiplier reduces the band to exactly the
% script's main iB, so its nu ratio must reproduce the established
% ratio-of-medians (1.034 catalog-wide). If it does not, this implementation is
% wrong and nothing else in the output should be believed. That check is printed
% first and is the reason to trust the truncated rows.
%
% Writes outputs/validation/harmonic_closure_sufficient.mat
%   ROWS  per-record reductions (per-hour arrays dropped)
%   P     pooled per-hour arrays: ursell, hsh, rec, nuPuv/nuMop per cut
%   CUTS  the fp multipliers
%
% Author: Holden Leslie-Bole, 2026

startup_puv

toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

CUTS = [1.5 1.75 2.5 Inf];

registry    = deployment_registry();
deployNames = sort(keys(registry));

pipelineRoot = fileparts(fileparts(mfilename('fullpath')));
outDir       = fullfile(pipelineRoot,'outputs','validation');
if ~isfolder(outDir), mkdir(outDir); end

fprintf('\n================================================================\n');
fprintf(' Sufficient condition: nu RATIO vs fp-relative band limit\n');
fprintf(' Established path (S_eta + shoaled model + shape_coarse)\n');
fprintf('================================================================\n\n');

ROWS = struct([]); SKIPPED = struct([]);
P = struct('ursell',[],'hsh',[],'rec',[],'nuPuv',[],'nuMop',[]);
nAttempt = 0; nRec = 0; nExcl = 0; t0 = tic;
seenRecord = containers.Map('KeyType','char','ValueType','logical');

for d = 1:numel(deployNames)
    try
        configFn = registry(deployNames{d});
        cfg = configFn();
    catch
        continue
    end
    if isKey(seenRecord, cfg.name), continue; end
    seenRecord(cfg.name) = true; %#ok<NASGU>

    l2Dir = fullfile(cfg.outputDir,'L2',cfg.name);
    if ~isfolder(l2Dir), continue; end
    files = dir(fullfile(l2Dir,'*_L2.mat'));
    if isempty(files), continue; end

    fprintf('[%2d/%2d] %s (%d records)\n', d, numel(deployNames), cfg.name, numel(files));

    for k = 1:numel(files)
        lab = erase(files(k).name,'_L2.mat');

        % Reporting-time exclusions, centralized in shared/excluded_records.m.
        [isEx, exReason] = excluded_records(cfg.name, lab);
        if isEx
            nExcl = nExcl + 1;
            fprintf('        [excluded] %-14s %s\n', lab, exReason(1:min(70,end)));
            continue
        end

        nAttempt = nAttempt + 1;
        try
            S = load(fullfile(files(k).folder, files(k).name)); L2 = S.L2;
            R = compare_shape_matched(L2, struct('verbose', false, 'fpMultList', CUTS));
        catch ME
            R = struct('status',['error: ' ME.message], 'deployment',cfg.name, ...
                       'label',lab, 'station','');
        end

        if isempty(R.status)
            nRec = nRec + 1;
            sg = R.seg;
            g  = isfinite(sg.ursell) & all(isfinite(sg.nu_puv_byFpMult),2) ...
                                     & all(isfinite(sg.nu_mop_byFpMult),2);
            P.ursell = [P.ursell; sg.ursell(g)];
            P.hsh    = [P.hsh;    sg.hsh(g)];
            P.rec    = [P.rec;    repmat(nRec, sum(g), 1)];
            P.nuPuv  = [P.nuPuv;  sg.nu_puv_byFpMult(g,:)];
            P.nuMop  = [P.nuMop;  sg.nu_mop_byFpMult(g,:)];

            fprintf('        %-14s n=%4d  nu ratio [', lab, sum(g));
            fprintf('%.3f ', R.nu_ratio_byFpMult); fprintf('] full=%.3f\n', R.nu_ratio);

            R.seg = []; R.time = [];
            if isempty(ROWS), ROWS = R; else, ROWS(end+1) = orderfields(R, ROWS); end %#ok<SAGROW>
        else
            fprintf('        [skip] %-14s %s\n', lab, R.status);
            s = struct('deployment',R.deployment,'label',R.label, ...
                       'station',R.station,'status',R.status);
            if isempty(SKIPPED), SKIPPED = s; else, SKIPPED(end+1) = s; end %#ok<SAGROW>
        end
    end
end

elapsed = toc(t0);

%% ---- Closure check FIRST: does the Inf row reproduce the sweep? --------
fprintf('\n================================================================\n');
fprintf(' CLOSURE CHECK — Inf cut must equal the established full band\n');
fprintf('================================================================\n');
iInf = find(~isfinite(CUTS), 1);
if ~isempty(ROWS) && ~isempty(iInf)
    perRec = arrayfun(@(r) r.nu_ratio_byFpMult(iInf), ROWS);
    estab  = [ROWS.nu_ratio];
    nuP = arrayfun(@(r) r.nu_puv_byFpMult(iInf), ROWS);
    nuM = arrayfun(@(r) r.nu_mop_byFpMult(iInf), ROWS);
    gg = isfinite(perRec) & isfinite(estab);
    fprintf('  per-record: median Inf-cut ratio %.4f vs established nu_ratio %.4f\n', ...
        median(perRec(gg)), median(estab(gg)));
    fprintf('  max |difference| across records: %.2e  (should be ~0)\n', ...
        max(abs(perRec(gg) - estab(gg))));
    fprintf('  pooled ratio-of-medians: %.4f  (catalog reference 1.034)\n', ...
        median(nuP(gg))/median(nuM(gg)));
    if max(abs(perRec(gg) - estab(gg))) > 1e-6
        fprintf('\n  *** CLOSURE FAILED — do not trust the truncated rows below. ***\n');
    else
        fprintf('  -> closure OK; the truncated rows below use the same path.\n');
    end
end

%% ---- The result -------------------------------------------------------
fprintf('\n================================================================\n');
fprintf(' RESULT — %d records, %d hours, %d excluded, %.1f min\n', ...
    nRec, numel(P.ursell), nExcl, elapsed/60);
fprintf('================================================================\n\n');

if ~isempty(P.ursell)
    fprintf('  %-16s %8s %8s %10s %12s %8s\n', ...
        'band limit','nu_puv','nu_mop','nu ratio','rho(ur,ratio)','n');
    for c = 1:numel(CUTS)
        p = P.nuPuv(:,c); m = P.nuMop(:,c);
        g = isfinite(p) & isfinite(m) & m > 0;
        if ~any(g), continue; end
        ratioOfMed = median(p(g))/median(m(g));
        perHour    = p(g)./m(g);
        rho = corr(P.ursell(g), perHour, 'type','Spearman');
        lbl = 'full band'; if isfinite(CUTS(c)), lbl = sprintf('%.2f fp', CUTS(c)); end
        fprintf('  %-16s %8.4f %8.4f %10.4f %+12.3f %8d\n', ...
            lbl, median(p(g)), median(m(g)), ratioOfMed, rho, sum(g));
    end

    % Per-RECORD inference. The pooled hour count (~72k) is not a sample size --
    % hours within a record are strongly autocorrelated, so a p-value on 72k
    % hours is meaningless and a rho of +0.017 will read as "significant". The
    % defensible test is the per-record ratio against unity, n = number of
    % records, which is what should be quoted.
    fprintf('\n  Per-record ratio, signed-rank against unity (this is the quotable test):\n');
    recIds = unique(P.rec);
    for c = 1:numel(CUTS)
        per = NaN(numel(recIds),1);
        for q = 1:numel(recIds)
            s = P.rec == recIds(q) & isfinite(P.nuPuv(:,c)) & isfinite(P.nuMop(:,c)) ...
                & P.nuMop(:,c) > 0;
            if sum(s) > 20
                per(q) = median(P.nuPuv(s,c)) / median(P.nuMop(s,c));
            end
        end
        per = per(isfinite(per));
        lbl = 'full band'; if isfinite(CUTS(c)), lbl = sprintf('%.2f fp', CUTS(c)); end
        if numel(per) > 5
            pv = signrank(per, 1);
            fprintf('   %-16s median %.4f  n=%3d  p=%.3g\n', lbl, median(per), numel(per), pv);
        end
    end

    fprintf('\n  Interpretation guide:\n');
    fprintf('   - If the nu RATIO collapses toward 1.000 as the band stops below\n');
    fprintf('     2 fp, the harmonic band accounts for the model-observation shape\n');
    fprintf('     discrepancy: the SUFFICIENT condition.\n');
    fprintf('   - If it stays at ~1.045 under truncation, the discrepancy is\n');
    fprintf('     broadband and the harmonic localization is incidental.\n');
    fprintf('   - rho is on per-hour ratios and is the noisier statistic; the\n');
    fprintf('     ratio-of-medians column is the primary result.\n');
end

meta = struct('created', datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
              'nRecords', nRec, 'nHours', numel(P.ursell), ...
              'nExcluded', nExcl, 'elapsed_min', elapsed/60, ...
              'spectrum', 'L2.S_eta (surface); NOT Spp -- see header', ...
              'code', 'compare_shape_matched.m opts.fpMultList');
save(fullfile(outDir,'harmonic_closure_sufficient.mat'), 'ROWS','SKIPPED','P','CUTS','meta');
fprintf('\nSaved harmonic_closure_sufficient.mat\n');
