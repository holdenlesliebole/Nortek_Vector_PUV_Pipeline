% COMPARE_DERIVED_QUANTITIES  What the model's spectral errors do to the
% quantities people actually use: near-bed orbital velocity, energy flux, and
% the infragravity band the model does not resolve at all.
%
% function R = compare_derived_quantities(L2, opts)
%
% The model spectrum is pushed through the SAME operator the pipeline applies
% to the PUV spectrum, so a difference is a model-bias measurement rather than
% a methods difference:
%
%     Ub_rms^2 = integral[ T(f)^2 * S_eta(f) df ],   T(f) = omega / sinh(k h)
%
% (the convention in validation/verify_L2_products.m:41-45).
%
% THREE THINGS THIS DOES THAT A STRAIGHT RATIO DOES NOT
%
% 1. EXACT ENERGY/SHAPE DECOMPOSITION. Writing S = m0 * shat(f) with shat the
%    unit-area shape, the Ub ratio factors exactly:
%
%      Ub2_mop/Ub2_puv = (m0_mop/m0_puv) * (int shat_mop T^2 / int shat_puv T^2)
%                         \___ energy ___/  \________ shape ________/
%
%    Phase 1 found the model's peak SHAPE is unbiased while its ENERGY has real
%    spread, so this attributes the consequence to the right cause instead of
%    reporting one conflated number.
%
% 2. THE INFRAGRAVITY GAP. The CDIP MOP grid begins at ~0.037 Hz, so the IG
%    band is not biased in the model -- it is structurally absent. T(f) grows
%    as f falls, so IG is weighted MORE heavily at the bed than its share of
%    surface variance suggests. This is a categorical gap, not a percentage.
%
% 3. RETENTION VS FORCING, FIRST. PUV validity falls with wave height -- the
%    energy that makes the signal defeats the instrument -- so any statistic
%    conditioned on forcing (every threshold-exceedance number) is computed on
%    a sample selected by the forcing. P(PUV valid | model Hs) is reported
%    before any such statistic. The model Hs is the right conditioning axis
%    precisely because it exists whether or not the PUV survived.
%
% INPUTS
%   L2   - L2 struct or path to a *_L2.mat file
%   opts - .toolboxPath, .band (default L2.params.fSS), .bandIG (default
%          L2.params.fIG or [0.004 0.04]), .matchWindow (default 30 min),
%          .verbose (default true)
%
% OUTPUT
%   R - struct; empty .status on success. Key fields:
%       .closure_ratio      Ub from PUV spectrum through this code path,
%                           divided by L2.Ub. Sanity check on the operator.
%       .Ub_ratio           model/PUV near-bed orbital velocity (rms)
%       .Ub_energy_factor   the m0 part of that ratio
%       .Ub_shape_factor    the shape part
%       .Ub_bin_effect      PUV fine-grid Ub / PUV binned Ub. Shows whether
%                           the resolution issue that wrecked the shape
%                           metrics matters for an integral quantity.
%       .UbIG_over_UbSS     IG near-bed velocity relative to sea-swell, PUV
%       .IG_var_fraction    share of total near-bed variance in the IG band
%                           that the model cannot represent
%       .Ef_ratio           model/PUV energy flux
%       .retention          P(PUV valid | model Hs) by Hs bin
%
% UNITS AND FRAME (Rule 10): Ub_rms is the rms near-bed orbital velocity of a
% single horizontal component derived from the 1D elevation spectrum with no
% directional spreading, over the stated band, in m/s. It is NOT L2.Ub, which
% is built from the measured two-component velocity via bed_velocity_ifft.
% .closure_ratio reports the offset between the two conventions rather than
% assuming they agree.
%
% Author: Holden Leslie-Bole, 2026

function R = compare_derived_quantities(L2, opts)

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts,'toolboxPath'), opts.toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox'); end
if ~isfield(opts,'matchWindow'), opts.matchWindow = minutes(30); end
if ~isfield(opts,'verbose'),     opts.verbose     = true; end

if ~exist('read_MOPline2','file') && isfolder(opts.toolboxPath)
    addpath(opts.toolboxPath);
end
if ischar(L2) || isstring(L2)
    S = load(char(L2)); L2 = S.L2;
end

R = struct('status','','deployment',L2.deploymentName,'label',L2.label,'station','');

if ~isfield(opts,'band') || isempty(opts.band)
    if isfield(L2,'params') && isfield(L2.params,'fSS'), opts.band = L2.params.fSS;
    else, opts.band = [0.04 0.25]; end
end
if ~isfield(opts,'bandIG') || isempty(opts.bandIG)
    if isfield(L2,'params') && isfield(L2.params,'fIG'), opts.bandIG = L2.params.fIG;
    else, opts.bandIG = [0.004 0.04]; end
end
R.band = opts.band; R.bandIG = opts.bandIG;

rho = 1025; g = 9.81;

%% ---- Station and model load -------------------------------------------
station = '';
if isfield(L2,'refStation') && ~isempty(L2.refStation),      station = L2.refStation;
elseif isfield(L2,'mopStation') && ~isempty(L2.mopStation),  station = L2.mopStation;
else
    tok = regexp(L2.label,'MOP(\d+)','tokens','once');
    if ~isempty(tok), station = ['D0' tok{1}]; end
