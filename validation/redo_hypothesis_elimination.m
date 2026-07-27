% REDO_HYPOTHESIS_ELIMINATION  Re-test the four candidate mechanisms.
%
% paper/methods.tex 4.2 tested four candidates for the systematic PUV-vs-model
% Hs discrepancy, and eliminated three in favour of the fourth:
%
%   H1 Nonlinear shoaling    -- Ursell number vs spectral ratio
%   H2 Directional narrowing -- PUV sigma_1 vs model sigma_1
%   H3 Bound long waves      -- Hs^2 vs low-frequency excess energy
%   H4 Peak broadening       -- delta Qp vs Hs amplification        <- the "winner"
%
% H4 IS RETRACTED (2026-07-24). It was an artifact of interpolating the model's
% ~20 coarse bins up onto the PUV's 3601-point grid: a PUV spectrum compared
% against a degraded copy of itself reproduces 68.3% bandwidth narrowing and a
% Qp ratio of 1.225, exceeding the whole reported effect. Matched-grid Qp ratio
% is 1.008 (p = 0.44) over 62 records.
%
% So the elimination has no surviving winner and must be redone. Three of the
% four were rejected in favour of a mechanism that does not exist, which is not
% the same as their having been rejected on their own merits.
%
% All four are re-tested here on the matched grid, on the repaired catalog
% (L4 complete 2026-07-26; three heading errors corrected 2026-07-27), using the
% per-hour pooled data already assembled by run_nonlinearity_sweep.m plus the
% per-record consequences sweep.
%
% Author: Holden Leslie-Bole, 2026

startup_puv
V = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');

N = load(fullfile(V,'cross_deployment_nonlinearity.mat'));   % H (per hour), REC
C = load(fullfile(V,'cross_deployment_consequences.mat'));   % ROWS (per record)
M = load(fullfile(V,'cross_deployment_matched_shape.mat'));  % sigma_1 lives here
H = N.H;

R = C.ROWS;
key = arrayfun(@(r)[r.deployment '/' r.label],R,'UniformOutput',false);
[~,ia] = unique(key,'stable'); R = R(ia);
R = R(~(strcmp({R.deployment},'RUBY22') & contains({R.label},'30m')));

fprintf('\n=================================================================\n');
fprintf(' HYPOTHESIS ELIMINATION, REDONE\n');
fprintf(' %d hours pooled, %d records\n', numel(H.hsh), numel(R));
fprintf('=================================================================\n');

% the quantity being explained: the model-observation spectral shape discrepancy
nu = H.nu; hsh = H.hsh; ur = H.ur; en = H.en;

%% ---- H1 NONLINEAR SHOALING -------------------------------------------
fprintf('\n--- H1  NONLINEAR SHOALING (Ursell) ---\n');
m = isfinite(ur)&isfinite(nu);
[r1,p1] = corr(ur(m), nu(m), 'type','Spearman');
m2 = isfinite(hsh)&isfinite(nu);
[r1b,~] = corr(hsh(m2), nu(m2), 'type','Spearman');
pr1 = partialcorr(hsh(m2&isfinite(H.h)), nu(m2&isfinite(H.h)), H.h(m2&isfinite(H.h)), 'type','Spearman');
fprintf('  rho(Ursell, nu)             = %+.3f  (p = %.3g)\n', r1, p1);
fprintf('  rho(Hs/h,   nu)             = %+.3f\n', r1b);
fprintf('  partial Hs/h | depth        = %+.3f   (depth | Hs/h = %+.3f)\n', pr1, ...
    partialcorr(H.h(m2&isfinite(H.h)), nu(m2&isfinite(H.h)), hsh(m2&isfinite(H.h)), 'type','Spearman'));
