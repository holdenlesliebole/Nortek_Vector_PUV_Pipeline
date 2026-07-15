function L4mom = PUV_L4_moments(L2, opts)
% PUV_L4_moments  Frequency-resolved skewness/asymmetry predictors.
%
%   L4mom = PUV_L4_moments(L2)
%   L4mom = PUV_L4_moments(L2, opts)
%
%   Reverse-engineered after Bill O'Reilly's MOP511 6m PUV analysis
%   (Apr 2026 PDF). For each hourly segment, the velocity third moment
%   <u^3>/std(u)^3 correlates strongly with sqrt(Spp(f)) at the swell
%   band (~0.08 Hz at 6m). This module computes the frequency-resolved
%   correlation r(f) and a linear predictor coefficient at the
%   peak-correlation frequency. Same exercise for asymmetry. The slope
%   of the fit is expected to scale with the Stokes second-order
%   coupling function F(kh), so cross-deployment comparison at the same
%   peak frequency provides an empirical test of the kh-dependence.
%
%   INPUTS
%     L2    - L2 struct with .time, .f, .Spp, .Suu, .vmom, .segValid,
%             .params.segLen, .fs, .depth (or .h)
%     opts  - optional struct
%             .smoothHours   smoothing window for Fig 7/9 (default 120)
%             .freqMergeHz   freq-domain moving mean half-width (default 0.012)
%             .bandSwell     [fLow fHigh] (default [0.04 0.18])
%             .bandSea       [fLow fHigh] (default [0.18 0.30])
%             .bandIG        [fLow fHigh] (default [0.004 0.04])
%
%   OUTPUT (struct L4mom)
%     .time, .f, .segValid                 - copied from L2
%     .varP_over_varU                      - (nSeg x 1) Fig 2 QC diagnostic
%     .skewness_u, .asymmetry_u            - copied from L2.vmom
%     .r_skew_Spp,  .r_asym_Spp            - (nf x 1) r(f) curves, raw
%     .r_skew_Spp_s, .r_asym_Spp_s         - smoothed (Fig 7 style)
%     .r_skew_Suu,  .r_asym_Suu            - velocity-spectrum versions
%     .peak.skew_fHz, .peak.skew_r         - max-correlation freq + r
%     .peak.asym_fHz, .peak.asym_r
%     .fit_hourly                          - struct from fitlm at peak f
%        .slope, .intercept, .r2, .fHz
%     .fit_smoothed                        - same on 120-hr smoothed series
%     .opts                                - resolved options for provenance
%
%   Author: Holden Leslie-Bole, 2026

if nargin < 2, opts = struct(); end
if ~isfield(opts, 'smoothHours'),  opts.smoothHours  = 120;            end
if ~isfield(opts, 'freqMergeHz'),  opts.freqMergeHz  = 0.012;          end
if ~isfield(opts, 'bandSwell'),    opts.bandSwell    = [0.04 0.18];    end
if ~isfield(opts, 'bandSea'),      opts.bandSea      = [0.18 0.30];    end
if ~isfield(opts, 'bandIG'),       opts.bandIG       = [0.004 0.04];   end

f      = L2.f(:);
df     = mean(diff(f));
mergeN = max(1, round(opts.freqMergeHz / df));

Spp = L2.Spp;
Suu = L2.Suu;

% --- valid segments (QC + non-NaN moments) ---
valid = L2.segValid(:) & ~isnan(L2.vmom.skewness(:)) & ~isnan(L2.vmom.asymmetry(:));
skewU = L2.vmom.skewness(:);
asymU = L2.vmom.asymmetry(:);

% --- Fig 2 var(P)/var(U) diagnostic (band-integrated; alt: use raw timeseries) ---
varP = sum(Spp, 1, 'omitnan') * df;
varU = sum(Suu, 1, 'omitnan') * df;
varRatio = varP(:) ./ varU(:);

% --- Bill uses raw P spectrum (no Kp correction). Skewness is dimensionless,
%     so any frequency-uniform scaling cancels; the slope is what carries
%     the F(kh) signature for cross-depth comparison.
SppFit = Spp;

% --- Frequency-resolved correlations (raw, hourly) ---
r_skew_Spp = freq_resolved_corr(skewU, SppFit, valid);
r_asym_Spp = freq_resolved_corr(asymU, SppFit, valid);
r_skew_Suu = freq_resolved_corr(skewU, Suu,    valid);
r_asym_Suu = freq_resolved_corr(asymU, Suu,    valid);