end
if isempty(station), R.status = 'no reference station'; return; end
R.station = station;

valid = find(L2.segValid);
if numel(valid) < 20, R.status = sprintf('only %d valid segments', numel(valid)); return; end

tS = min(L2.time(valid)); tE = max(L2.time(valid));
if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end
try
    MOP = read_MOPline2(station, tS, tE);
catch ME
    R.status = ['THREDDS failure: ' ME.message]; return
end
if isempty(MOP.time), R.status = 'no model data'; return; end

%% ---- (3) RETENTION VS FORCING, before anything conditioned on it ------
% Conditioning axis is the MODEL Hs, which exists for every hour regardless
% of whether the PUV survived that hour.
tAll = L2.time; if isempty(tAll.TimeZone), tAll.TimeZone = MOP.time.TimeZone; end
nM = numel(MOP.time);
pickAll = NaN(nM,1);
for t = 1:nM
    [dt, im] = min(abs(tAll - MOP.time(t)));
    if dt < opts.matchWindow, pickAll(t) = im; end
end
haveSeg = ~isnan(pickAll);
isValid = false(nM,1);
isValid(haveSeg) = L2.segValid(pickAll(haveSeg));

HsM = double(MOP.Hs(:));
edges = [0 0.5 1.0 1.5 2.0 2.5 3.0 inf];
ret = struct('edges',edges,'n',zeros(numel(edges)-1,1),'frac',NaN(numel(edges)-1,1));
for b = 1:numel(edges)-1
    m = haveSeg & HsM >= edges(b) & HsM < edges(b+1);
    ret.n(b) = sum(m);
    if any(m), ret.frac(b) = mean(isValid(m)); end
end
R.retention = ret;
okr = ret.n >= 10;
if sum(okr) > 2
    [R.retention_rho, R.retention_p] = corr(HsM(haveSeg), double(isValid(haveSeg)), 'type','Spearman');
else
    R.retention_rho = NaN; R.retention_p = NaN;
end

if opts.verbose
    fprintf('\n--- %s / %s (%s) ---\n', R.deployment, R.label, station);
    fprintf('  RETENTION P(PUV valid | model Hs):\n');
    for b = 1:numel(edges)-1
        if ret.n(b) < 10, continue; end
        hi = edges(b+1); if isinf(hi), hiStr = '  +'; else, hiStr = sprintf('%3.1f', hi); end
        fprintf('    Hs %3.1f-%s m : %5.1f%%  (n=%4d)\n', edges(b), hiStr, 100*ret.frac(b), ret.n(b));
    end
    fprintf('    rho(valid, Hs) = %+.3f (p = %.2g)\n', R.retention_rho, R.retention_p);
    if R.retention_rho < -0.1
        fprintf('    -> retention FALLS with forcing; forcing-conditioned statistics\n');
        fprintf('       below are computed on a selected sample. Reported, not hidden.\n');
    end
end

%% ---- Match hours and shoal --------------------------------------------
tP = L2.time(valid); if isempty(tP.TimeZone), tP.TimeZone = MOP.time.TimeZone; end
pick = NaN(nM,1);
for t = 1:nM
    [dt, im] = min(abs(tP - MOP.time(t)));
    if dt < opts.matchWindow, pick(t) = valid(im); end
end
keep = find(~isnan(pick));
if numel(keep) < 20, R.status = sprintf('only %d matched hours', numel(keep)); return; end
idxPUV = pick(keep); nK = numel(keep);

MOPk = MOP; MOPk.spec1D = MOP.spec1D(keep,:); MOPk.time = MOP.time(keep);
hSeg = L2.depth(idxPUV);
sh   = shoal_mop_to_site(MOPk, hSeg, struct('band', opts.band));

fMid = sh.frequency; fbw = sh.fbw; fbounds = sh.fbounds;
if isempty(fbounds), R.status = 'model has no fbounds'; return; end

f  = L2.f(:);
df = f(2)-f(1);
fCut   = median(L2.fCut(idxPUV),'omitnan'); if ~isfinite(fCut), fCut = opts.band(2); end
fHiEff = min(opts.band(2), fCut);

iB = fMid >= opts.band(1) & fMid <= fHiEff & fbounds(2,:)' <= fHiEff;
if sum(iB) < 4, iB = fMid >= opts.band(1) & fMid <= opts.band(2); end
iF   = f >= opts.band(1) & f <= fHiEff;
iFIG = f >= opts.bandIG(1) & f <= opts.bandIG(2);

R.nMatched = nK; R.nBins = sum(iB); R.fCut = fCut;
R.h_median = median(hSeg,'omitnan');
R.model_fmin = min(fbounds(:));

%% ---- Per-hour quantities ----------------------------------------------
z = NaN(nK,1);
seg = struct('Ub_puv_fine',z,'Ub_puv_bin',z,'Ub_mop',z, ...
             'm0_puv',z,'m0_mop',z,'I_puv',z,'I_mop',z, ...
             'UbIG_puv',z,'Ef_puv',z,'Ef_mop',z,'Ub_L2',z, ...
             'Ub_par',z,'Tp_puv',z,'Tp_mop',z, ...
             'tau_puv',z,'tau_mop',z,'sh_puv',z,'sh_mop',z, ...
             'Sxy_puv',z,'Sxy_mop',z,'Pl_puv',z,'Pl_mop',z, ...
             'th_puv',z,'th_mop',z, ...
             'Ab_puv',z,'Ab_mop',z,'Tb_puv',z,'Tb_mop',z, ...
             'Tm01_puv',z,'Tm01_mop',z,'Tpk_puv',z, ...
             'tau_puv_Tm01',z,'tau_mop_Tm01',z,'tau_puv_Tpk',z);

