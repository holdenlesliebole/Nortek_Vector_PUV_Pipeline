% SHOAL_MOP_TO_SITE  Transform a CDIP MOP (or buoy) 1D spectrum from the model
% point depth to an instrument site depth by linear-theory energy-flux
% conservation.
%
% function out = shoal_mop_to_site(MOP, h_site, opts)
%
% Hoists the shoaling block that was previously inlined and duplicated across
% seven files (compare_PUV_MOP, compare_PUV_MOP_spectra, analyze_spectral_shape,
% analyze_bound_waves, compare_directional_spread, analyze_depth_dependence,
% scripts/fig_bulk_Hs_all_deployments). Default behaviour reproduces those
% copies exactly; the two additions below are opt-in.
%
%   S(f, h_site) = S(f, h_mop) * Cg(f, h_mop) / Cg(f, h_site) * Kr(f)^2
%
% ADDITIONS OVER THE INLINED VERSION
%   1. Per-segment depth. Every inlined copy used a single scalar
%      median(L2.depth) for an entire record. On an 8 m site a +/- 1 m tidal
%      swing is a non-trivial Cg error, and it is correlated with the tide
%      rather than random, so it does not average out of a bias estimate.
%      Pass a vector h_site to shoal each hour at its own depth.
%   2. Refraction. Energy-flux shoaling alone assumes shore-parallel contours
%      and normal incidence (Kr == 1). Supply opts.Kr or opts.theta_mop_deg to
%      include it, or leave it off and treat its omission as a bounded error
%      term. See the REFRACTION note below before enabling.
%
% INPUTS
%   MOP    - struct from read_MOPline2 / cdip_station_reference. Uses fields
%            .spec1D [nTimes x nFreq], .frequency, .fbw, .depth, .time, and
%            (optionally) .fbounds.
%   h_site - site depth (m). Either a scalar (applied to every hour) or a
%            vector of length nTimes giving the depth at each MOP time.
%   opts   - (optional) struct:
%              .Kr            refraction coefficient, scalar or [nFreq x 1].
%                             Default 1 (no refraction).
%              .theta_mop_deg incidence angle at the MOP point relative to
%                             shore normal (deg), scalar or [nFreq x 1]. If
%                             given and .Kr is not, Kr is derived by Snell's
%                             law (see REFRACTION). Default [] (unused).
%              .band          [fLo fHi] Hz for the bulk integrals.
%                             Default [0.04 0.25] (the pipeline sea-swell band).
%              .verbose       print the depth transform. Default false.
%
% OUTPUT
%   out - struct with fields:
%     .spec          shoaled spectral density at the site, [nTimes x nFreq],
%                    same orientation as MOP.spec1D
%     .frequency     [nFreq x 1] MOP band centres (Hz)
%     .fbw           [nFreq x 1] MOP band widths (Hz) -- NOT constant
%     .fbounds       MOP band edges if present in MOP, else []
%     .time          MOP.time, carried through unchanged
%     .h_mop         model point depth (m)
%     .h_site        site depth actually used (scalar or [nTimes x 1])
%     .cg_site       group velocity at the site, [nFreq x 1] or [nFreq x nTimes]
%     .cg_mop        group velocity at the model point, [nFreq x 1]
%     .shoalFactor   applied factor incl. Kr^2, [nFreq x 1] or [nFreq x nTimes]
%     .Kr            refraction coefficient actually applied
%     .Hs            Hs from the shoaled spectrum over .band, [nTimes x 1]
%     .Ef            energy flux at the site over .band (W/m), [nTimes x 1]
%     .band          the integration band used
%
% REFRACTION
%   Snell's law over straight parallel contours gives
%       sin(theta_site) = sin(theta_mop) * c_site / c_mop
%       Kr = sqrt( cos(theta_mop) / cos(theta_site) )
%   with c = omega/k the phase speed. Kr < 1 for obliquely incident waves, so
%   omitting it makes the shoaled model spectrum too energetic -- i.e. it biases
%   in the same direction as a claimed model over-prediction. Quantify it before
%   attributing bias to a model.
%
%   theta_mop_deg is measured relative to shore normal. Note that the frame of
%   MOP's own a1/b1 (geographic vs shore-relative) is NOT verified here; the
%   pipeline's PUV a1/b1 are shore-relative, so atan2d(b1,a1) is directly an
%   incidence angle for PUV but this has not been confirmed for MOP. Verify the
%   MOP direction convention before deriving theta from MOP.a1/MOP.b1.
%
% REQUIRES
%   get_wavenumber.m, get_cg.m (shared/)
%
% Author: Holden Leslie-Bole, 2026

function out = shoal_mop_to_site(MOP, h_site, opts)

if nargin < 3 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'Kr'),            opts.Kr            = [];          end
if ~isfield(opts, 'theta_mop_deg'), opts.theta_mop_deg = [];          end
if ~isfield(opts, 'band'),          opts.band          = [0.04 0.25]; end
if ~isfield(opts, 'verbose'),       opts.verbose       = false;       end

rho = 1025;   % kg/m^3
g   = 9.81;   % m/s^2

%% ---- Unpack and validate ---------------------------------------------
if ~isfield(MOP, 'spec1D') || isempty(MOP.spec1D)
    error('shoal_mop_to_site:noSpectra', ...
        'MOP struct carries no spec1D. Bulk-only references (e.g. L3.mop) cannot be shoaled.');
end

freq   = double(MOP.frequency(:));      % [nFreq x 1]
fbw    = double(MOP.fbw(:));            % non-uniform -- never assume constant df
nFreq  = numel(freq);
spec   = double(MOP.spec1D);            % [nTimes x nFreq]

