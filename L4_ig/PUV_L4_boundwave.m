function L4bw = PUV_L4_boundwave(L4eta, L2, PUV, opts)
% PUV_L4_boundwave  Bound / free IG separation via Hasselmann forcing kernel.
%
%   L4bw = PUV_L4_boundwave(L4eta, L2, PUV)
%   L4bw = PUV_L4_boundwave(L4eta, L2, PUV, opts)
%
%   PUV (L1) is required so the bound shore-normal velocity can be
%   compared against the measured shore-normal velocity for the per-
%   segment free residual u_ig_free = u_ig_total - u_ig_bound.
%
%   For each L2 segment, estimates the bound-IG component as the second-
%   order weakly nonlinear difference-frequency forcing of swell-band
%   pairs via the Hasselmann (1962) / Schaffer-Madsen (1995) interaction
%   kernel implemented in shared/boundwave_zig1D.m (1D collinear,
%   shoreward-traveling swell assumption). The free-IG component is the
%   residual:
%
%       eta_ig_free = eta_ig_total - eta_ig_bound
%
%   This lets PUV_L4_reflection (or a wrapper) be re-applied to the free
%   IG residual to recover a true shoreline reflection coefficient,
%   uncontaminated by the bound-wave misallocation that drives R^2_IG
%   toward 1 in the raw Sheremet decomposition.
%
%   INPUTS
%     L4eta - struct from PUV_L4_eta with .eta_total, .eta_ig, .time,
%             .fs, .segLen, .depth, .segValid, .bands
%     L2    - L2 struct (for shore-normal and params; not strictly
%             required for the 1D bound-wave estimator but kept for
%             metadata symmetry)
%     opts  - optional struct (passed through to boundwave_zig1D)
%             .bandSwell  default [0.04 0.25]
%             .bandIG     default [0.004 0.04]
%             .khmin      default 0.265
%             .khmax      default 10
%
%   OUTPUT (struct L4bw)
%     L4bw.time, fs, segLen, depth, segValid, bandIG, bandSwell
%     L4bw.eta_ig_bound       - (segLen x nSeg) bound IG eta timeseries (m)
%     L4bw.eta_ig_free        - (segLen x nSeg) free IG eta timeseries (m)
%     L4bw.u_ig_bound         - (segLen x nSeg) bound IG shore-normal velocity
%                               timeseries (m/s, positive onshore)
%     L4bw.u_ig_free          - (segLen x nSeg) free IG shore-normal velocity
%                               residual = u_ig_total - u_ig_bound (m/s)
%     L4bw.var_ig_total       - (nSeg x 1) variance of input eta_ig (m^2)
%     L4bw.var_ig_bound       - (nSeg x 1) variance of bound IG (m^2)
%     L4bw.var_ig_free        - (nSeg x 1) variance of free IG (m^2)
%     L4bw.var_u_ig_total     - (nSeg x 1) variance of bandpassed u_sn_ig (m^2/s^2)
%     L4bw.var_u_ig_bound     - (nSeg x 1) variance of bound u (m^2/s^2)
%     L4bw.var_u_ig_free      - (nSeg x 1) variance of free u residual (m^2/s^2)
%     L4bw.bound_frac_raw     - (nSeg x 1) var_bound / var_total, unclamped.
%                               Can exceed 1 when the second-order theory
%                               overpredicts (Hs/h > ~0.10 — see regime
%                               note below). Use this for diagnostics.
%     L4bw.bound_frac         - (nSeg x 1) bound_frac_raw clamped to [0,1].
%                               Use this for headline plots only after
%                               filtering on Hs/h.
%     L4bw.fIG                - (nfIG x 1) IG-band frequency grid (Hz)
%     L4bw.S_ig_total         - (nfIG x nSeg) one-sided PSD of total IG (m^2/Hz)
%     L4bw.S_ig_bound         - (nfIG x nSeg) one-sided PSD of bound IG (m^2/Hz)
%     L4bw.S_ig_free          - (nfIG x nSeg) one-sided PSD of free IG (m^2/Hz)
%     L4bw.bound_frac_f       - (nfIG x nSeg) S_bound / S_total per IG bin
%
%   REGIME OF VALIDITY
%     The Hasselmann (1962) / Schaffer-Madsen (1995) interaction kernel
%     is the second-order term in a perturbation expansion in wave
%     steepness ka and shallowness 1/kh. The bound-wave prediction is
%     unbounded — nothing in the second-order theory prevents
%     var(eta_bound) from exceeding var(eta_total). Catalog-wide check
%     across 42 PUV instruments (2026-05-12):
%       Hs/h > 0.15  -> raw bound/total ratio 1.9-2.5 (theory unphysical)
%       Hs/h ~ 0.10  -> raw ratio ~1.0 (theory borderline)
%       Hs/h < 0.07  -> raw ratio 0.05-0.25 (clean theory regime)
%     Correlation r(bound_frac_raw, Hs/h) = +0.93 across the catalog.
%     Treat bound_frac numbers at Hs/h > ~0.10 as a saturation flag
%     rather than a physical bound fraction.
%
%   REQUIRES
%     shared/boundwave_zig1D.m, shared/get_wavenumber.m on the path.
%
%   REFERENCES
%     Hasselmann, K. (1962), J. Fluid Mech. 12, 481-500.
%     Herbers, T.H.C., Elgar, S. & Guza, R.T. (1994), J. Geophys. Res.,
%       99(C5), 10075-10089.
%     Schaffer, H.A. & Madsen, P.A. (1995), Coastal Eng. 26, 1-14.
% Author: Holden Leslie-Bole, 2026