% Alongshore radiation stress needs the directional frame. Established by
% closure against CDIP's own published Sxy (validation/test_sxy_frame.m):
%   - MOP a2/b2 are GEOGRAPHIC; rotating second moments by 2*shorenormal
%     puts them shore-relative, reproducing MOP.Sxy at R = -1.000 with a
%     ratio of exactly -rho*g (CDIP normalizes by rho*g and uses the
%     opposite sign).
%   - PUV a2/b2 are ALREADY shore-relative (velocities are rotated to
%     shore-normal before the cross-spectra are formed).
% The un-rotated frame correlates at R = 0.974 -- close enough to look
% correct and wrong enough to flip the sign of alongshore forcing.
haveDir2 = isfield(L2,'a2') && isfield(L2,'b2') && ~isempty(L2.a2) ...
           && isfield(MOP,'a2') && ~isempty(MOP.a2);
if haveDir2 && isfield(MOP,'shorenormal')
    alpha = deg2rad(double(MOP.shorenormal));
else
    alpha = NaN;
end

% Sediment for the Shields normalization. Both sides use the SAME bed --
% the comparison is of the forcing, not of the sediment.
D50 = 2e-4;
if isfield(L2,'params') && isfield(L2.params,'D50') && isfinite(L2.params.D50)
    D50 = L2.params.D50;
end
% Roughness: match the pipeline's canonical choice ks = 2.5*D84 (Wiberg &
% Smith 1991), used by PUV_L2_spectral via bed_stress_ks, rather than the
% legacy ks = 10*D50 that bed_stress.m itself calls "unprincipled". Roughness
% largely cancels in a model/PUV ratio but sets absolute tau and the
% mobilization threshold.
ks = 10*D50; R.ks_source = 'legacy 10*D50';
if exist('site_grain_size','file') == 2
    try
        gs = site_grain_size(char(L2.label));
        if isfinite(gs.D84) && gs.D84 > 0
            ks = 2.5*gs.D84;
            R.ks_source = sprintf('2.5*D84 (%s)', char(gs.status));
            if isfinite(gs.D50) && gs.D50 > 0, D50 = gs.D50; end
        end
    catch
    end
end
R.D50 = D50; R.ks = ks;
rho_s = 2650; theta_cr = 0.05;
R.theta_cr = theta_cr;