% --- Smoothed versions (Fig 7/9 style) ---
W = opts.smoothHours;
skewS  = movmedian_valid(skewU, W, valid);
asymS  = movmedian_valid(asymU, W, valid);
SppS   = movmean_valid(SppFit, W, valid);
SppS_f = freq_smooth(SppS, mergeN);

r_skew_Spp_s = freq_resolved_corr(skewS, SppS_f, valid);
r_asym_Spp_s = freq_resolved_corr(asymS, SppS_f, valid);

% --- Peak correlation frequencies (restrict to swell band) ---
inSwell = f >= opts.bandSwell(1) & f <= opts.bandSwell(2);
[peakSkewR, iS] = max_in_band(r_skew_Spp_s, inSwell);
[peakAsymR, iA] = max_in_band(r_asym_Spp_s, inSwell);
fSkew = f(iS);
fAsym = f(iA);

% --- Linear fits at peak skewness frequency ---
xH  = sqrt(SppFit(iS, :)).';   xH = xH(:);
yH  = skewU;
xS  = sqrt(SppS_f(iS, :)).';   xS = xS(:);
yS  = skewS;

fit_hourly   = fit_linear(xH, yH, valid, fSkew);
fit_smoothed = fit_linear(xS, yS, valid, fSkew);

% --- pack ---
L4mom = struct();
L4mom.time           = L2.time;
L4mom.f              = f;
L4mom.segValid       = L2.segValid;
L4mom.varP_over_varU = varRatio;
L4mom.skewness_u     = skewU;
L4mom.asymmetry_u    = asymU;
L4mom.r_skew_Spp     = r_skew_Spp;
L4mom.r_asym_Spp     = r_asym_Spp;
L4mom.r_skew_Suu     = r_skew_Suu;
L4mom.r_asym_Suu     = r_asym_Suu;
L4mom.r_skew_Spp_s   = r_skew_Spp_s;
L4mom.r_asym_Spp_s   = r_asym_Spp_s;
L4mom.peak.skew_fHz  = fSkew;
L4mom.peak.skew_r    = peakSkewR;
L4mom.peak.asym_fHz  = fAsym;
L4mom.peak.asym_r    = peakAsymR;
L4mom.fit_hourly     = fit_hourly;
L4mom.fit_smoothed   = fit_smoothed;
L4mom.opts           = opts;
end

% ============================================================
function r = freq_resolved_corr(y, S, valid)
% Pearson correlation between scalar timeseries y(nSeg) and sqrt(S(f, nSeg))
% across valid segments. Returns r(f) of length nf.
nf = size(S, 1);
r  = NaN(nf, 1);
yv = y(valid);
if std(yv, 'omitnan') == 0, return; end
Sv = sqrt(max(S(:, valid), 0));
for fi = 1:nf
    xv = Sv(fi, :).';
    ok = ~isnan(xv) & ~isnan(yv);
    if nnz(ok) < 30, continue; end
    c = corrcoef(xv(ok), yv(ok));   % base MATLAB; = corr() for two vectors
    r(fi) = c(1, 2);
end
end

% ------------------------------------------------------------
function y = movmedian_valid(x, W, valid)
y = x;
y(~valid) = NaN;
y = movmedian(y, W, 'omitnan');
end

function Y = movmean_valid(X, W, valid)
Y = X;
Y(:, ~valid) = NaN;
Y = movmean(Y, W, 2, 'omitnan');
end

function Y = freq_smooth(X, mergeN)
if mergeN <= 1, Y = X; return; end
Y = movmean(X, mergeN, 1, 'omitnan');
end

% ------------------------------------------------------------
function [rmax, idx] = max_in_band(r, mask)
rmask = r;
rmask(~mask) = -Inf;
[rmax, idx] = max(rmask);
end

% ------------------------------------------------------------
function fit = fit_linear(x, y, valid, fHz)
ok = valid & ~isnan(x) & ~isnan(y);
fit = struct('slope', NaN, 'intercept', NaN, 'r2', NaN, ...
             'fHz', fHz, 'n', nnz(ok));
if nnz(ok) < 30, return; end
p = polyfit(x(ok), y(ok), 1);
yhat = polyval(p, x(ok));
ss_res = sum((y(ok) - yhat).^2);
ss_tot = sum((y(ok) - mean(y(ok))).^2);
fit.slope     = p(1);
fit.intercept = p(2);
fit.r2        = 1 - ss_res / ss_tot;
end

