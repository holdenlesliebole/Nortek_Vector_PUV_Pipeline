% COMPARE_SHAPE_MATCHED  Resolution-matched PUV-vs-model spectral shape comparison.
%
% function R = compare_shape_matched(L2, opts)
%
% Replaces the shape metrics in analyze_spectral_shape.m, which computed
% half-power bandwidth and Goda Qp after interpolating the model's ~20 coarse
% bins UP onto the PUV's 3601-point grid. That path manufactures the effect it
% was measuring: a PUV spectrum compared against a degraded copy of itself
% through it returns 68% apparent bandwidth narrowing and a Qp ratio of 1.225
% (see validation/test_resolution_artifact.m).
%
% Here BOTH products are reduced to the model's native bin grid before any
% metric is computed, so the resolution bias applies identically to both sides
% and cancels in every ratio. Verified to recover injected broadening at 95-96%
% efficiency down to r = 1.02 (validation/test_shape_metric_sensitivity.m).
%
% Half-power bandwidth is deliberately NOT reported on the matched grid: with
% ~16 usable bins the peak spans ~4 of them and the metric is meaningless.
% Normalized peak density and narrowness nu replace it.
%
% INPUTS
%   L2   - L2 struct, or a path to a *_L2.mat file
%   opts - (optional) struct:
%           .toolboxPath  path holding read_MOPline2. Default ~/…/Research/toolbox
%           .band         [fLo fHi] Hz. Default L2.params.fSS, else [0.04 0.25]
%           .fHiList      band upper limits for the nu-truncation diagnostic.
%                         Default [0.25 0.22 0.20 0.18 0.15 0.12]
%           .matchWindow  max PUV-model time offset. Default minutes(30)
%           .perSegDepth  use per-hour tidal depth when shoaling. Default true
%           .legacy       also compute the old interp-up metrics for
%                         side-by-side auditing. Default true
%           .verbose      Default true
%
% OUTPUT
%   R - struct. Empty .status field means success; otherwise .status names the
%       reason the record was skipped (no station, no model data, too few
%       matched hours, THREDDS failure).
%       Key fields (all medians over matched hours unless noted):
%         .Qp_puv .Qp_mop .Qp_ratio            Goda peakedness, matched grid
%         .pkNorm_puv .pkNorm_mop .pkNorm_ratio  normalized peak density
%         .nu_puv .nu_mop .nu_ratio            narrowness sqrt(m0*m2/m1^2-1)
%         .nu_ratio_byFHi                      nu ratio at each opts.fHiList
%         .sig1_puv .sig1_mop .sig1_ratio      directional spread at the peak
%         .Hs_ratio .m0_ratio
%         .fracM2_hi_puv .fracM2_hi_mop        share of m2 above 0.18 Hz
%         .Qp_ratio_legacy .bw_narrow_legacy   old interp-up path, for audit
%         .seg_*                               per-hour vectors
%         .nMatched .nBins .fCut .h_median .station .band
%
% Author: Holden Leslie-Bole, 2026

function R = compare_shape_matched(L2, opts)

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts,'toolboxPath'), opts.toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox'); end
if ~isfield(opts,'fHiList'),     opts.fHiList     = [0.25 0.22 0.20 0.18 0.15 0.12]; end
if ~isfield(opts,'matchWindow'), opts.matchWindow = minutes(30); end
if ~isfield(opts,'perSegDepth'), opts.perSegDepth = true;  end
if ~isfield(opts,'legacy'),      opts.legacy      = true;  end
if ~isfield(opts,'verbose'),     opts.verbose     = true;  end

if ~exist('read_MOPline2','file') && isfolder(opts.toolboxPath)
    addpath(opts.toolboxPath);
end

if ischar(L2) || isstring(L2)
    S = load(char(L2)); L2 = S.L2;
end

R = struct('status','', 'deployment','', 'label','', 'station','');
R.deployment = L2.deploymentName;
R.label      = L2.label;

if ~isfield(opts,'band') || isempty(opts.band)
    if isfield(L2,'params') && isfield(L2.params,'fSS')
        opts.band = L2.params.fSS;
    else
        opts.band = [0.04 0.25];
    end
end
R.band = opts.band;

%% ---- Reference station -------------------------------------------------
station = '';
if isfield(L2,'refStation') && ~isempty(L2.refStation)
    station = L2.refStation;