for i = 1:nK
    ii = idxPUV(i);
    h  = hSeg(i);
    if ~isfinite(h) || h <= 0, continue; end
    s_fine = double(L2.S_eta(:, ii));
    if all(~isfinite(s_fine)), continue; end

    % --- transfer on the fine grid (PUV truth) and on the model grid
    Tf = transfer_bed(f(iF),    h);
    Tm = transfer_bed(fMid(iB), h);

    sF = s_fine(iF); sF(~isfinite(sF)) = 0;
    seg.Ub_puv_fine(i) = sqrt(sum(Tf.^2 .* sF) * df);

    % IG band, PUV only -- the model has no bins here
    sI = s_fine(iFIG); sI(~isfinite(sI)) = 0;
    TI = transfer_bed(f(iFIG), h);
    seg.UbIG_puv(i) = sqrt(sum(TI.^2 .* sI) * df);

    % --- matched grid, both sides
    sb = bin_spectrum_to_grid(f, s_fine, fbounds);
    sb = sb(iB); sb(~isfinite(sb)) = 0;
    sm = sh.spec(i,:)'; sm = sm(iB); sm(~isfinite(sm)) = 0;
    w  = fbw(iB);

    seg.Ub_puv_bin(i) = sqrt(sum(Tm.^2 .* sb .* w));
    seg.Ub_mop(i)     = sqrt(sum(Tm.^2 .* sm .* w));

    m0p = sum(sb .* w); m0m = sum(sm .* w);
    seg.m0_puv(i) = m0p; seg.m0_mop(i) = m0m;
    if m0p > 0, seg.I_puv(i) = sum(Tm.^2 .* (sb/m0p) .* w); end
    if m0m > 0, seg.I_mop(i) = sum(Tm.^2 .* (sm/m0m) .* w); end

    % --- energy flux. BOTH sides on the binned grid over the SAME bins.
    % Using the PUV fine grid over iF against the model over iB would compare
    % different frequency ranges (iB requires whole bins below fHiEff, so it
    % is strictly narrower) and manufacture a model deficit of tens of percent.
    cgm = sh.cg_site; if size(cgm,2) > 1, cgm = cgm(:,i); end
    seg.Ef_puv(i) = rho*g*sum(cgm(iB) .* sb .* w);
    seg.Ef_mop(i) = rho*g*sum(cgm(iB) .* sm .* w);

    if isfield(L2,'Ub'), seg.Ub_L2(i) = L2.Ub(ii); end

    % --- (Rule 17) PARAMETRIC BASELINE: what you get from the model's BULK
    % parameters alone, via a JONSWAP shape, pushed through the same operator.
    % If this matches the model's full-spectrum Ub, the spectral product buys
    % nothing for transport and the honest claim is "use the bulk parameters".
    fpM = double(MOP.fp(keep(i)));
    HsM_i = 4*sqrt(max(sum(sm .* w), 0));
    sPar  = jonswap_shape(fMid(iB), fpM);
    sPar  = sPar * (HsM_i^2/16) / max(sum(sPar .* w), eps);   % scale to model m0
    seg.Ub_par(i) = sqrt(sum(Tm.^2 .* sPar .* w));

    % --- BED STRESS AND SHIELDS: FULL-SPECTRUM ORBITAL EXCURSION.
    %
    % bed_stress* takes a single period and forms Aw = Ub*T/(2*pi) internally.
    % With a broad spectrum that is an approximation, because the bed transfer
    % omega/sinh(kh) is a strong low-pass: the frequency content of the
    % NEAR-BED orbital motion is not that of the surface elevation. The
    % spectrally consistent quantities are
    %     S_u(f) = S_eta(f)*(omega/sinh(kh))^2      near-bed velocity
    %     S_a(f) = S_u(f)/omega^2 = S_eta/sinh^2(kh)  near-bed displacement
    %     u_b = sqrt(int S_u df),  A_b = sqrt(int S_a df),  T_b = 2*pi*A_b/u_b
    % Passing T_b makes the routine's internal Aw exactly the spectral A_b, so
    % the single-period interface carries the full-spectrum answer.
    %
    % Measured on this catalog: T_b/T_m01 = 1.25-1.43 (the near-bed motion is
    % much longer-period than the surface), and T_b lands close to T_p. That
    % post-hoc justifies Paper 1's use of T_p, which is asserted there without
    % discussion. Using T_m01 instead overestimates tau by 4-14%.
    %
    % Both sides use the SAME definition. An earlier version compared the PUV
    % mean period against the model PEAK period -- different quantities, which
    % contaminated tau independently of any Ub error.
    Am = 1 ./ sinh(get_wavenumber(2*pi*fMid(iB), h) * h);   % 1/sinh(kh)

    m0p_i = sum(sb .* w); m0m_i = sum(sm .* w);
    if m0p_i > 0
        Ab_p = sqrt(sum((Am.^2) .* sb .* w));
        seg.Ab_puv(i) = Ab_p;
        seg.Tb_puv(i) = 2*pi*Ab_p / max(seg.Ub_puv_bin(i), eps);
        seg.Tm01_puv(i) = m0p_i / max(sum(fMid(iB) .* sb .* w), eps);
        fB_i = fMid(iB); [~, ipk] = max(sb); seg.Tpk_puv(i) = 1/fB_i(ipk);
        [tp, ~, ~] = bed_stress_ks(seg.Ub_puv_bin(i), seg.Tb_puv(i), ks, rho);
        seg.tau_puv(i) = tp;
        seg.sh_puv(i)  = tp / ((rho_s - rho)*g*D50);
        % sensitivity: the same stress under the two single-period proxies
        seg.tau_puv_Tm01(i) = bed_stress_ks(seg.Ub_puv_bin(i), seg.Tm01_puv(i), ks, rho);
        seg.tau_puv_Tpk(i)  = bed_stress_ks(seg.Ub_puv_bin(i), seg.Tpk_puv(i),  ks, rho);
    end
    if m0m_i > 0
        Ab_m = sqrt(sum((Am.^2) .* sm .* w));
        seg.Ab_mop(i) = Ab_m;
        seg.Tb_mop(i) = 2*pi*Ab_m / max(seg.Ub_mop(i), eps);
        seg.Tm01_mop(i) = m0m_i / max(sum(fMid(iB) .* sm .* w), eps);
        [tm, ~, ~] = bed_stress_ks(seg.Ub_mop(i), seg.Tb_mop(i), ks, rho);
        seg.tau_mop(i) = tm;
        seg.sh_mop(i)  = tm / ((rho_s - rho)*g*D50);
        seg.tau_mop_Tm01(i) = bed_stress_ks(seg.Ub_mop(i), seg.Tm01_mop(i), ks, rho);
    end

    % --- ALONGSHORE RADIATION STRESS, shore-normal frame, both sides.
    %   Sxy = rho*g * int S(f) * n(f) * (b2/2) df,   n = cg/c
    % and the alongshore energy flux driving transport, P_l = Sxy * c, which
    % a CERC-type transport estimate is linear in -- so a fractional Sxy
    % error maps directly to a fractional transport error without our having
    % to model breaking.
    if haveDir2 && isfinite(alpha)
        cgm_i = cgm(iB);
        c_i   = phase_speed(fMid(iB), h);
        n_i   = cgm_i ./ c_i;

        % PUV: already shore-relative; energy-weight before binning
        b2p_f = double(L2.b2(:, ii));
        if any(isfinite(b2p_f))
            nb = bin_spectrum_to_grid(f, s_fine .* b2p_f, fbounds);
            b2p = nb(iB) ./ max(sb, eps);
            b2p(~isfinite(b2p)) = 0;
            seg.Sxy_puv(i) = rho*g*sum(sb .* n_i .* (b2p/2) .* w);
            seg.Pl_puv(i)  = rho*g*sum(sb .* n_i .* (b2p/2) .* c_i .* w);
            % Effective obliquity. For a narrow directional distribution the
            % shore-frame second sine moment is b2 = sin(2*theta), so
            % theta = asin(b2)/2 is the energy-weighted angle of the wave
            % field from shore-normal, in degrees, positive in the same sense
            % as Sxy. This is the axis that separates the two explanations for
            % a negative slope: a frame error is a fixed rotation per MOP
            % line, a model failure should track obliquity across sites.
            b2b = sum(sb .* b2p .* w) / max(sum(sb .* w), eps);
            seg.th_puv(i) = 0.5*asind(max(min(b2b,1),-1));
        end

        % Model: rotate geographic second moments into the shore-normal frame
        a2m = double(MOP.a2(keep(i),:))'; b2m = double(MOP.b2(keep(i),:))';
        if numel(a2m) == numel(fMid) && any(isfinite(a2m))
            a2m(~isfinite(a2m)) = 0; b2m(~isfinite(b2m)) = 0;
            % Rotate into the shore-normal frame, then negate. The negation is
            % NOT a fudge to make the sign come out: the closure test
            % (test_sxy_frame.m) found MOP.Sxy = -(1/rho g) * (this rotation),
            % at R = -1.000 and a ratio of exactly -rho*g, i.e. CDIP's own
            % published convention is the negative of this rotation. That is
            % the signature of a nautical (clockwise-from-north) vs
            % mathematical (counterclockwise-from-east) angle convention,
            % which flips handedness and so negates b2, an odd function of
            % the rotation sense. The .Sxy_frame_ok handedness check below is
            % an INDEPENDENT confirmation, not the basis for the sign.
            b2r = -( -a2m*sin(2*alpha) + b2m*cos(2*alpha) );
            b2r = b2r(iB);
            seg.Sxy_mop(i) = rho*g*sum(sm .* n_i .* (b2r/2) .* w);
            seg.Pl_mop(i)  = rho*g*sum(sm .* n_i .* (b2r/2) .* c_i .* w);
            b2bm = sum(sm .* b2r .* w) / max(sum(sm .* w), eps);
            seg.th_mop(i) = 0.5*asind(max(min(b2bm,1),-1));
        end
    end
