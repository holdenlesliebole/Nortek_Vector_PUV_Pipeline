% RUN_CONSEQUENCES_SWEEP  Phase 2 consequences over the whole catalog.
%
% Runs compare_derived_quantities.m for every registered instrument-record.
% Purpose beyond the per-record numbers: settle whether the Ub/Ef error is
% depth-dependent. A 5-record pilot showed a monotonic depth trend, but the
% Phase 1 sweep gives Hs-ratio-vs-depth rho = -0.172 (p = 0.18, not
% significant) with non-monotonic depth bins, and in the pilot depth was
% confounded with season. Only a full sweep with both axes populated can
% separate them.
%
% Writes outputs/validation/cross_deployment_consequences.mat
%   ROWS, SKIPPED, meta
%
% Deduplicates registry aliases (TOR23S -> TBR23_config) so the record count
% matches the server manifest.
%
% Author: Holden Leslie-Bole, 2026

startup_puv

toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

registry    = deployment_registry();
deployNames = sort(keys(registry));

pipelineRoot = fileparts(fileparts(mfilename('fullpath')));
outDir = fullfile(pipelineRoot,'outputs','validation');
if ~isfolder(outDir), mkdir(outDir); end

fprintf('\n================================================================\n');
fprintf(' Consequences sweep — Ub, Ef, IG, Shields, alongshore\n');
fprintf('================================================================\n\n');

ROWS = struct([]); SKIPPED = struct([]);
nAttempt = 0; t0 = tic;
seen = containers.Map('KeyType','char','ValueType','logical');

for d = 1:numel(deployNames)
    try
        configFn = registry(deployNames{d});
        cfg = configFn();
    catch
        continue
    end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true; %#ok<NASGU>

    l2Dir = fullfile(cfg.outputDir,'L2',cfg.name);
    if ~isfolder(l2Dir), continue; end
    files = dir(fullfile(l2Dir,'*_L2.mat'));
    if isempty(files), continue; end

    fprintf('[%2d/%2d] %s\n', d, numel(deployNames), cfg.name);
    for k = 1:numel(files)
        nAttempt = nAttempt + 1;
        try
            S = load(fullfile(files(k).folder, files(k).name));
            R = compare_derived_quantities(S.L2, struct('verbose', false));
        catch ME
            R = struct('status',['error: ' ME.message], 'deployment',cfg.name, ...
                       'label',erase(files(k).name,'_L2.mat'), 'station','');
        end
        if isempty(R.status)
            R.seg = []; R.retention = [];
            fprintf('   %-13s h=%5.1f  Ub %.3f [E %.3f x S %.3f]  Ef %.3f  tau %.3f  mob %.3f  SxyR %+.2f\n', ...
                R.label, R.h_median, R.Ub_ratio, R.Ub_energy_factor, R.Ub_shape_factor, ...
                R.Ef_ratio, R.tau_ratio, R.mobil_hours_ratio, R.Sxy_R);
            if isempty(ROWS), ROWS = R; else, ROWS(end+1) = orderfields(R, ROWS); end %#ok<SAGROW>
        else
            fprintf('   [skip] %-13s %s\n', R.label, R.status);
            s = struct('deployment',R.deployment,'label',R.label,'station',R.station,'status',R.status);
            if isempty(SKIPPED), SKIPPED = s; else, SKIPPED(end+1) = s; end %#ok<SAGROW>
        end
    end
end
elapsed = toc(t0);

%% ---- Summary -----------------------------------------------------------
fprintf('\n================================================================\n');
fprintf(' %d of %d records produced metrics (%.1f min)\n', numel(ROWS), nAttempt, elapsed/60);
fprintf('================================================================\n\n');

meta = struct('created', datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
              'nAttempted', nAttempt, 'nSucceeded', numel(ROWS), ...
              'elapsed_min', elapsed/60); %#ok<TNOW1,DATST>
save(fullfile(outDir,'cross_deployment_consequences.mat'), 'ROWS','SKIPPED','meta');
fprintf('\nSaved: %s\n\n', fullfile(outDir,'cross_deployment_consequences.mat'));