elseif isfield(L2,'mopStation') && ~isempty(L2.mopStation)
    station = L2.mopStation;
else
    tok = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if ~isempty(tok), station = ['D0' tok{1}]; end
end
if isempty(station)
    R.status = 'no reference station (outside MOP coverage)';
    return
end
R.station = station;

valid = find(L2.segValid);
if numel(valid) < 20
    R.status = sprintf('only %d valid segments', numel(valid));
    return
end

%% ---- Load model --------------------------------------------------------
tS = min(L2.time(valid)); tE = max(L2.time(valid));
if isempty(tS.TimeZone), tS.TimeZone = 'UTC'; tE.TimeZone = 'UTC'; end

try
    MOP = read_MOPline2(station, tS, tE);
catch ME
    R.status = ['THREDDS failure: ' ME.message];
    return
end
if isempty(MOP.time) || isempty(MOP.spec1D)
    R.status = 'no model data in window';
    return
end

%% ---- Match times -------------------------------------------------------
tP = L2.time(valid);
if isempty(tP.TimeZone), tP.TimeZone = MOP.time.TimeZone; end

nM   = numel(MOP.time);
pick = NaN(nM,1);
for t = 1:nM
    [dt, im] = min(abs(tP - MOP.time(t)));
    if dt < opts.matchWindow, pick(t) = valid(im); end
end
keep = find(~isnan(pick));
if numel(keep) < 20
    R.status = sprintf('only %d matched hours', numel(keep));
    return
end
idxPUV = pick(keep);
nK     = numel(keep);

%% ---- Shoal model to site ----------------------------------------------
MOPk        = MOP;
MOPk.spec1D = MOP.spec1D(keep,:);
MOPk.time   = MOP.time(keep);

hSeg = L2.depth(idxPUV);
if opts.perSegDepth && all(isfinite(hSeg)) && all(hSeg > 0)
    hUse = hSeg;
else
    hUse = median(L2.depth(valid), 'omitnan');
end
sh = shoal_mop_to_site(MOPk, hUse, struct('band', opts.band));

% The model point sits on the ~10 m contour. Transforming to a site deeper
% than that runs the shoaling relation backwards, outside the regime it was
% built for, and the result is not a model-bias measurement. Flag rather than
% silently report -- RUBY22/MOP582_30m produced Hs ratio 0.008 this way.
R.depthExtrapolation = median(hUse) > 1.25 * sh.h_mop;
if R.depthExtrapolation && opts.verbose
    fprintf('  [warn] %s/%s: site depth %.1f m exceeds model depth %.1f m; ', ...
        R.deployment, R.label, median(hUse), sh.h_mop);
    fprintf('shoaling is an extrapolation to deeper water.\n');
end

fMid    = sh.frequency;
fbw     = sh.fbw;
fbounds = sh.fbounds;
if isempty(fbounds)
    R.status = 'model struct has no fbounds; cannot bin to matched grid';
    return
end

%% ---- Band mask on the model grid --------------------------------------
f    = L2.f(:);
fCut = median(L2.fCut(idxPUV), 'omitnan');
if ~isfinite(fCut), fCut = opts.band(2); end

fHiEff = min(opts.band(2), fCut);
iB = fMid >= opts.band(1) & fMid <= fHiEff & fbounds(2,:)' <= fHiEff;
if sum(iB) < 4
    iB = fMid >= opts.band(1) & fMid <= opts.band(2);   % fall back
end
if sum(iB) < 4
    R.status = sprintf('only %d model bins in band', sum(iB));
    return
end

R.nBins    = sum(iB);
R.fCut     = fCut;
R.h_median = median(hSeg, 'omitnan');
R.nMatched = nK;

%% ---- Bin PUV down, compute matched metrics ----------------------------
nF = numel(fMid);
Spuv_c = NaN(nF, nK);
a1_c   = NaN(nF, nK);
b1_c   = NaN(nF, nK);

hasDir = isfield(L2,'a1') && isfield(L2,'b1') && ~isempty(L2.a1);