end

%% ---- Reduce ------------------------------------------------------------
med = @(v) median(v(isfinite(v) & v > 0));
g1 = isfinite(seg.Ub_puv_fine) & seg.Ub_puv_fine > 0;
if sum(g1) < 20, R.status = sprintf('only %d hours with finite Ub', sum(g1)); return; end
R.nGood = sum(g1);

% closure: this code path vs the pipeline's own L2.Ub
gc = g1 & isfinite(seg.Ub_L2) & seg.Ub_L2 > 0;
if any(gc)
    R.closure_ratio = median(seg.Ub_puv_fine(gc) ./ seg.Ub_L2(gc));
    cc = corrcoef(seg.Ub_puv_fine(gc), seg.Ub_L2(gc));
    R.closure_R = cc(1,2);
else
    R.closure_ratio = NaN; R.closure_R = NaN;
end

R.Ub_puv = med(seg.Ub_puv_fine);
R.Ub_mop = med(seg.Ub_mop);

% Exact decomposition, formed PER HOUR. The identity
%   Ub_mop/Ub_puv = sqrt(m0_mop/m0_puv) * sqrt(I_mop/I_puv)
% holds exactly for each hour but NOT after taking medians separately, since
% median(a*b) ~= median(a)*median(b). Computing the factors per hour and
% reducing afterwards keeps the reported numbers internally consistent.
gd = g1 & isfinite(seg.m0_puv) & seg.m0_puv > 0 & isfinite(seg.m0_mop) & seg.m0_mop > 0 ...
        & isfinite(seg.I_puv)  & seg.I_puv  > 0 & isfinite(seg.I_mop)  & seg.I_mop  > 0;
seg.energy_factor = NaN(nK,1); seg.shape_factor = NaN(nK,1); seg.Ub_ratio_hourly = NaN(nK,1);
seg.energy_factor(gd)   = sqrt(seg.m0_mop(gd) ./ seg.m0_puv(gd));
seg.shape_factor(gd)    = sqrt(seg.I_mop(gd)  ./ seg.I_puv(gd));
seg.Ub_ratio_hourly(gd) = seg.Ub_mop(gd) ./ seg.Ub_puv_bin(gd);

R.Ub_ratio         = median(seg.Ub_ratio_hourly(gd));
R.Ub_energy_factor = median(seg.energy_factor(gd));
R.Ub_shape_factor  = median(seg.shape_factor(gd));
% Per-hour identity check: max relative departure should be at round-off.
R.Ub_decomp_resid  = max(abs(seg.energy_factor(gd).*seg.shape_factor(gd) ...
                            - seg.Ub_ratio_hourly(gd)) ./ seg.Ub_ratio_hourly(gd));
R.Ub_shape_factor_iqr = [prctile(seg.shape_factor(gd),25), prctile(seg.shape_factor(gd),75)];

% does binning matter for an integral quantity? (it wrecked the shape metrics)
R.Ub_bin_effect = med(seg.Ub_puv_fine) / med(seg.Ub_puv_bin);