if ~isempty(ROWS)
    h  = [ROWS.h_median]';   ub = [ROWS.Ub_ratio]';
    en = [ROWS.Ub_energy_factor]'; shp = [ROWS.Ub_shape_factor]';
    ef = [ROWS.Ef_ratio]';   ta = [ROWS.tau_ratio]';
    mo = [ROWS.mobil_hours_ratio]'; ig = [ROWS.IG_var_fraction]';
    sr = [ROWS.Sxy_R]';      sb = [ROWS.spectrum_beats_bulk]';
    b0 = [ROWS.Sxy_b0]';     ng = [ROWS.Pl_cancellation_puv]';
    na = [ROWS.Sxy_nrmse_abs]'; pn = [ROWS.Pl_net_ratio]';
    pg = [ROWS.Pl_gross_ratio]';
    thP = [ROWS.theta_puv_med]'; thA = [ROWS.theta_puv_absmed]';
    dth = [ROWS.dtheta_med]';    sag = [ROWS.sign_agree]';
    mline = zeros(numel(ROWS),1);
    for i = 1:numel(ROWS)
        tk = regexp(ROWS(i).station,'(\d+)','tokens','once');
        if ~isempty(tk), mline(i) = str2double(tk{1}); else, mline(i) = NaN; end
    end

    pr = @(n,v) fprintf('  %-26s %7.3f  [IQR %6.3f - %6.3f]  n=%d\n', n, ...
        median(v,'omitnan'), prctile(v,25), prctile(v,75), sum(isfinite(v)));
    fprintf('--- Cross-catalog medians ---\n');
    pr('Ub ratio (model/PUV)', ub);
    pr('  energy factor', en);
    pr('  SHAPE factor', shp);
    pr('Ef ratio', ef);
    pr('tau_b ratio', ta);
    pr('mobilized-hours ratio', mo);
    pr('IG share of near-bed var', ig);
    pr('Sxy slope b0 (thru origin)', b0);
    pr('Sxy nRMSE / mean|Sxy|', na);
    pr('alongshore gross-flux ratio', pg);
    pr('  [descriptor] Sxy corr', sr);
    pr('spectrum-beats-bulk margin', sb);

    fprintf('\n--- THE DEPTH QUESTION ---\n');
    vars = {'Ub ratio',ub; 'energy factor',en; 'shape factor',shp; ...
            'Ef ratio',ef; 'tau ratio',ta; 'IG share',ig};
    for i = 1:size(vars,1)
        m = isfinite(h) & isfinite(vars{i,2});
        [rr,pp] = corr(h(m), vars{i,2}(m), 'type','Spearman');
        star = ''; if pp < 0.05, star = ' *'; end
        fprintf('  %-16s vs depth : rho = %+.3f  (p = %.3g)%s\n', vars{i,1}, rr, pp, star);
    end

    edges = [0 6 8 9.5 12 20 40];
    fprintf('\n  binned by depth:\n');
    fprintf('  %-12s %4s %9s %9s %9s %9s\n','band','n','Ub','energy','shape','Ef');
    for b = 1:numel(edges)-1
        m = h >= edges(b) & h < edges(b+1) & isfinite(ub);
        if ~any(m), continue; end
        fprintf('  %4.1f-%4.1f m %4d %9.3f %9.3f %9.3f %9.3f\n', edges(b), edges(b+1), ...
            sum(m), median(ub(m)), median(en(m)), median(shp(m)), median(ef(m),'omitnan'));
    end

    % Season, to break the pilot's depth/season confound
    fprintf('\n--- SEASON (deployment code S=summer, W=winter) ---\n');
    dn = {ROWS.deployment}';
    isW = contains(dn,'W') & ~contains(dn,'RUBY');
    isS = contains(dn,'S') & ~contains(dn,'SIO') & ~contains(dn,'SOL');
    fprintf('  winter-coded n=%d: Ub %.3f, energy %.3f\n', sum(isW), median(ub(isW),'omitnan'), median(en(isW),'omitnan'));
    fprintf('  summer-coded n=%d: Ub %.3f, energy %.3f\n', sum(isS), median(ub(isS),'omitnan'), median(en(isS),'omitnan'));
    fprintf('  (crude coding from deployment names; refine before quoting)\n');

    fprintf('\n--- ALONGSHORE FORCING ---\n');
    fprintf('  Metric is the THROUGH-ORIGIN slope b0 = sum(x*y)/sum(x^2) of model\n');
    fprintf('  on observed Sxy. Correlation is reported as a descriptor only; it was\n');
    fprintf('  retired as a quality gate 2026-07-27 (see below).\n\n');

    gb = isfinite(b0);
    fprintf('  b0 median %.3f  [IQR %.3f - %.3f]  n=%d\n', ...
        median(b0(gb)), prctile(b0(gb),25), prctile(b0(gb),75), sum(gb));
    fprintf('  records with b0 < 0 (genuine frame/handedness failure): %d of %d\n', ...
        sum(b0 < 0), sum(gb));
    [pw,~,st] = signrank(b0(gb) - 1);   %#ok<ASGLU>
    fprintf('  H0: b0 = 1 (model reproduces alongshore forcing) -> p = %.3g\n', pw);
    fprintf('  net alongshore flux ratio  median %.3f  [IQR %.3f - %.3f]\n', ...
        median(pn,'omitnan'), prctile(pn,25), prctile(pn,75));
    fprintf('  gross alongshore flux ratio median %.3f  [IQR %.3f - %.3f]\n', ...
        median(pg,'omitnan'), prctile(pg,25), prctile(pg,75));
    fprintf('  |net|/gross (PUV)          median %.3f  [IQR %.3f - %.3f]\n', ...
        median(ng,'omitnan'), prctile(ng,25), prctile(ng,75));

    % THE CONDITIONING TEST. If b0 is properly conditioned, its association
    % with |net|/gross should be far weaker than the correlation's.
    m = isfinite(ng) & isfinite(sr) & isfinite(b0);
    [rR,pR] = corr(ng(m), sr(m),  'type','Spearman');
    [r0,p0] = corr(ng(m), b0(m),  'type','Spearman');
    [ra,pa] = corr(ng(m), na(m),  'type','Spearman');
    [rn,pn2]= corr(ng(m), [ROWS(m).Sxy_nrmse]', 'type','Spearman');
    fprintf('\n  CONDITIONING (association with |net|/gross; near zero = well conditioned):\n');
    fprintf('    correlation Sxy_R        rho = %+.3f (p = %.3g)   <- the artifact\n', rR, pR);
    fprintf('    slope b0                 rho = %+.3f (p = %.3g)\n', r0, p0);
    fprintf('    nRMSE / sd(Sxy)  [old]   rho = %+.3f (p = %.3g)\n', rn, pn2);
    fprintf('    nRMSE / mean|Sxy| [new]  rho = %+.3f (p = %.3g)\n', ra, pa);
    fprintf('  Derivation: Var(b_freeIntercept)/Var(b0) = 1 + mean(x)^2/var(x), so a\n');
    fprintf('  one-signed record makes the mean-referenced statistics noisy while b0\n');
    fprintf('  is unaffected. Confirmed synthetically to 3 significant figures, and a\n');
    fprintf('  correct frame was shown to yield R < 0 in up to 27%% of trials at high\n');
    fprintf('  |net|/gross while b0 never once changed sign.\n');

    % ================= FRAME ERROR OR MODEL FAILURE? =====================
    % Two explanations for b0 < 0. They make different predictions:
    %   FRAME  -- our MOP shore-normal is wrong by a fixed angle for a given
    %             MOP line. Then dtheta = theta_mop - theta_puv is a CONSTANT
    %             offset within a line, and sign flips concentrate where the
    %             true obliquity is SMALL (a small rotation flips the sign of
    %             sin(2 theta) only when theta is near zero).
    %   MODEL  -- MOP mis-states the directional distribution. Then the error
    %             should track obliquity or forcing ACROSS sites, and sign
    %             flips should NOT prefer small theta.
    fprintf('\n--- FRAME ERROR OR MODEL FAILURE? ---\n');
    gq = isfinite(b0) & isfinite(thA) & isfinite(dth);
    fprintf('  observed obliquity |theta| median %.1f deg  [IQR %.1f - %.1f]\n', ...
        median(thA(gq)), prctile(thA(gq),25), prctile(thA(gq),75));
    fprintf('  hourly SIGN agreement median %.3f  [IQR %.3f - %.3f]\n', ...
        median(sag(gq)), prctile(sag(gq),25), prctile(sag(gq),75));

    % Prediction 1: do sign failures concentrate at SMALL obliquity?
    neg = b0 < 0;
    fprintf('\n  [P1] obliquity of sign-reversed vs sign-correct records:\n');
    fprintf('    b0 <  0 : |theta| median %5.2f deg (n=%d)\n', median(thA(gq & neg)), sum(gq&neg));
    fprintf('    b0 >= 0 : |theta| median %5.2f deg (n=%d)\n', median(thA(gq & ~neg)), sum(gq&~neg));
    if sum(gq&neg) > 3 && sum(gq&~neg) > 3
        pRS = ranksum(thA(gq&neg), thA(gq&~neg));
        if pRS < 0.05, verdictP1 = 'DIFFERENT'; else, verdictP1 = 'not distinguishable'; end
        fprintf('    rank-sum p = %.3g  -> %s\n', pRS, verdictP1);
    end
    [rt,pt] = corr(thA(gq), b0(gq), 'type','Spearman');
    fprintf('    rho(|theta|, b0) = %+.3f (p = %.3g)\n', rt, pt);

    % Prediction 2: is dtheta a fixed per-line offset?
    fprintf('\n  [P2] dtheta = theta_mop - theta_puv, by MOP line (>=2 records):\n');
    fprintf('    %6s %4s %9s %9s %9s\n','line','n','mean dth','sd dth','mean b0');
    ul = unique(mline(gq & isfinite(mline)));
    wSD = []; bSD = [];
    for L = ul'
        m = gq & mline == L;
        if sum(m) < 2, continue; end
        fprintf('    %6d %4d %9.2f %9.2f %9.3f\n', L, sum(m), mean(dth(m)), std(dth(m)), mean(b0(m)));
        wSD(end+1) = std(dth(m)); bSD(end+1) = std(b0(m)); %#ok<SAGROW>
    end
    if ~isempty(wSD)
        fprintf('    within-line sd of dtheta : median %.2f deg   (total sd %.2f)\n', ...
            median(wSD), std(dth(gq)));
        fprintf('    -> a pure per-line frame error predicts within-line sd << total sd\n');
    end
    fprintf('    catalog-wide dtheta: median %+.2f deg, IQR %+.2f to %+.2f\n', ...
        median(dth(gq)), prctile(dth(gq),25), prctile(dth(gq),75));

    nBad = sum(sr < 0);
    if nBad > 0
        fprintf('\n  The %d records with negative CORRELATION, now scored by b0:\n', nBad);
        fprintf('    %-9s %-13s %6s %8s %8s %9s\n','deploy','label','h','Sxy_R','b0','|net|/gr');
        for i = find(sr < 0)'
            fprintf('    %-9s %-13s %6.1f %+8.3f %8.3f %9.3f\n', ...
                ROWS(i).deployment, ROWS(i).label, h(i), sr(i), b0(i), ng(i));
        end
        fprintf('    (TOR16B is the proof: it had a REAL heading error, R2_swell 5.53;\n');
        fprintf('     correcting it drove R2_swell to 0.005 and made Sxy_R WORSE, -0.507.)\n');
    end
end

if ~isempty(SKIPPED)
    fprintf('\n--- Skipped: %d ---\n', numel(SKIPPED));
    for i = 1:numel(SKIPPED)
        fprintf('  %-9s %-14s %s\n', SKIPPED(i).deployment, SKIPPED(i).label, SKIPPED(i).status);
    end
end


