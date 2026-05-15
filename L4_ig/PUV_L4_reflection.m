function L4ref = PUV_L4_reflection(PUV, L2, L4eta, opts)
% PUV_L4_reflection  Per-band Sheremet (2002) incident/reflected decomposition.
%
%   L4ref = PUV_L4_reflection(PUV, L2, L4eta)
%   L4ref = PUV_L4_reflection(PUV, L2, L4eta, opts)
%
%   For each L2 segment, splits the surface elevation into shoreward (Zp)
%   and seaward (Zr) components inside each of three bands (IG, swell, sea)
%   using the co-located shore-normal velocity and the Sheremet (2002)
%   local-velocity F-factor
%
%       F(f) = w / (g*k) * cosh(k*H) / cosh(k*doffp)
%
%   The same Sheremet decomposition is applied band-by-band — only the
%   frequency mask changes. Per-band variance, energy flux, R^2, R^2(f),
%   and PSDs are written to L4ref.byBand.{IG,swell,sea}. The pre-existing
%   IG-only flat fields (eta_IG_in/out, R2_IG, R2_f, etc.) are kept for
%   backwards compatibility and are equivalent to L4ref.byBand.IG.
%
%   INTERPRETATION CAVEATS (added 2026-05-14)
%
%   The Sheremet split rests on three assumptions, all of which are
%   weaker in swell/sea than in IG:
%
%     1. Linear wave theory (eta/u_sn = F for a free wave). In swell/sea
%        at the inner-shelf 5-7 m PUVs during winter, Hs/h often exceeds
%        0.15-0.20 and finite-amplitude steepness biases the F-factor.
%
%     2. **Unidirectional propagation along the shore-normal.** IG is
%        predominantly shore-normal (sigma_theta ~ 5-15 deg). Swell has
%        sigma_theta ~ 10-20 deg, sea ~ 20-30 deg at Torrey Pines. An
%        oblique wave at angle theta to the shore-normal has u_sn =
%        u_wave * cos(theta), so the F-factor systematically under-
%        projects incoming swell — that geometric "loss" gets labeled
%        as outgoing. For a single arrival at angle theta the leakage
%        ratio is R^2 ≈ ((1 - cos theta)/(1 + cos theta))^2 ≈ theta^4/16
%        for small theta (radians). At swell sigma_theta = 15 deg this
%        is ≈ 0.001; at 25 deg ≈ 0.008; at 45 deg ≈ 0.03. So typical
%        per-band R^2 floor from spread alone is ~0.001-0.01 (NOT the
%        10-15% I previously claimed). Verified 2026-05-14 by both
%        analytical derivation and empirical agreement with R^2_swell
%        median ≈ 0.008 across 38 instruments.
%
%     3. Free waves only (no bound or strongly nonlinear components).
%        Bound waves are second-order difference-frequency products of
%        swell pairs and live in the IG band by construction — so the
%        bound-wave contamination addressed by PUV_L4_reflection_free is
%        an IG-specific concern. In swell/sea the analogous Stokes
%        second-harmonic at sum frequencies is much weaker and usually
%        falls outside the band edges, so the standard Sheremet split
%        (this routine) is the right tool for swell/sea — there is no
%        meaningful "free swell" or "free sea" variant.
%
%   What R^2_swell and R^2_sea actually measure
%
%   R^2_band = |Z_out|^2 / |Z_in|^2 is the locally observed outgoing-to-
%   incoming variance ratio AT THE PUV in the named band. It is NOT a
%   shoreline reflection coefficient for swell/sea because:
%     (a) directional-spread leakage adds a baseline ~0.001-0.01 even
%         with zero physical reflection (scales as ~sigma_theta^4/16);
%     (b) most swell breaks shoreward of the PUV, so the connection
%         between R^2_band at the PUV and shoreline reflection is
%         indirect;
%     (c) breaking-zone backwash and refraction near shore add seaward
%         variance that is not "reflected" in the linear-wave sense.
%
%   Use R^2_IG as the meaningful reflection metric. Use R^2_swell and
%   R^2_sea as energy-budget bookkeeping bounds, and report band-mean
%   directional spread (L4ref.byBand.<band>.sigma_theta) alongside them
%   so a reader can judge how much of the outgoing-bin variance is
%   geometric leakage. The saturation_flag (Hs/h > satThresh) flags
%   segments where depth-limited breaking probably has reached the PUV;
%   filter those out for any quantitative claim about the linear regime.
%
%   INPUTS
%     PUV    - L1 struct with .BuoyCoord.U, .BuoyCoord.V, .doffp
%     L2     - L2 struct (.time, .depth, .segValid, .shorenormal, .Hs,
%                         .a1, .b1, .S_eta, .f, .params.segLen, .fs,
%                         .doffp, .params.startOffset_samples)
%     L4eta  - struct from PUV_L4_eta with .eta_total, .segValid, etc.
%     opts   - optional struct
%              .bandIG      [fmin fmax] (default [0.004 0.04] Hz)
%              .bandSwell   [fmin fmax] (default [0.04 0.12] Hz)
%              .bandSea     [fmin fmax] (default [0.12 0.25] Hz)
%              .nanMaxFrac  default = L2.params.nanMaxFrac or 0.05
%              .rho         default = L2.params.rho or 1025
%              .g           default = L2.params.g   or 9.81
%              .satThresh   Hs/h threshold for saturation flag
%                           (default 0.10 — second-order Sheremet
%                           assumptions degrade above this; see
%                           project_boundwave_regime memory)
%              .keepEtaTS   if true, save eta_in/eta_out segLen x nSeg
%                           timeseries for ALL bands (default false —
%                           IG only, for backwards compat / xspec
%                           consumption).
%
%   OUTPUT (struct L4ref)
%     L4ref.input          = 'total' (provenance marker; reflection_free
%                            sets this to 'free')
%     L4ref.time, fs, segLen, depth, segValid, shorenormal
%     L4ref.bandIG         [fmin fmax]   (kept for back-compat)
%     L4ref.bandSwell      [fmin fmax]
%     L4ref.bandSea        [fmin fmax]
%     L4ref.Hs_over_h      (nSeg x 1)  diagnostic saturation proxy
%     L4ref.saturation_flag (nSeg x 1) Hs/h > satThresh per segment
%
%     IG-only flat fields (back-compat, equivalent to .byBand.IG.*):
%       L4ref.eta_IG_in/out, var_IG_in/out, R2_IG, fIG, S_IG_in/out,
%       R2_f, cg_IG, Ef_IG_in/out/net
%
%     L4ref.byBand.IG, .swell, .sea — each a struct with:
%       .band               [fmin fmax]
%       .f                  (nfBand x 1) one-sided frequency grid
%       .var_in/out         (nSeg x 1) elevation variance (m^2)
%       .R2                 (nSeg x 1) var_out / var_in
%       .S_in/out           (nfBand x nSeg) one-sided PSD (m^2/Hz)
%       .R2_f               (nfBand x nSeg) S_out/S_in per bin
%       .cg                 (nSeg x 1) sqrt(g*H) (shallow approx)
%       .Ef_in/out/net      (nSeg x 1) rho*g*cg*var (W/m)
%       .sigma_theta        (nSeg x 1) energy-weighted directional
%                           spread within the band (rad, Kuik 1988)
%       .eta_in/out         (segLen x nSeg) timeseries — only saved for
%                           IG by default (see opts.keepEtaTS)
%
%   REQUIRES
%     get_wavenumber.m, apply_shorenormal_rotation.m on the path.
% Author: Holden Leslie-Bole, 2026