% infragravity
R.UbIG_puv       = med(seg.UbIG_puv);
R.UbIG_over_UbSS = R.UbIG_puv / R.Ub_puv;
R.IG_var_fraction = med(seg.UbIG_puv.^2) / (med(seg.UbIG_puv.^2) + med(seg.Ub_puv_fine.^2));

ge = gd & isfinite(seg.Ef_puv) & seg.Ef_puv > 0 & isfinite(seg.Ef_mop);
R.Ef_ratio = median(seg.Ef_mop(ge) ./ seg.Ef_puv(ge));

%% ---- Parametric baseline (Rule 17) ------------------------------------
gp = gd & isfinite(seg.Ub_par) & seg.Ub_par > 0;
if any(gp)
    R.Ub_par_ratio      = median(seg.Ub_par(gp)  ./ seg.Ub_puv_bin(gp));  % vs truth
    R.Ub_par_vs_full    = median(seg.Ub_par(gp)  ./ seg.Ub_mop(gp));      % vs full spectrum
    % Which is closer to the PUV: the model's full spectrum, or its bulk params?
    eFull = abs(seg.Ub_mop(gp)./seg.Ub_puv_bin(gp) - 1);
    ePar  = abs(seg.Ub_par(gp)./seg.Ub_puv_bin(gp) - 1);
    R.Ub_par_median_abs_err  = median(ePar);
    R.Ub_full_median_abs_err = median(eFull);
    R.spectrum_beats_bulk    = median(ePar) - median(eFull);   % >0 means spectrum helps
else
    R.Ub_par_ratio = NaN; R.Ub_par_vs_full = NaN;
    R.Ub_par_median_abs_err = NaN; R.Ub_full_median_abs_err = NaN;
    R.spectrum_beats_bulk = NaN;
end