if nargin < 4, opts = struct(); end
if ~isfield(opts, 'bandSwell'),  opts.bandSwell  = [0.04 0.25];  end
if ~isfield(opts, 'bandIG'),     opts.bandIG     = [0.004 0.04]; end
if ~isfield(opts, 'khmin'),      opts.khmin      = 0.265;        end
if ~isfield(opts, 'khmax'),      opts.khmax      = 10;           end
if ~isfield(opts, 'nanMaxFrac'), opts.nanMaxFrac = 0.10;         end

fs     = L4eta.fs;
segLen = L4eta.segLen;
nSeg   = numel(L4eta.time);

% One-sided IG band frequency grid for spectra
fOne   = (0:segLen/2)' * fs / segLen;
igMask = fOne >= opts.bandIG(1) & fOne <= opts.bandIG(2);
fIG    = fOne(igMask);
nfIG   = numel(fIG);

L4bw.time         = L4eta.time;
L4bw.fs           = fs;
L4bw.segLen       = segLen;
L4bw.depth        = L4eta.depth;
L4bw.segValid     = L4eta.segValid;
L4bw.bandIG       = opts.bandIG;
L4bw.bandSwell    = opts.bandSwell;
L4bw.fIG          = fIG;

L4bw.eta_ig_bound = NaN(segLen, nSeg);
L4bw.eta_ig_free  = NaN(segLen, nSeg);
L4bw.u_ig_bound   = NaN(segLen, nSeg);
L4bw.u_ig_free    = NaN(segLen, nSeg);
L4bw.var_ig_total   = NaN(nSeg, 1);
L4bw.var_ig_bound   = NaN(nSeg, 1);
L4bw.var_ig_free    = NaN(nSeg, 1);
L4bw.var_u_ig_total = NaN(nSeg, 1);
L4bw.var_u_ig_bound = NaN(nSeg, 1);
L4bw.var_u_ig_free  = NaN(nSeg, 1);
L4bw.bound_frac     = NaN(nSeg, 1);
L4bw.bound_frac_raw = NaN(nSeg, 1);
L4bw.S_ig_total   = NaN(nfIG, nSeg);
L4bw.S_ig_bound   = NaN(nfIG, nSeg);
L4bw.S_ig_free    = NaN(nfIG, nSeg);
L4bw.bound_frac_f = NaN(nfIG, nSeg);

