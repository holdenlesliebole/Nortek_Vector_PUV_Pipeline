function L4ref = PUV_L4_reflection(PUV, L2, L4eta, opts)
% PUV_L4_reflection  Sheremet (2002) incident/reflected IG separation per segment.
%
%   PLANNED EXTENSION (queued 2026-05-14, see docs/todo.md):
%     Generalise this module to run the same Sheremet F-factor decomposition
%     on swell (0.04-0.12 Hz) and sea (0.12-0.25 Hz) bands, not just IG.
%     The decomposition formulae are band-agnostic — only the frequency
%     mask needs to change. Empirical motivation: at TBR23, raw R^2_IG is
%     ~1.0 (free-wave R^2 0.35-0.87), so IG reflection is non-trivial; we
%     need swell/sea numbers to know whether the unidirectional-flux
%     assumption holds at higher frequencies (likely violated more by
%     breaking + directional spread than by reflection).
%
%   L4ref = PUV_L4_reflection(PUV, L2, L4eta)
%   L4ref = PUV_L4_reflection(PUV, L2, L4eta, opts)
%
%   For each L2 segment, splits surface elevation into shoreward (Zp) and
%   seaward (Zr) components in the IG band using co-located shore-normal
%   velocity. Sheremet et al. (2002) local-velocity factor is
%
%       F(f) = w / (g*k) * cosh(k*H) / cosh(k*doffp)
%
%   with k from linear dispersion at depth H, w = 2*pi*f, doffp = sensor
%   height above bed (z = -H + doffp). The split is
%
%       Zp_h = 0.5 * Z_h + 0.5 * F * U_h     (shoreward)
%       Zr_h = 0.5 * Z_h - 0.5 * F * U_h     (seaward)
%
%   applied only inside the IG band; bins outside the band are zeroed in
%   both Zp_h and Zr_h before the inverse FFT.
%
%   Inputs come from PUV (L1) for raw velocity, L2 for shore-normal angle
%   and segment metadata, and L4eta for the broadband surface elevation
%   timeseries (already pressure-corrected via Kp). Re-using L4eta avoids
%   recomputing the dBar→m + Kp + IFFT chain.
%
%   INPUTS
%     PUV    - L1 struct with .BuoyCoord.U, .BuoyCoord.V, .doffp
%     L2     - L2 struct with .time, .depth, .segValid, .shorenormal,
%              .params.segLen, .fs, .doffp
%     L4eta  - struct from PUV_L4_eta with .eta_total, .segValid, etc.
%     opts   - optional struct
%              .bandIG      [fmin fmax] (default [0.004 0.04] Hz)
%              .nanMaxFrac  (default = L2.params.nanMaxFrac or 0.05)
%              .rho         (default = L2.params.rho or 1025)
%              .g           (default = L2.params.g   or 9.81)
%
%   OUTPUT (struct L4ref)
%     L4ref.time        - (nSeg x 1) datetime, copied from L2.time
%     L4ref.fs          - sampling frequency (Hz)
%     L4ref.segLen      - segment length (samples)
%     L4ref.depth       - (nSeg x 1) per-segment H
%     L4ref.segValid    - (nSeg x 1)
%     L4ref.shorenormal - scalar (deg)
%     L4ref.bandIG      - [fmin fmax] used
%     L4ref.eta_IG_in   - (segLen x nSeg) shoreward IG eta timeseries (m)
%     L4ref.eta_IG_out  - (segLen x nSeg) seaward IG eta timeseries (m)
%     L4ref.var_IG_in   - (nSeg x 1) variance of eta_IG_in (m^2)
%     L4ref.var_IG_out  - (nSeg x 1) variance of eta_IG_out (m^2)
%     L4ref.R2_IG       - (nSeg x 1) IG reflection coef = var_out / var_in
%     L4ref.fIG         - (nf_ig x 1) IG-band frequency grid (Hz)
%     L4ref.S_IG_in     - (nf_ig x nSeg) one-sided incident PSD (m^2/Hz)
%     L4ref.S_IG_out    - (nf_ig x nSeg) one-sided reflected PSD (m^2/Hz)
%     L4ref.R2_f        - (nf_ig x nSeg) freq-resolved R^2(f) = S_out/S_in
%     L4ref.cg_IG       - (nSeg x 1) shallow-water phase speed sqrt(g*H) (m/s)
%     L4ref.Ef_IG_in    - (nSeg x 1) shoreward IG energy flux rho*g*cg*var_in (W/m)
%     L4ref.Ef_IG_out   - (nSeg x 1) seaward IG energy flux  rho*g*cg*var_out (W/m)
%     L4ref.Ef_IG_net   - (nSeg x 1) Ef_IG_in - Ef_IG_out (W/m)
%
%   REQUIRES
%     get_wavenumber.m, apply_shorenormal_rotation.m on the path.
%
%   INTERPRETATION CAVEAT
%     Sheremet decomposition assumes FREE waves obeying linear dispersion
%     (u/eta = (g*k/w) * cosh(k*doffp)/cosh(k*H)). Bound IG waves are
%     anti-phase with eta and violate this relation, so a pure bound wave
%     is misallocated by the split — typically biased toward Zr because
%     eta_b < 0 while u_b > 0 makes |0.5*eta - 0.5*F*u| > |0.5*eta + 0.5*F*u|.
%     This means R²_IG approaches or exceeds 1 at depths where bound IG
%     dominates the IG variance (typical at 5-10 m on sandy coasts). To
%     recover a true shoreline reflection coefficient, first remove bound
%     waves (Herbers et al. 1994 / boundwave module) and apply Sheremet
%     to the free-IG residual.
%
%   REFERENCES
%     Sheremet, A. et al. (2002), J. Geophys. Res., 107(C8), 3095.
%     Herbers, T.H.C. & Guza, R.T. (1994), J. Geophys. Res., 99(C12).
% Author: Holden Leslie-Bole, 2026