%% ---- Bed stress, Shields, and threshold exceedance --------------------
gs = gd & isfinite(seg.tau_puv) & seg.tau_puv > 0 & isfinite(seg.tau_mop) & seg.tau_mop > 0;
if sum(gs) > 20
    R.tau_ratio    = median(seg.tau_mop(gs) ./ seg.tau_puv(gs));
    % Period-treatment sensitivity: how much the single-period proxies move
    % the ABSOLUTE stress relative to the full-spectrum A_b, and how much they
    % move the model/PUV RATIO (which is what the paper reports).
    gt = gs & isfinite(seg.tau_puv_Tm01) & seg.tau_puv_Tm01 > 0;
    if any(gt)
        R.Tb_over_Tm01     = median(seg.Tb_puv(gt) ./ seg.Tm01_puv(gt));
        R.Tb_over_Tpk      = median(seg.Tb_puv(gt) ./ seg.Tpk_puv(gt));
        R.tau_spec_over_Tm01 = median(seg.tau_puv(gt) ./ seg.tau_puv_Tm01(gt));
        R.tau_spec_over_Tpk  = median(seg.tau_puv(gt) ./ seg.tau_puv_Tpk(gt));
        R.tau_ratio_Tm01   = median(seg.tau_mop_Tm01(gt) ./ seg.tau_puv_Tm01(gt));
        R.Ab_ratio         = median(seg.Ab_mop(gt) ./ seg.Ab_puv(gt));
    else
        R.Tb_over_Tm01 = NaN; R.Tb_over_Tpk = NaN;
        R.tau_spec_over_Tm01 = NaN; R.tau_spec_over_Tpk = NaN;
        R.tau_ratio_Tm01 = NaN; R.Ab_ratio = NaN;
    end
    R.shields_ratio = median(seg.sh_mop(gs) ./ seg.sh_puv(gs));
    % Amplification: how a fractional Ub error propagates into tau_b.
    % Ill-conditioned when the Ub error is near zero (log(1) -> 0 in the
    % denominator), so it is only reported when there is an error to amplify.
    % Hand-derived expectation at fixed period, for Swart (1974)'s
    % rough-turbulent branch as implemented in bed_stress_ks.m:
    %     fw = 0.0521 * r^-0.187,  r = Aw/ks
    % so d(ln fw)/d(ln r) = -0.187 and, since r ~ Ub at fixed period,
    %     d(ln tau)/d(ln Ub) = 2 - 0.187 = 1.813.
    % (An earlier comment here said 1.66 from Nielsen's fw ~ r^-0.109; this
    % codebase uses Swart's -0.187, so 1.813 is the correct expectation.)
    ubr = median(seg.Ub_mop(gs) ./ seg.Ub_puv_bin(gs));
    R.Ub_ratio_for_amp = ubr;
    if abs(ubr - 1) > 0.02
        R.tau_amplification = log(R.tau_ratio) / log(ubr);
    else
        R.tau_amplification = NaN;   % no error to amplify; exponent undefined
    end
    R.tau_amplification_expected = 1.813;
    % The number a sediment reader cares about: mobilized hours
    R.mobil_hours_puv = sum(seg.sh_puv(gs) > theta_cr);
    R.mobil_hours_mop = sum(seg.sh_mop(gs) > theta_cr);
    R.mobil_frac_puv  = R.mobil_hours_puv / sum(gs);
    R.mobil_frac_mop  = R.mobil_hours_mop / sum(gs);
    if R.mobil_hours_puv > 0
        R.mobil_hours_ratio = R.mobil_hours_mop / R.mobil_hours_puv;
    else
        R.mobil_hours_ratio = NaN;
    end
    R.nShields = sum(gs);
else
    R.tau_ratio = NaN; R.shields_ratio = NaN; R.tau_amplification = NaN;
    R.mobil_hours_ratio = NaN; R.mobil_frac_puv = NaN; R.mobil_frac_mop = NaN;
    R.nShields = sum(gs);
end

%% ---- Alongshore forcing and transport ---------------------------------
ga = gd & isfinite(seg.Sxy_puv) & isfinite(seg.Sxy_mop);
if sum(ga) > 20
    x = seg.Sxy_puv(ga);   y = seg.Sxy_mop(ga);

    % --- THROUGH-ORIGIN SLOPE: the conditioned magnitude/handedness metric ---
    % (replaces correlation as the frame gate, 2026-07-27)
    %
    % Correlation and a free-intercept slope both reduce about the MEAN:
    %   b = sum((x-xbar)(y-ybar)) / sum((x-xbar)^2),  Var(b) = sn^2/(n*var(x))
    % Sxy on a given beach is usually one-signed for long stretches, so var(x)
    % is small relative to xbar^2 and both statistics are dominated by noise.
    % Through the origin -- which is also the physically correct constraint,
    % since Sxy = 0 must map to Sxy = 0 -- the second moment is taken about
    % zero instead:
    %   b0 = sum(x*y) / sum(x^2),        Var(b0) = sn^2/(n*(var(x)+xbar^2))
    %   Var(b)/Var(b0) = 1 + xbar^2/var(x)
    % At xbar/sd = 3 (a typical unidirectional record) the free-intercept
    % slope is 10x noisier. This is the same conditioning defect that made
    % Sxy_R look like a quality flag when it is not: |net|/gross is a proxy
    % for xbar/sd, hence the catalog-wide rho(|net|/gross, Sxy_R) = -0.417.
    R.Sxy_b0 = sum(x.*y) / max(sum(x.^2), eps);
    R.Sxy_frame_ok = R.Sxy_b0 > 0;

    % Kept as a DESCRIPTOR only -- never a gate. See above for why.
    cc = corrcoef(x, y);
    R.Sxy_R = cc(1,2);

    R.Sxy_puv_med = median(x);
    R.Sxy_mop_med = median(y);

    % Retained for continuity with the pre-2026-07-27 numbers; superseded by
    % Sxy_b0 and not to be quoted on its own.
    p = polyfit(x, y, 1);
    R.Sxy_slope = p(1);

    R.Sxy_rmse  = sqrt(mean((y-x).^2));
    R.Sxy_nrmse = R.Sxy_rmse / max(std(x), eps);           % legacy, mean-referenced
    % Normalise by the mean ABSOLUTE Sxy rather than the standard deviation,
    % for the same reason: sd(x) collapses on unidirectional records and
    % inflates nRMSE there even when the model is doing well.
    R.Sxy_nrmse_abs = R.Sxy_rmse / max(mean(abs(x)), eps);

    % Net alongshore transport is the TIME-INTEGRAL of P_l, so a net-drift
    % error matters more than the scatter: partial cancellation means a
    % small hourly bias can dominate the integral.
    R.Pl_net_puv = sum(seg.Pl_puv(ga));
    R.Pl_net_mop = sum(seg.Pl_mop(ga));
    if abs(R.Pl_net_puv) > 0
        R.Pl_net_ratio = R.Pl_net_mop / R.Pl_net_puv;
    else
        R.Pl_net_ratio = NaN;
    end
    R.Pl_gross_puv = sum(abs(seg.Pl_puv(ga)));
    R.Pl_gross_mop = sum(abs(seg.Pl_mop(ga)));
    R.Pl_gross_ratio = R.Pl_gross_mop / max(R.Pl_gross_puv, eps);
    % How much cancellation: |net|/gross. Low values mean the net is a small
    % residual of large opposing fluxes and is correspondingly fragile.
    R.Pl_cancellation_puv = abs(R.Pl_net_puv)/max(R.Pl_gross_puv, eps);
    % --- OBLIQUITY, for the frame-vs-model discrimination -----------------
    gt = ga & isfinite(seg.th_puv) & isfinite(seg.th_mop);
    if sum(gt) > 20
        R.theta_puv_med = median(seg.th_puv(gt));
        R.theta_mop_med = median(seg.th_mop(gt));
        R.theta_puv_absmed = median(abs(seg.th_puv(gt)));
        dth = seg.th_mop(gt) - seg.th_puv(gt);
        R.dtheta_med = median(dth);
        R.dtheta_iqr = prctile(dth,75) - prctile(dth,25);
        % Fraction of hours on which the two disagree about which way the
        % alongshore forcing points. Sign-only, so it is immune to the
        % magnitude conditioning that broke the correlation.
        R.sign_agree = mean(sign(seg.Sxy_puv(ga)) == sign(seg.Sxy_mop(ga)));
    else
        R.theta_puv_med = NaN; R.theta_mop_med = NaN; R.theta_puv_absmed = NaN;
        R.dtheta_med = NaN; R.dtheta_iqr = NaN; R.sign_agree = NaN;
    end
    R.nSxy = sum(ga);
else
    R.Sxy_R = NaN; R.Sxy_frame_ok = false; R.Sxy_slope = NaN;
    R.Sxy_b0 = NaN; R.Sxy_nrmse_abs = NaN;
    R.theta_puv_med = NaN; R.theta_mop_med = NaN; R.theta_puv_absmed = NaN;
    R.dtheta_med = NaN; R.dtheta_iqr = NaN; R.sign_agree = NaN;
    R.Pl_net_ratio = NaN; R.Pl_gross_ratio = NaN; R.Pl_cancellation_puv = NaN;
    R.nSxy = sum(ga);
end

R.seg = seg;

if opts.verbose
    fprintf('  CLOSURE  Ub(this path) / L2.Ub = %.3f  (R = %.3f)\n', R.closure_ratio, R.closure_R);
    fprintf('  Ub       model/PUV = %.3f   [energy %.3f x shape %.3f]  identity resid %.1e\n', ...
        R.Ub_ratio, R.Ub_energy_factor, R.Ub_shape_factor, R.Ub_decomp_resid);
    fprintf('           shape factor IQR %.3f - %.3f\n', ...
        R.Ub_shape_factor_iqr(1), R.Ub_shape_factor_iqr(2));
    fprintf('  Ub       binning effect on PUV Ub = %.4f  (1.000 = binning irrelevant)\n', R.Ub_bin_effect);
    fprintf('  IG       Ub_IG/Ub_SS = %.3f, IG share of near-bed variance = %.1f%%\n', ...
        R.UbIG_over_UbSS, 100*R.IG_var_fraction);
    fprintf('           model grid starts at %.3f Hz; IG band [%.3f %.3f] is unrepresented\n', ...
        R.model_fmin, opts.bandIG(1), opts.bandIG(2));
    fprintf('  Ef       model/PUV = %.3f\n', R.Ef_ratio);
    fprintf('  BASELINE JONSWAP-from-bulk Ub / PUV = %.3f;  vs full spectrum = %.3f\n', ...
        R.Ub_par_ratio, R.Ub_par_vs_full);
    fprintf('           median |err|: full spectrum %.4f vs bulk-parametric %.4f  -> %s\n', ...
        R.Ub_full_median_abs_err, R.Ub_par_median_abs_err, ...
        ternary_str(R.spectrum_beats_bulk > 0, 'spectrum helps', 'spectrum adds NOTHING'));
    fprintf('  PERIOD   T_b/T_m01 = %.3f, T_b/T_peak = %.3f | full-spectrum tau vs\n', ...
        R.Tb_over_Tm01, R.Tb_over_Tpk);
    fprintf('           single-period: /T_m01 %.3f, /T_peak %.3f  (ks: %s)\n', ...
        R.tau_spec_over_Tm01, R.tau_spec_over_Tpk, R.ks_source);
    fprintf('  SHIELDS  tau ratio = %.3f (Ub error amplified ^%.2f, expect %.3f), Shields ratio = %.3f\n', ...
        R.tau_ratio, R.tau_amplification, R.tau_amplification_expected, R.shields_ratio);
    fprintf('           tau ratio under T_m01 instead = %.3f (ratio robustness)\n', R.tau_ratio_Tm01);
    fprintf('           mobilized hours: PUV %.1f%%, model %.1f%% -> ratio %.3f (n=%d)\n', ...
        100*R.mobil_frac_puv, 100*R.mobil_frac_mop, R.mobil_hours_ratio, R.nShields);
    if isfinite(R.Sxy_R)
        fprintf('  ALONGSHORE Sxy  R = %+.3f %s, slope %.3f, nRMSE %.3f (n=%d)\n', ...
            R.Sxy_R, ternary_str(R.Sxy_frame_ok,'(frame OK)','(FRAME MISMATCH - sign error!)'), ...
            R.Sxy_slope, R.Sxy_nrmse, R.nSxy);
        fprintf('           net alongshore flux ratio %.3f, gross %.3f, |net|/gross(PUV) %.3f\n', ...
            R.Pl_net_ratio, R.Pl_gross_ratio, R.Pl_cancellation_puv);
    end
end
end

%% ---- local ------------------------------------------------------------
function T = transfer_bed(fv, h)
    om = 2*pi*fv(:);
    k  = get_wavenumber(om, h);
    T  = om ./ sinh(k(:) * h);
end

function cg = group_velocity(fv, h)
    om = 2*pi*fv(:);
    k  = get_wavenumber(om, h);
    cg = reshape(get_cg(k, h), [], 1);
end

function S = jonswap_shape(fv, fp)
% Unit-scale JONSWAP shape (gamma = 3.3). Only the SHAPE is used -- the
% caller rescales to the model's own m0 -- so the Phillips constant drops out.
    fv = fv(:); gamma = 3.3;
    sig = 0.07*(fv <= fp) + 0.09*(fv > fp);
    r   = exp(-((fv - fp).^2) ./ (2*(sig.^2)*fp^2));
    S   = fv.^(-5) .* exp(-1.25*(fp./fv).^4) .* gamma.^r;
    S(~isfinite(S)) = 0;
end

function s = ternary_str(c, a, b), if c, s = a; else, s = b; end, end

function c = phase_speed(fv, h)
    om = 2*pi*fv(:);
    k  = get_wavenumber(om, h);
    c  = om ./ k(:);
end