if nargin < 4, opts = struct(); end

if ~isfield(opts, 'bandIG'),     opts.bandIG     = [0.004, 0.04]; end
if ~isfield(opts, 'bandSwell'),  opts.bandSwell  = [0.04,  0.12]; end
if ~isfield(opts, 'bandSea'),    opts.bandSea    = [0.12,  0.25]; end
if ~isfield(opts, 'satThresh'),  opts.satThresh  = 0.10;          end
if ~isfield(opts, 'keepEtaTS'),  opts.keepEtaTS  = false;         end
opts = inheritFromL2(opts, L2, 'nanMaxFrac', 0.05);
opts = inheritFromL2(opts, L2, 'rho',        1025);
opts = inheritFromL2(opts, L2, 'g',          9.81);

fs     = L2.fs;
segLen = L2.params.segLen;
nSeg   = numel(L2.time);
doffp  = L2.doffp;

% Leading-sample offset applied by PUV_L2_spectral for UTC hour alignment.
if isfield(L2, 'params') && isfield(L2.params, 'startOffset_samples')
    startOffset = L2.params.startOffset_samples;
else
    startOffset = 0;
end

% Two-sided FFT frequency grid
freq = (0:segLen-1)' * fs / segLen;
freq(freq > fs/2) = freq(freq > fs/2) - fs;
freqAbs  = abs(freq);
omegaAbs = 2 * pi * freqAbs;

% One-sided frequency grid for spectra
fOne = (0:segLen/2)' * fs / segLen;

% Per-band frequency masks (one-sided and two-sided)
bands = {'IG', 'swell', 'sea'};
bandEdges = struct('IG', opts.bandIG, 'swell', opts.bandSwell, 'sea', opts.bandSea);
for b = 1:numel(bands)
    name = bands{b};
    edges = bandEdges.(name);
    maskOne  = (fOne    >= edges(1)) & (fOne    <= edges(2));
    maskFull = (freqAbs >= edges(1)) & (freqAbs <= edges(2));
    bandInfo.(name).edges    = edges;
    bandInfo.(name).maskOne  = maskOne;
    bandInfo.(name).maskFull = maskFull;
    bandInfo.(name).f        = fOne(maskOne);
    bandInfo.(name).nf       = numel(bandInfo.(name).f);