if nargin < 4, opts = struct(); end

if ~isfield(opts, 'bandIG'),     opts.bandIG     = [0.004, 0.04]; end
opts = inheritFromL2(opts, L2, 'nanMaxFrac', 0.05);
opts = inheritFromL2(opts, L2, 'rho',        1025);
opts = inheritFromL2(opts, L2, 'g',          9.81);

fs     = L2.fs;
segLen = L2.params.segLen;
nSeg   = numel(L2.time);
doffp  = L2.doffp;

% Leading-sample offset applied by PUV_L2_spectral for UTC hour alignment.
% L4 must use the same offset so PUV.U/V(idx,:) lines up with L2.time(i).
if isfield(L2, 'params') && isfield(L2.params, 'startOffset_samples')
    startOffset = L2.params.startOffset_samples;
else
    startOffset = 0;
end

% Two-sided FFT frequency grid for length segLen
freq = (0:segLen-1)' * fs / segLen;
freq(freq > fs/2) = freq(freq > fs/2) - fs;
freqAbs = abs(freq);
omegaAbs = 2 * pi * freqAbs;

% Positive-frequency IG indices (one-sided) — for the saved spectra/R²(f)
fOneSided    = (0:segLen/2)' * fs / segLen;
igOneSided   = (fOneSided >= opts.bandIG(1)) & (fOneSided <= opts.bandIG(2));
fIG          = fOneSided(igOneSided);
nfIG         = numel(fIG);

% Two-sided IG mask for the FFT-domain split
igMaskAll    = (freqAbs >= opts.bandIG(1)) & (freqAbs <= opts.bandIG(2));

% Allocate
L4ref.time        = L2.time;
L4ref.fs          = fs;
L4ref.segLen      = segLen;
L4ref.depth       = L2.depth;
L4ref.segValid    = false(nSeg, 1);
if isfield(L2, 'segValid'), L4ref.segValid = L2.segValid; end
L4ref.shorenormal = L2.shorenormal;
L4ref.bandIG      = opts.bandIG;

L4ref.eta_IG_in   = NaN(segLen, nSeg);
L4ref.eta_IG_out  = NaN(segLen, nSeg);
L4ref.var_IG_in   = NaN(nSeg, 1);
L4ref.var_IG_out  = NaN(nSeg, 1);
L4ref.R2_IG       = NaN(nSeg, 1);
L4ref.fIG         = fIG;
L4ref.S_IG_in     = NaN(nfIG, nSeg);
L4ref.S_IG_out    = NaN(nfIG, nSeg);
L4ref.R2_f        = NaN(nfIG, nSeg);
L4ref.cg_IG       = NaN(nSeg, 1);
L4ref.Ef_IG_in    = NaN(nSeg, 1);
L4ref.Ef_IG_out   = NaN(nSeg, 1);
L4ref.Ef_IG_net   = NaN(nSeg, 1);

if isnan(L2.shorenormal)
    warning('PUV_L4_reflection:noShorenormal', ...
        'L2.shorenormal is NaN for %s — cannot rotate U/V to shore-normal frame. Returning empty L4ref.', ...
        PUV.label);
    return
end