if size(spec, 2) ~= nFreq
    error('shoal_mop_to_site:sizeMismatch', ...
        'MOP.spec1D is [%d x %d] but MOP.frequency has %d entries.', ...
        size(spec, 1), size(spec, 2), nFreq);
end
nTimes = size(spec, 1);

h_mop = double(MOP.depth);
if ~isscalar(h_mop)
    error('shoal_mop_to_site:badMopDepth', 'MOP.depth must be scalar.');
end

h_site = double(h_site(:));
perSegment = ~isscalar(h_site);
if perSegment && numel(h_site) ~= nTimes
    error('shoal_mop_to_site:badSiteDepth', ...
        ['h_site must be scalar or have one entry per MOP time ' ...
         '(got %d, expected %d).'], numel(h_site), nTimes);
end
if any(h_site <= 0) || any(isnan(h_site))
    error('shoal_mop_to_site:badSiteDepth', 'h_site must be positive and finite.');
end

%% ---- Group velocities ------------------------------------------------
omega  = 2 * pi * freq;                 % [nFreq x 1]
k_mop  = get_wavenumber(omega, h_mop);
cg_mop = get_cg(k_mop, h_mop);
cg_mop = cg_mop(:);

if perSegment
    % [nFreq x nTimes]: each hour gets its own depth. Depth enters only
    % through kh, so identical depths are solved once and reused -- the
    % Newton solve is the expensive part of a 65-record sweep.
    [hU, ~, iBack] = unique(round(h_site, 3));
    cgU = zeros(nFreq, numel(hU));
    cU  = zeros(nFreq, numel(hU));
    for m = 1:numel(hU)
        kU        = reshape(get_wavenumber(omega, hU(m)), nFreq, 1);
        cgU(:, m) = reshape(get_cg(kU, hU(m)), nFreq, 1);
        cU(:, m)  = omega ./ kU;
    end
    cg_site = cgU(:, iBack);
    c_site  = cU(:, iBack);
else
    k_site  = get_wavenumber(omega, h_site);
    cg_site = reshape(get_cg(k_site, h_site), nFreq, 1);
    c_site  = omega ./ k_site(:);
end

%% ---- Refraction coefficient ------------------------------------------
if ~isempty(opts.Kr)
    Kr = double(opts.Kr(:));
    if isscalar(Kr), Kr = repmat(Kr, nFreq, 1); end
    if numel(Kr) ~= nFreq
        error('shoal_mop_to_site:badKr', ...
            'opts.Kr must be scalar or [nFreq x 1] (got %d, expected %d).', ...
            numel(Kr), nFreq);
    end
elseif ~isempty(opts.theta_mop_deg)
    theta_mop = double(opts.theta_mop_deg(:));
    if isscalar(theta_mop), theta_mop = repmat(theta_mop, nFreq, 1); end
    if numel(theta_mop) ~= nFreq
        error('shoal_mop_to_site:badTheta', ...
            'opts.theta_mop_deg must be scalar or [nFreq x 1].');
    end
    c_mop = omega ./ k_mop(:);
    % Snell over straight parallel contours. c_site < c_mop in shoaling water,
    % so sin(theta_site) <= sin(theta_mop) and the asin is well posed; clamp
    % anyway to survive any pathological depth pairing. Broadcasting gives
    % [nFreq x 1] for a scalar site depth and [nFreq x nTimes] per-segment.
    sinTs = min(max(sind(theta_mop) .* (c_site ./ c_mop), -1), 1);
    Kr    = sqrt(cosd(theta_mop) ./ sqrt(1 - sinTs.^2));
else
    Kr = ones(nFreq, 1);
end

%% ---- Shoal ------------------------------------------------------------
% Energy conservation: S(h) = S(h_mop) * Cg(h_mop) / Cg(h), times Kr^2.
shoalFactor = (cg_mop ./ cg_site) .* (Kr.^2);       % [nFreq x 1] or [nFreq x nTimes]

if perSegment
    spec_shoaled = spec .* shoalFactor.';            % [nTimes x nFreq]
else
    spec_shoaled = spec .* shoalFactor(:).';         % broadcast
end

if opts.verbose
    if perSegment
        fprintf('  Shoaling MOP %.1f m -> site %.2f-%.2f m (per-segment, n=%d)\n', ...
            h_mop, min(h_site), max(h_site), nTimes);
    else
        fprintf('  Shoaling MOP %.1f m -> site %.1f m (scalar)\n', h_mop, h_site);
    end
end

%% ---- Bulk integrals over the band -------------------------------------
band = opts.band;
iB   = freq >= band(1) & freq <= band(2);

% Integrate with the MOP bandwidth vector, not a constant df.
m0 = spec_shoaled(:, iB) * fbw(iB);                  % [nTimes x 1]
Hs = 4 * sqrt(max(m0, 0));

if perSegment
    Ef = rho * g * sum(spec_shoaled(:, iB) .* (cg_site(iB, :).' .* fbw(iB).'), 2);
else
    Ef = rho * g * (spec_shoaled(:, iB) * (cg_site(iB) .* fbw(iB)));
end

%% ---- Pack -------------------------------------------------------------
out = struct();
out.spec        = spec_shoaled;
out.frequency   = freq;
out.fbw         = fbw;
if isfield(MOP, 'fbounds'), out.fbounds = double(MOP.fbounds); else, out.fbounds = []; end
if isfield(MOP, 'time'),    out.time    = MOP.time;            else, out.time    = [];  end
out.h_mop       = h_mop;
out.h_site      = h_site;
out.cg_mop      = cg_mop;
out.cg_site     = cg_site;
out.shoalFactor = shoalFactor;
out.Kr          = Kr;
out.Hs          = Hs;
out.Ef          = Ef;
out.band        = band;
out.perSegment  = perSegment;