end

% --- Header fields ---
L4ref.input         = 'total';
L4ref.time          = L2.time;
L4ref.fs            = fs;
L4ref.segLen        = segLen;
L4ref.depth         = L2.depth;
L4ref.segValid      = false(nSeg, 1);
if isfield(L2, 'segValid'), L4ref.segValid = L2.segValid; end
L4ref.shorenormal   = L2.shorenormal;
L4ref.bandIG        = opts.bandIG;
L4ref.bandSwell     = opts.bandSwell;
L4ref.bandSea       = opts.bandSea;

% Saturation proxy and flag (segments where depth-limited breaking may have
% reached the PUV — the linear-Sheremet assumptions degrade above this).
if isfield(L2, 'Hs') && isfield(L2, 'depth')
    L4ref.Hs_over_h = L2.Hs(:) ./ L2.depth(:);
else
    L4ref.Hs_over_h = NaN(nSeg, 1);
end
L4ref.saturation_flag = L4ref.Hs_over_h > opts.satThresh;

% --- Allocate per-band outputs ---
for b = 1:numel(bands)
    name = bands{b};
    nf   = bandInfo.(name).nf;
    L4ref.byBand.(name).band        = bandInfo.(name).edges;
    L4ref.byBand.(name).f           = bandInfo.(name).f;
    L4ref.byBand.(name).var_in      = NaN(nSeg, 1);
    L4ref.byBand.(name).var_out     = NaN(nSeg, 1);
    L4ref.byBand.(name).R2          = NaN(nSeg, 1);
    L4ref.byBand.(name).S_in        = NaN(nf, nSeg);
    L4ref.byBand.(name).S_out       = NaN(nf, nSeg);
    L4ref.byBand.(name).R2_f        = NaN(nf, nSeg);
    L4ref.byBand.(name).cg          = NaN(nSeg, 1);
    L4ref.byBand.(name).Ef_in       = NaN(nSeg, 1);
    L4ref.byBand.(name).Ef_out      = NaN(nSeg, 1);
    L4ref.byBand.(name).Ef_net      = NaN(nSeg, 1);
    L4ref.byBand.(name).sigma_theta = NaN(nSeg, 1);
    if strcmp(name, 'IG') || opts.keepEtaTS
        L4ref.byBand.(name).eta_in  = NaN(segLen, nSeg);
        L4ref.byBand.(name).eta_out = NaN(segLen, nSeg);
    end
end

% --- Flat IG-only fields for backwards compatibility (populated from byBand.IG) ---
L4ref.fIG          = bandInfo.IG.f;
L4ref.eta_IG_in    = NaN(segLen, nSeg);
L4ref.eta_IG_out   = NaN(segLen, nSeg);
L4ref.var_IG_in    = NaN(nSeg, 1);
L4ref.var_IG_out   = NaN(nSeg, 1);
L4ref.R2_IG        = NaN(nSeg, 1);
L4ref.S_IG_in      = NaN(bandInfo.IG.nf, nSeg);
L4ref.S_IG_out     = NaN(bandInfo.IG.nf, nSeg);
L4ref.R2_f         = NaN(bandInfo.IG.nf, nSeg);
L4ref.cg_IG        = NaN(nSeg, 1);
L4ref.Ef_IG_in     = NaN(nSeg, 1);
L4ref.Ef_IG_out    = NaN(nSeg, 1);
L4ref.Ef_IG_net    = NaN(nSeg, 1);

if isnan(L2.shorenormal)
    warning('PUV_L4_reflection:noShorenormal', ...
        'L2.shorenormal is NaN for %s — returning empty L4ref.', PUV.label);
    return
end

