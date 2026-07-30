% TEST_SKEWNESS_PROXY  Can a single-parameter nonlinearity measure predict wave
% skewness, or does phase coupling carry independent information?
%
%   test_skewness_proxy
%
% BACKGROUND. A reduced-complexity proxy of the form u_skew ~ 12.1 * k_eff *
% sigma_u predicts velocity skewness from a single frequency (k_eff from Tp) and
% a single amplitude scale. Paper_3 found the MOP-driven version of that proxy
% fails, and that full-spectrum, Tp-independent predictors rescue it -- an
% empirical result with no mechanism attached. This catalog carries the
% diagnostics that can supply one: observed skewness, Ursell, Hs/h, bicoherence
% and the harmonic-band excess, on the same 70k hours.
%
% FOUR TESTS
%   1. What does skewness actually track? If Ursell wins, the proxy targets the
%      right variable and the question is completeness, not form.
%   2. Does the Ursell-skewness relation hold across regimes? Computed within
%      Hs/h bands.
%   3. IS TEST 2 JUST SIGNAL-TO-NOISE? Skewness is ~0.02 in the most linear
%      band and ~0.36 in the most nonlinear one, so a rank correlation will rise
%      with Hs/h for purely statistical reasons. Correlation is scale-free and
%      SNR-sensitive; the REGRESSION SLOPE of skewness on Ursell is not. If the
%      slope is flat while rho climbs, the climb is SNR and means nothing about
%      physics. This test is the reason the first pass at this question could
%      not be trusted.
%   4. Does bicoherence explain skewness BEYOND Ursell? This is the one that
%      bears on the proxy: if the partial correlation survives, no
%      single-parameter measure can be complete, whatever its functional form.
%
% Every test is repeated per record, because 70k pooled hours over 61 records
% with very unequal lengths will overstate any pooled statistic.
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
S = load(fullfile(root,'cross_deployment_nonlinearity.mat'));
H = S.H;

g = isfinite(H.skew) & isfinite(H.hsh) & isfinite(H.ur) & isfinite(H.bic) & isfinite(H.harm);
fprintf('\n%d of %d hours carry skewness + all nonlinearity diagnostics\n', sum(g), numel(H.skew));
fprintf('skewness: median %.3f  [IQR %.3f - %.3f]  range %.3f to %.3f\n', ...
    median(H.skew(g)), prctile(H.skew(g),25), prctile(H.skew(g),75), ...
    min(H.skew(g)), max(H.skew(g)));

%% ---- 1. what does skewness track? --------------------------------------
fprintf('\n===== 1. WHAT DOES SKEWNESS TRACK? =====\n');
PR = {'ur','Ursell'; 'hsh','Hs/h'; 'bic','bicoherence'; 'harm','harmonic excess'; 'h','depth'};
fprintf('  %-18s %10s %14s\n','predictor','pooled','per-record');
uR = unique(H.rec(isfinite(H.rec)));
for i = 1:size(PR,1)
    rp = corr(H.(PR{i,1})(g), H.skew(g), 'type','Spearman');
    rr = [];
    for u = uR'
        m = g & H.rec==u;
        if sum(m) < 100, continue; end
        rr(end+1) = corr(H.(PR{i,1})(m), H.skew(m), 'type','Spearman'); %#ok<SAGROW>
    end
    fprintf('  %-18s %+10.3f %+9.3f (%d/%d +)\n', PR{i,2}, rp, median(rr), sum(rr>0), numel(rr));
end