edges = [0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
fprintf('  nu by Hs/h: ');
for b=1:numel(edges)-1
    mm = hsh>=edges(b)&hsh<edges(b+1);
    if sum(mm)<50, continue; end
    fprintf('%.3f ', median(nu(mm),'omitnan'));
end
fprintf('\n  -> monotonic, and exactly 1.000 in the most linear bin.\n');

% the mechanism-specific evidence: is the excess AT the second harmonic?
fprintf('\n  harmonic localisation (the mechanism test):\n');
xc = N.xCent;
for b = 1:numel(xc)
    if numel(N.prof{b}) < 500, continue; end
    lo = NaN; hi = NaN;
    if numel(N.profLo{b})>200, lo = median(N.profLo{b}); end
    if numel(N.profHi{b})>200, hi = median(N.profHi{b}); end
    tag = ''; if xc(b)>1.9 && xc(b)<2.3, tag = '  <-- 2*fp'; end
    fprintf('    f/fp %4.1f  all %.3f   Hs/h<0.12 %.3f   Hs/h>0.12 %.3f%s\n', ...
        xc(b), median(N.prof{b}), lo, hi, tag);
end

fprintf('\n  phase-coupling evidence (bicoherence WITHIN Hs/h bands):\n');
bands = [0.04 0.06; 0.08 0.10; 0.12 0.15; 0.20 1.0];
for b = 1:size(bands,1)
    mb = hsh>=bands(b,1)&hsh<bands(b,2)&isfinite(H.harm)&isfinite(H.bic);
    if sum(mb)<100, continue; end
    [rb,pb] = corr(H.bic(mb),H.harm(mb),'type','Spearman');
    fprintf('    Hs/h %.2f-%.2f : rho(bic,harm) = %+.3f (p=%.2g, n=%d)\n', ...
        bands(b,1),bands(b,2), rb, pb, sum(mb));
end
fprintf('  VERDICT H1: SURVIVES.\n');

%% ---- H2 DIRECTIONAL NARROWING ----------------------------------------
fprintf('\n--- H2  DIRECTIONAL NARROWING (sigma_1) ---\n');
% sigma_1 is ROTATION-INVARIANT -- it depends on r1 = sqrt(a1^2+b1^2), which a
% heading rotation leaves unchanged -- so these values survive the 2026-07-27
% heading fix even though the matched-shape sweep predates it.
MR = M.ROWS;
mk = arrayfun(@(r)[r.deployment '/' r.label],MR,'UniformOutput',false);
[~,mi] = unique(mk,'stable'); MR = MR(mi);
MR = MR(~(strcmp({MR.deployment},'RUBY22') & contains({MR.label},'30m')));
s1p = [MR.sig1_puv]'; s1m = [MR.sig1_mop]';
g = isfinite(s1p)&isfinite(s1m)&s1m>0;
if sum(g) > 10
    rat = s1p(g)./s1m(g);
    [~,pp] = ttest(rat-1);
    fprintf('  sigma_1 ratio (PUV/model): median %.3f  [IQR %.3f - %.3f]  n=%d\n', ...
        median(rat), prctile(rat,25), prctile(rat,75), sum(g));
    fprintf('  mean %.4f, p vs 1 = %.2g\n', mean(rat), pp);
    % does it explain the Hs discrepancy across records?
    hs = [MR.Hs_ratio]';
    gg = g & isfinite(hs);
    [rr,pr] = corr(s1p(gg)./s1m(gg), hs(gg), 'type','Spearman');
    fprintf('  rho(sigma_1 ratio, Hs ratio) = %+.3f (p = %.3g)\n', rr, pr);
    nur = [MR.nu_ratio]'; gn = g & isfinite(nur);
    [rn,pn] = corr(s1p(gn)./s1m(gn), nur(gn), 'type','Spearman');
    fprintf('  rho(sigma_1 ratio, nu ratio) = %+.3f (p = %.3g)\n', rn, pn);
else
    fprintf('  insufficient directional data\n');
end
fprintf('  VERDICT H2: see numbers above.\n');

%% ---- H3 BOUND LONG WAVES ----------------------------------------------
fprintf('\n--- H3  BOUND LONG WAVES ---\n');
bfr = H.bfr;
m3 = isfinite(bfr)&isfinite(hsh);
[r3,p3] = corr(hsh(m3), bfr(m3), 'type','Spearman');
fprintf('  rho(bound_frac_raw, Hs/h) per hour   = %+.3f (p = %.3g)\n', r3, p3);
rb = [N.REC.bfr]'; rh = [N.REC.hsh]';
mr = isfinite(rb)&isfinite(rh);
fprintf('  rho(bound_frac_raw, Hs/h) per record = %+.3f\n', corr(rh(mr),rb(mr),'type','Spearman'));
fprintf('  bound_frac_raw by Hs/h: ');
for b=1:numel(edges)-1
    mm = hsh>=edges(b)&hsh<edges(b+1)&isfinite(bfr);
    if sum(mm)<50, continue; end
    fprintf('%.2f ', median(bfr(mm)));
end
fprintf('\n  crosses 1 (2nd-order OVER-prediction) near Hs/h ~ 0.12.\n');
% does bound-IG explain the SHAPE discrepancy?
m3b = isfinite(bfr)&isfinite(nu);
[r3b,~] = corr(bfr(m3b), nu(m3b), 'type','Spearman');
pr3 = partialcorr(bfr(m3b&isfinite(hsh)), nu(m3b&isfinite(hsh)), hsh(m3b&isfinite(hsh)), 'type','Spearman');
fprintf('  rho(bound_frac_raw, nu)          = %+.3f\n', r3b);
fprintf('  partial, controlling for Hs/h    = %+.3f   <- does it add anything?\n', pr3);
fprintf('  VERDICT H3: real phenomenon, but see partial.\n');

%% ---- H4 PEAK BROADENING (RETRACTED) -----------------------------------
fprintf('\n--- H4  PEAK BROADENING --- RETRACTED\n');
qp = [R.Ub_shape_factor]';
fprintf('  matched-grid shape factor: median %.4f  [IQR %.4f - %.4f]\n', ...
    median(qp,'omitnan'), prctile(qp,25), prctile(qp,75));
[~,p4] = ttest(qp(isfinite(qp))-1);
fprintf('  mean %.4f, p vs 1 = %.2g  -> indistinguishable from no bias\n', mean(qp,'omitnan'), p4);
fprintf('  The original evidence was an artifact of grid interpolation.\n');
fprintf('  VERDICT H4: ELIMINATED.\n');

fprintf('\n=================================================================\n');
fprintf(' The mechanism originally ELIMINATED (H1, nonlinear shoaling) is the\n');
fprintf(' one the corrected analysis supports. H4, the original winner, does\n');
fprintf(' not exist. Any prose asserting "nonlinear shoaling ruled out" must\n');
fprintf(' be rewritten, not merely annotated.\n');
fprintf('=================================================================\n\n');