haveDir = isfield(L2, 'a1') && isfield(L2, 'b1') && isfield(L2, 'S_eta') && isfield(L2, 'f');

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

    F = zeros(segLen, 1);
    nonDC = omegaAbs > 0;
    k = nan(segLen, 1);
    k(nonDC) = get_wavenumber(omegaAbs(nonDC), H);
    valid = nonDC & ~isnan(k) & k > 0;
    F(valid) = omegaAbs(valid) ./ (opts.g .* k(valid)) .* ...
               cosh(k(valid) .* H) ./ cosh(k(valid) .* doffp);

    % --- Loop over bands ---
    for b = 1:numel(bands)
        name     = bands{b};
        maskFull = bandInfo.(name).maskFull;
        maskOne  = bandInfo.(name).maskOne;

        Zph = zeros(segLen, 1);
        Zrh = zeros(segLen, 1);
        Zph(maskFull) = 0.5 * Zh(maskFull) + 0.5 * F(maskFull) .* Uh(maskFull);
        Zrh(maskFull) = 0.5 * Zh(maskFull) - 0.5 * F(maskFull) .* Uh(maskFull);

        eta_in  = real(ifft(Zph));
        eta_out = real(ifft(Zrh));
        vIn     = var(eta_in);
        vOut    = var(eta_out);

        L4ref.byBand.(name).var_in(i)  = vIn;
        L4ref.byBand.(name).var_out(i) = vOut;
        if vIn > 0
            L4ref.byBand.(name).R2(i) = vOut / vIn;
        end

        % One-sided PSD
        SinFull  = 2 * abs(Zph).^2 / (fs * segLen);
        SoutFull = 2 * abs(Zrh).^2 / (fs * segLen);
        SinFull(1)             = SinFull(1)  / 2;
        SoutFull(1)            = SoutFull(1) / 2;
        SinFull(segLen/2 + 1)  = SinFull(segLen/2 + 1)  / 2;
        SoutFull(segLen/2 + 1) = SoutFull(segLen/2 + 1) / 2;
        Sin_one  = SinFull(1:segLen/2 + 1);
        Sout_one = SoutFull(1:segLen/2 + 1);

        L4ref.byBand.(name).S_in(:, i)  = Sin_one(maskOne);
        L4ref.byBand.(name).S_out(:, i) = Sout_one(maskOne);
        sIn  = L4ref.byBand.(name).S_in(:, i);
        sOut = L4ref.byBand.(name).S_out(:, i);
        safe = sIn > 0;
        R2f  = NaN(bandInfo.(name).nf, 1);
        R2f(safe) = sOut(safe) ./ sIn(safe);
        L4ref.byBand.(name).R2_f(:, i) = R2f;

        % Shallow-water cg + energy flux. cg = sqrt(g*H) is accurate for
        % IG and reasonable for swell at PUV depths; for sea it under-
        % estimates by ~10-30% at typical inner-shelf depths. Treated as
        % a single band-mean approximation here for energy-budget
        % bookkeeping. Use the per-bin R2_f for frequency-resolved work.
        cg = sqrt(opts.g * H);
        L4ref.byBand.(name).cg(i)     = cg;
        L4ref.byBand.(name).Ef_in(i)  = opts.rho * opts.g * cg * vIn;
        L4ref.byBand.(name).Ef_out(i) = opts.rho * opts.g * cg * vOut;
        L4ref.byBand.(name).Ef_net(i) = L4ref.byBand.(name).Ef_in(i) - L4ref.byBand.(name).Ef_out(i);

        % Optional eta timeseries
        if strcmp(name, 'IG') || opts.keepEtaTS
            L4ref.byBand.(name).eta_in(:, i)  = eta_in;
            L4ref.byBand.(name).eta_out(:, i) = eta_out;
        end

        % Energy-weighted directional spread within band (Kuik et al. 1988)
        if haveDir
            fL2 = L2.f(:);
            inBand = fL2 >= bandInfo.(name).edges(1) & fL2 <= bandInfo.(name).edges(2);
            if any(inBand)
                m1f = sqrt(L2.a1(inBand, i).^2 + L2.b1(inBand, i).^2);
                Sf  = L2.S_eta(inBand, i);
                wOk = isfinite(m1f) & isfinite(Sf) & Sf > 0;
                if any(wOk)
                    m1_band = sum(Sf(wOk) .* m1f(wOk)) / sum(Sf(wOk));
                    m1_band = max(0, min(1, m1_band));
                    L4ref.byBand.(name).sigma_theta(i) = sqrt(2 * (1 - m1_band));
                end
            end
        end
    end
end

% --- Populate backwards-compatible flat fields from byBand.IG ---
L4ref.eta_IG_in    = L4ref.byBand.IG.eta_in;
L4ref.eta_IG_out   = L4ref.byBand.IG.eta_out;
L4ref.var_IG_in    = L4ref.byBand.IG.var_in;
L4ref.var_IG_out   = L4ref.byBand.IG.var_out;
L4ref.R2_IG        = L4ref.byBand.IG.R2;
L4ref.S_IG_in      = L4ref.byBand.IG.S_in;
L4ref.S_IG_out     = L4ref.byBand.IG.S_out;
L4ref.R2_f         = L4ref.byBand.IG.R2_f;
L4ref.cg_IG        = L4ref.byBand.IG.cg;
L4ref.Ef_IG_in     = L4ref.byBand.IG.Ef_in;
L4ref.Ef_IG_out    = L4ref.byBand.IG.Ef_out;
L4ref.Ef_IG_net    = L4ref.byBand.IG.Ef_net;
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