for i = 1:nK
    s = double(L2.S_eta(:, idxPUV(i)));
    if all(~isfinite(s)), continue; end
    Spuv_c(:,i) = bin_spectrum_to_grid(f, s, fbounds);

    if hasDir
        a = double(L2.a1(:, idxPUV(i)));
        b = double(L2.b1(:, idxPUV(i)));
        if any(isfinite(a))
            % Energy-weight the directional moments before binning: a1 is a
            % normalized quantity, so binning it directly would average
            % directions without regard to how much energy carries them.
            num_a = bin_spectrum_to_grid(f, s .* a, fbounds);
            num_b = bin_spectrum_to_grid(f, s .* b, fbounds);
            a1_c(:,i) = num_a ./ Spuv_c(:,i);
            b1_c(:,i) = num_b ./ Spuv_c(:,i);
        end
    end
end
Smop_c = sh.spec.';                                  % [nF x nK]

seg = struct();
[seg.Qp_puv,  seg.pkNorm_puv, seg.nu_puv, seg.m0_puv] = deal(NaN(nK,1));
[seg.Qp_mop,  seg.pkNorm_mop, seg.nu_mop, seg.m0_mop] = deal(NaN(nK,1));
seg.Hs_ratio  = NaN(nK,1);
seg.sig1_puv  = NaN(nK,1);
seg.sig1_mop  = NaN(nK,1);
seg.Qp_ratio_legacy  = NaN(nK,1);
seg.bw_narrow_legacy = NaN(nK,1);

hasMopDir = isfield(MOP,'a1') && ~isempty(MOP.a1);

for i = 1:nK
    if all(~isfinite(Spuv_c(:,i))), continue; end

    [seg.Qp_puv(i), seg.pkNorm_puv(i), seg.nu_puv(i), seg.m0_puv(i)] = ...
        shape_coarse(Spuv_c(:,i), fMid, fbw, iB);
    [seg.Qp_mop(i), seg.pkNorm_mop(i), seg.nu_mop(i), seg.m0_mop(i)] = ...
        shape_coarse(Smop_c(:,i), fMid, fbw, iB);

    if seg.m0_puv(i) > 0 && seg.m0_mop(i) > 0
        seg.Hs_ratio(i) = sqrt(seg.m0_puv(i)/seg.m0_mop(i));
    end

    % Directional spread at the spectral peak, both on the matched grid
    if hasDir && any(isfinite(a1_c(:,i)))
        seg.sig1_puv(i) = sig1_at_peak(Spuv_c(:,i), a1_c(:,i), b1_c(:,i), iB);
    end
    if hasMopDir
        am = double(MOP.a1(keep(i),:)).';
        bm = double(MOP.b1(keep(i),:)).';
        if numel(am) == nF
            seg.sig1_mop(i) = sig1_at_peak(Smop_c(:,i), am, bm, iB);
        end
    end

    % Legacy interp-up path, retained so the correction stays auditable
    if opts.legacy
        s_fine = double(L2.S_eta(:, idxPUV(i)));
        s_up   = interp1(fMid, Smop_c(:,i), f, 'linear', 0);
        iF     = f >= opts.band(1) & f <= opts.band(2);
        df     = f(2) - f(1);
        [qp, bwp] = shape_fine(s_fine, f, iF);
        [qm, bwm] = shape_fine(s_up,   f, iF);
        if isfinite(qp) && isfinite(qm) && qm > 0
            seg.Qp_ratio_legacy(i) = qp/qm;
        end
        if isfinite(bwp) && isfinite(bwm) && bwm > 0
            seg.bw_narrow_legacy(i) = 100*(1 - (bwp*df)/(bwm*df));
        end
    end
end

%% ---- nu vs band upper limit (the cutoff-noise falsifier) --------------
nuByFHi = NaN(numel(opts.fHiList),1);
for j = 1:numel(opts.fHiList)
    ib = fMid >= opts.band(1) & fMid <= opts.fHiList(j);
    if sum(ib) < 4, continue; end
    np = NaN(nK,1); nm = NaN(nK,1);
    for i = 1:nK
        if all(~isfinite(Spuv_c(:,i))), continue; end
        [~,~,np(i)] = shape_coarse(Spuv_c(:,i), fMid, fbw, ib);
        [~,~,nm(i)] = shape_coarse(Smop_c(:,i), fMid, fbw, ib);
    end
    g = isfinite(np) & isfinite(nm);
    if any(g), nuByFHi(j) = median(np(g))/median(nm(g)); end
end

