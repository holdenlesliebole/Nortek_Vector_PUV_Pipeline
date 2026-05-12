function L4ref = PUV_L4_reflection_free(PUV, L2, L4eta, L4bw, opts)
% PUV_L4_reflection_free  Sheremet incident/reflected IG split applied to
%                         the bound-stripped free residual.
%
%   L4ref = PUV_L4_reflection_free(PUV, L2, L4eta, L4bw)
%   L4ref = PUV_L4_reflection_free(PUV, L2, L4eta, L4bw, opts)
%
%   Same machinery as PUV_L4_reflection, but the elevation and shore-
%   normal velocity inputs are first cleaned of the Hasselmann second-
%   order bound-wave component using L4bw.eta_ig_bound and L4bw.u_ig_bound.
%   The intended interpretation of R2_IG returned by this routine is a
%   true shoreline reflection coefficient for free IG waves, no longer
%   contaminated by the bound-wave misallocation that drives the raw
%   Sheremet split toward R2_IG ~= 1 in the IG-saturated regime.
%
%   The L4bw inputs are themselves limited by the regime of validity of
%   the second-order Hasselmann theory (see project_boundwave_regime
%   memory). For segments with Hs/h > 0.10 the theory overpredicts and
%   the free residual eta_total - eta_bound can be negative-variance in
%   places — interpret outputs with the same Hs/h filter you apply to
%   L4.boundwave.bound_frac.
%
%   INPUTS
%     PUV   - L1 struct
%     L2    - L2 struct
%     L4eta - struct from PUV_L4_eta
%     L4bw  - struct from PUV_L4_boundwave with .eta_ig_bound and
%             .u_ig_bound populated
%     opts  - optional struct (bandIG, nanMaxFrac, rho, g) — same
%             defaults as PUV_L4_reflection
%
%   OUTPUT (struct L4ref) — same shape as PUV_L4_reflection.
%     Header field L4ref.input = 'free' to mark provenance.
% Author: Holden Leslie-Bole, 2026

if nargin < 5, opts = struct(); end

if ~isfield(opts, 'bandIG'),     opts.bandIG     = [0.004, 0.04]; end
opts = inheritFromL2(opts, L2, 'nanMaxFrac', 0.05);
opts = inheritFromL2(opts, L2, 'rho',        1025);
opts = inheritFromL2(opts, L2, 'g',          9.81);

fs     = L2.fs;
segLen = L2.params.segLen;
nSeg   = numel(L2.time);
doffp  = L2.doffp;

if isfield(L2, 'params') && isfield(L2.params, 'startOffset_samples')
    startOffset = L2.params.startOffset_samples;
else
    startOffset = 0;
end

freq = (0:segLen-1)' * fs / segLen;
freq(freq > fs/2) = freq(freq > fs/2) - fs;
freqAbs = abs(freq);
omegaAbs = 2 * pi * freqAbs;

fOneSided  = (0:segLen/2)' * fs / segLen;
igOneSided = (fOneSided >= opts.bandIG(1)) & (fOneSided <= opts.bandIG(2));
fIG        = fOneSided(igOneSided);
nfIG       = numel(fIG);

igMaskAll  = (freqAbs >= opts.bandIG(1)) & (freqAbs <= opts.bandIG(2));

L4ref.input       = 'free';
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
    warning('PUV_L4_reflection_free:noShorenormal', ...
        'L2.shorenormal is NaN for %s — returning empty L4ref.', PUV.label);
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

    % --- KEY DIFFERENCE: subtract the bound IG slice from BOTH inputs ---
    z_bound = L4bw.eta_ig_bound(:, i);
    u_bound = L4bw.u_ig_bound(:, i);
    if any(isnan(z_bound)) || any(isnan(u_bound))
        continue
    end
    Z = L4eta.eta_total(:, i) - z_bound;
    U_sn = U_sn - u_bound;
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

    SinFull  = 2 * abs(Zph).^2 / (fs * segLen);
    SoutFull = 2 * abs(Zrh).^2 / (fs * segLen);
    SinFull(1)            = SinFull(1) / 2;
    SoutFull(1)           = SoutFull(1) / 2;
    SinFull(segLen/2 + 1) = SinFull(segLen/2 + 1) / 2;
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

    cg = sqrt(opts.g * H);
    L4ref.cg_IG(i)     = cg;
    L4ref.Ef_IG_in(i)  = opts.rho * opts.g * cg * L4ref.var_IG_in(i);
    L4ref.Ef_IG_out(i) = opts.rho * opts.g * cg * L4ref.var_IG_out(i);
    L4ref.Ef_IG_net(i) = L4ref.Ef_IG_in(i) - L4ref.Ef_IG_out(i);
end
end


function opts = inheritFromL2(opts, L2, fld, defaultVal)
if isfield(opts, fld), return, end
if isfield(L2, 'params') && isfield(L2.params, fld)
    opts.(fld) = L2.params.(fld);
else
    opts.(fld) = defaultVal;
end
end