%% ---- 2 & 3. regime dependence, and whether it is just SNR --------------
fprintf('\n===== 2+3. DOES THE RELATION HOLD ACROSS REGIMES -- OR IS IT SNR? =====\n');
e = [0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
fprintf('  %-13s %8s %9s %9s %11s %11s\n','Hs/h','n','rho','med skew','slope','slope/med');
sl = nan(numel(e)-1,1); rh = sl; ms = sl;
for b = 1:numel(e)-1
    m = g & H.hsh>=e(b) & H.hsh<e(b+1);
    if sum(m) < 200, continue; end
    rh(b) = corr(H.ur(m), H.skew(m), 'type','Spearman');
    ms(b) = median(H.skew(m));
    % robust slope of skew on log10(Ursell): Theil-Sen would be ideal but is
    % O(n^2); a least-squares fit on ranks-free values is adequate here and the
    % point is only whether the slope MOVES.
    p = polyfit(log10(max(H.ur(m),eps)), H.skew(m), 1);
    sl(b) = p(1);
    fprintf('  %.2f - %.2f  %8d %+9.3f %9.3f %11.4f %11.3f\n', ...
        e(b), e(b+1), sum(m), rh(b), ms(b), sl(b), sl(b)/ms(b));
end
ok = isfinite(rh);
fprintf('\n  rho rises %.3f -> %.3f across the range (factor %.1f)\n', ...
    rh(find(ok,1)), rh(find(ok,1,'last')), rh(find(ok,1,'last'))/rh(find(ok,1)));
fprintf('  slope rises %.4f -> %.4f (factor %.1f)\n', ...
    sl(find(ok,1)), sl(find(ok,1,'last')), sl(find(ok,1,'last'))/sl(find(ok,1)));
fprintf('  slope NORMALISED by median skewness: %.3f -> %.3f (factor %.1f)\n', ...
    sl(find(ok,1))/ms(find(ok,1)), sl(find(ok,1,'last'))/ms(find(ok,1,'last')), ...
    (sl(find(ok,1,'last'))/ms(find(ok,1,'last')))/(sl(find(ok,1))/ms(find(ok,1))));
fprintf('  INTERPRETATION: if the normalised slope is roughly flat while rho\n');
fprintf('  climbs, the climb is signal-to-noise, not a change in the physics.\n');

%% ---- 4. does bicoherence add information beyond Ursell? ---------------
fprintf('\n===== 4. DOES PHASE COUPLING ADD INFORMATION BEYOND URSELL? =====\n');
rb  = corr(H.bic(g), H.skew(g), 'type','Spearman');
pbu = partialcorr(H.bic(g), H.skew(g), H.ur(g), 'type','Spearman');
pub = partialcorr(H.ur(g),  H.skew(g), H.bic(g), 'type','Spearman');
fprintf('  pooled:  rho(bic,skew) = %+.3f | partial(bic,skew|ur) = %+.3f | partial(ur,skew|bic) = %+.3f\n', ...
    rb, pbu, pub);

pr_rec = []; pu_rec = [];
for u = uR'
    m = g & H.rec==u;
    if sum(m) < 200, continue; end
    if std(H.bic(m))<eps || std(H.ur(m))<eps, continue; end
    pr_rec(end+1) = partialcorr(H.bic(m), H.skew(m), H.ur(m), 'type','Spearman'); %#ok<SAGROW>
    pu_rec(end+1) = partialcorr(H.ur(m),  H.skew(m), H.bic(m), 'type','Spearman'); %#ok<SAGROW>
end
fprintf('  per record: partial(bic,skew|ur) median %+.3f, positive in %d of %d\n', ...
    median(pr_rec), sum(pr_rec>0), numel(pr_rec));
fprintf('              partial(ur,skew|bic) median %+.3f, positive in %d of %d\n', ...
    median(pu_rec), sum(pu_rec>0), numel(pu_rec));

% and within Hs/h bands, so the partial is not carried by regime spread
fprintf('\n  partial(bic,skew|ur) WITHIN Hs/h bands:\n');
fprintf('  %-13s %8s %11s\n','Hs/h','n','partial');
for b = 1:numel(e)-1
    m = g & H.hsh>=e(b) & H.hsh<e(b+1);
    if sum(m) < 200, continue; end
    fprintf('  %.2f - %.2f  %8d %+11.3f\n', e(b), e(b+1), sum(m), ...
        partialcorr(H.bic(m), H.skew(m), H.ur(m), 'type','Spearman'));
end

fprintf('\n===== BOTTOM LINE =====\n');
fprintf('  A proxy built on a single nonlinearity parameter targets the right\n');
fprintf('  variable if Ursell wins test 1. Whether it can ever be COMPLETE is\n');
fprintf('  test 4: a surviving partial correlation means skewness depends on\n');
fprintf('  phase coupling independently of any amplitude/steepness parameter.\n');
fprintf('  Read test 3 before quoting test 2.\n\n');