%% ---- Where the m2 difference lives ------------------------------------
m0p = sum(Spuv_c(iB,:) .* fbw(iB), 1, 'omitnan');
m0m = sum(Smop_c(iB,:) .* fbw(iB), 1, 'omitnan');
cp  = median((Spuv_c(iB,:) .* (fMid(iB).^2) .* fbw(iB)) ./ m0p, 2, 'omitnan');
cm  = median((Smop_c(iB,:) .* (fMid(iB).^2) .* fbw(iB)) ./ m0m, 2, 'omitnan');
fB  = fMid(iB);
R.m2_contrib_f   = fB;
R.m2_contrib_puv = cp;
R.m2_contrib_mop = cm;
R.fracM2_hi_puv  = sum(cp(fB > 0.18)) / sum(cp);
R.fracM2_hi_mop  = sum(cm(fB > 0.18)) / sum(cm);

%% ---- Reduce -----------------------------------------------------------
g = isfinite(seg.Qp_puv) & isfinite(seg.Qp_mop);
R.nGood = sum(g);
if R.nGood < 20
    R.status = sprintf('only %d hours produced finite metrics', R.nGood);
    return
end

med = @(v) median(v(isfinite(v)));
R.Qp_puv     = med(seg.Qp_puv);      R.Qp_mop     = med(seg.Qp_mop);
R.pkNorm_puv = med(seg.pkNorm_puv);  R.pkNorm_mop = med(seg.pkNorm_mop);
R.nu_puv     = med(seg.nu_puv);      R.nu_mop     = med(seg.nu_mop);
R.sig1_puv   = med(seg.sig1_puv);    R.sig1_mop   = med(seg.sig1_mop);

R.Qp_ratio     = R.Qp_puv     / R.Qp_mop;
R.pkNorm_ratio = R.pkNorm_puv / R.pkNorm_mop;
R.nu_ratio     = R.nu_puv     / R.nu_mop;
R.sig1_ratio   = R.sig1_puv   / R.sig1_mop;
R.Hs_ratio     = med(seg.Hs_ratio);
R.m0_ratio     = med(seg.m0_puv) / med(seg.m0_mop);

R.nu_ratio_byFHi = nuByFHi;
R.fHiList        = opts.fHiList(:);

R.Qp_ratio_legacy  = med(seg.Qp_ratio_legacy);
R.bw_narrow_legacy = med(seg.bw_narrow_legacy);

R.seg  = seg;
R.time = MOP.time(keep);

if opts.verbose
    fprintf('  %-9s %-12s h=%4.1fm  n=%4d  bins=%2d | Qp %.3f  pk %.3f  nu %.3f  Hs %.3f | legacy Qp %.3f\n', ...
        R.deployment, R.label, R.h_median, R.nGood, R.nBins, ...
        R.Qp_ratio, R.pkNorm_ratio, R.nu_ratio, R.Hs_ratio, R.Qp_ratio_legacy);
end

end % main

%% ======================= local functions =============================
function [Qp, pkNorm, nu, m0] = shape_coarse(s, fMid, fbw, iB)
    ss = s(iB); ss(~isfinite(ss)) = 0;
    fm = fMid(iB); w = fbw(iB);
    m0 = sum(ss .* w);
    if m0 <= 0, Qp = NaN; pkNorm = NaN; nu = NaN; return; end
    m1 = sum(fm    .* ss .* w);
    m2 = sum(fm.^2 .* ss .* w);
    Qp = (2/m0^2) * sum(fm .* ss.^2 .* w);
    [pk, ipk] = max(ss);
    pkNorm = pk / (m0 / fm(ipk));         % dimensionless
    nu = sqrt(max(m0*m2/m1^2 - 1, 0));
end

function [Qp, bwCount] = shape_fine(s, f, iF)
    sp = s(iF); sp(~isfinite(sp)) = 0; ff = f(iF);
    m0 = trapz(ff, sp);
    if m0 <= 0, Qp = NaN; bwCount = NaN; return; end
    Qp = (2/m0^2) * trapz(ff, ff .* sp.^2);
    pk = max(sp);
    bwCount = sum(sp >= pk/2);
end

function s1 = sig1_at_peak(S, a1, b1, iB)
    ss = S(iB); ss(~isfinite(ss)) = 0;
    aa = a1(iB); bb = b1(iB);
    [~, ipk] = max(ss);
    r1 = sqrt(aa(ipk)^2 + bb(ipk)^2);
    if ~isfinite(r1), s1 = NaN; return; end
    r1 = min(max(r1, 0), 1);
    s1 = sqrt(2*(1 - r1));                % radians
end