for i = 1:nSeg
    if ~L4ref.segValid(i) || isnan(L2.depth(i))
        continue
    end

    idx = startOffset + ((i-1)*segLen + 1 : i*segLen);
    if idx(end) > numel(PUV.BuoyCoord.U)
        continue
    end

    uBuoy = PUV.BuoyCoord.U(idx);
    vBuoy = PUV.BuoyCoord.V(idx);
    nanFrac = sum(isnan(uBuoy) | isnan(vBuoy)) / segLen;
    if nanFrac > opts.nanMaxFrac
        continue
    end
    uBuoy = fillmissing(uBuoy, 'linear');
    vBuoy = fillmissing(vBuoy, 'linear');

    [U_sn, ~] = apply_shorenormal_rotation(uBuoy, vBuoy, L2.shorenormal);
    U_sn = detrend(U_sn);
    U_sn = U_sn - mean(U_sn);

    Z = L4eta.eta_total(:, i);
    if any(isnan(Z))
        continue
    end

    Zh = fft(Z);
    Uh = fft(U_sn);

    H = L2.depth(i);

    % Sheremet F factor on the two-sided FFT grid
    F = zeros(segLen, 1);
    nonDC = omegaAbs > 0;
    k = nan(segLen, 1);
    k(nonDC) = get_wavenumber(omegaAbs(nonDC), H);
    valid = nonDC & ~isnan(k) & k > 0;
    F(valid) = omegaAbs(valid) ./ (opts.g .* k(valid)) .* ...
               cosh(k(valid) .* H) ./ cosh(k(valid) .* doffp);

    % Sheremet split inside IG band; zero outside
    Zph = zeros(segLen, 1);
    Zrh = zeros(segLen, 1);
    Zph(igMaskAll) = 0.5 * Zh(igMaskAll) + 0.5 * F(igMaskAll) .* Uh(igMaskAll);
    Zrh(igMaskAll) = 0.5 * Zh(igMaskAll) - 0.5 * F(igMaskAll) .* Uh(igMaskAll);

    eta_in  = real(ifft(Zph));
    eta_out = real(ifft(Zrh));

    L4ref.eta_IG_in(:, i)  = eta_in;
    L4ref.eta_IG_out(:, i) = eta_out;
    L4ref.var_IG_in(i)     = var(eta_in);
    L4ref.var_IG_out(i)    = var(eta_out);
    if L4ref.var_IG_in(i) > 0
        L4ref.R2_IG(i) = L4ref.var_IG_out(i) / L4ref.var_IG_in(i);
    end

    % One-sided PSD on the IG band: 2 * |X|^2 / (fs * N) at non-Nyquist bins
    SinFull  = 2 * abs(Zph).^2 / (fs * segLen);
    SoutFull = 2 * abs(Zrh).^2 / (fs * segLen);
    SinFull(1)            = SinFull(1) / 2;             % DC
    SoutFull(1)           = SoutFull(1) / 2;
    SinFull(segLen/2 + 1) = SinFull(segLen/2 + 1) / 2;  % Nyquist
    SoutFull(segLen/2 + 1)= SoutFull(segLen/2 + 1) / 2;
    Sin_one  = SinFull(1:segLen/2 + 1);
    Sout_one = SoutFull(1:segLen/2 + 1);

    L4ref.S_IG_in(:, i)  = Sin_one(igOneSided);
    L4ref.S_IG_out(:, i) = Sout_one(igOneSided);
    sIn  = L4ref.S_IG_in(:, i);
    sOut = L4ref.S_IG_out(:, i);
    safe = sIn > 0;
    R2f  = NaN(nfIG, 1);
    R2f(safe) = sOut(safe) ./ sIn(safe);
    L4ref.R2_f(:, i) = R2f;

    % Shallow-water phase/group speed at depth H (cg ~ c = sqrt(g*H) in
    % the IG band where kH << 1; use this rather than per-bin cg to keep
    % the energy flux interpretation simple)
    cg = sqrt(opts.g * H);
    L4ref.cg_IG(i)     = cg;
    L4ref.Ef_IG_in(i)  = opts.rho * opts.g * cg * L4ref.var_IG_in(i);
    L4ref.Ef_IG_out(i) = opts.rho * opts.g * cg * L4ref.var_IG_out(i);
    L4ref.Ef_IG_net(i) = L4ref.Ef_IG_in(i) - L4ref.Ef_IG_out(i);
end
end


function opts = inheritFromL2(opts, L2, fld, defaultVal)
% Copy a parameter from L2.params if the caller didn't supply it.
if isfield(opts, fld), return, end
if isfield(L2, 'params') && isfield(L2.params, fld)
    opts.(fld) = L2.params.(fld);
else
    opts.(fld) = defaultVal;
end
end