% Pre-rotate full L1 timeseries to shore-normal frame once
if isnan(L2.shorenormal)
    warning('PUV_L4_boundwave:noShorenormal', ...
        'L2.shorenormal is NaN for %s — u_ig fields will remain NaN.', PUV.label);
    haveSN = false;
else
    haveSN = true;
    [U_sn_full, ~] = apply_shorenormal_rotation(PUV.BuoyCoord.U, PUV.BuoyCoord.V, L2.shorenormal);
end
if isfield(L2, 'params') && isfield(L2.params, 'startOffset_samples')
    startOffset = L2.params.startOffset_samples;
else
    startOffset = 0;
end

for i = 1:nSeg
    if ~L4bw.segValid(i) || isnan(L4eta.depth(i))
        continue
    end
    eta_t = L4eta.eta_total(:, i);
    eta_i = L4eta.eta_ig(:, i);
    if any(isnan(eta_t)) || any(isnan(eta_i))
        continue
    end

    [z_bound, u_bound_pred] = boundwave_zig1D(eta_t, L4eta.depth(i), fs, opts);
    z_free  = eta_i - z_bound;

    L4bw.eta_ig_bound(:, i) = z_bound;
    L4bw.eta_ig_free(:, i)  = z_free;

    vT = var(eta_i);
    vB = var(z_bound);
    vF = var(z_free);
    L4bw.var_ig_total(i) = vT;
    L4bw.var_ig_bound(i) = vB;
    L4bw.var_ig_free(i)  = vF;

    % Velocity side: bandpass the L1 shore-normal velocity into IG, then
    % subtract the predicted bound velocity to get the free residual.
    if haveSN
        idx = startOffset + ((i-1)*segLen + 1 : i*segLen);
        if idx(end) <= numel(U_sn_full)
            uSeg = U_sn_full(idx);
            nanFrac = mean(isnan(uSeg));
            if nanFrac <= opts.nanMaxFrac
                uSeg = fillmissing(uSeg, 'linear');
                uSeg = detrend(uSeg);
                u_ig_total = bandpass_freq(uSeg, fs, opts.bandIG(1), opts.bandIG(2));
                u_free     = u_ig_total - u_bound_pred;

                L4bw.u_ig_bound(:, i) = u_bound_pred;
                L4bw.u_ig_free(:, i)  = u_free;
                L4bw.var_u_ig_total(i) = var(u_ig_total);
                L4bw.var_u_ig_bound(i) = var(u_bound_pred);
                L4bw.var_u_ig_free(i)  = var(u_free);
            end
        end
    end
    if vT > 0
        L4bw.bound_frac_raw(i) = vB / vT;
        L4bw.bound_frac(i)     = max(0, min(1, vB / vT));
    end

    % One-sided PSDs of each timeseries on the IG band grid
    L4bw.S_ig_total(:, i) = oneSidedPSD(eta_i,   fs, segLen, igMask);
    L4bw.S_ig_bound(:, i) = oneSidedPSD(z_bound, fs, segLen, igMask);
    L4bw.S_ig_free(:, i)  = oneSidedPSD(z_free,  fs, segLen, igMask);

    safe = L4bw.S_ig_total(:, i) > 0;
    bf   = NaN(nfIG, 1);
    bf(safe) = L4bw.S_ig_bound(safe, i) ./ L4bw.S_ig_total(safe, i);
    L4bw.bound_frac_f(:, i) = max(0, min(1, bf));
end

end


function S = oneSidedPSD(x, fs, N, mask)
% One-sided PSD on the FFT grid, returned for the bins flagged by mask.
X = fft(x, N);
Sfull = 2 * abs(X).^2 / (fs * N);
Sfull(1)         = Sfull(1) / 2;          % DC
Sfull(N/2 + 1)   = Sfull(N/2 + 1) / 2;    % Nyquist
S = Sfull(1:N/2 + 1);
S = S(mask);
end
