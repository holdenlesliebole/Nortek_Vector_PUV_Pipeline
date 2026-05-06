function L2 = PUV_L2_spectral(PUV, instr, opts)
% PUV_L2_SPECTRAL  Level-2 spectral analysis for one PUV instrument.
%
%   L2 = PUV_L2_spectral(PUV, instr, opts)
%
% Default segment length is 1 hour (7200 samples @ 2 Hz). The
% within-hour-stationarity audit and the cross-deployment mean-flow
% validation both support this as the right choice for bulk
% parameters and segment-mean velocity — matches MOP cadence, gives
% finer Δf, and gives the longer N that the segment-mean velocity
% benefits from (1/√N noise reduction). The legacy 17-min default
% (segLen=2048) can be recovered by passing `opts.segLen=2048`
% explicitly. See docs/mean_flow_validation_plan.md for the
% rationale.
%
%   Segments the L1 QC'd timeseries into 1-hour (7200-sample @ 2 Hz)
%   windows by default, and computes:
%     - Surface elevation spectrum (Wu pressure correction)
%     - Directional coefficients (a1, b1, a2, b2)
%     - Bulk wave parameters (Hs, Tp, mean direction, energy flux)
%     - Z-test (pressure vs velocity spectral consistency)
%     - Radiation stress tensor (Sxx, Syy, Sxy; Herbers & Guza 1989)
%     - Near-bed orbital velocity (IFFT linear wave theory)
%     - Bed shear stress (Swart 1974)
%     - Reynolds stress and TKE
%     - Velocity moments (skewness, asymmetry)
%
%   INPUTS
%     PUV   - L1 struct from PUV_raw_process (loaded from *_processed.mat)
%     instr - instrument config struct (from deployment config), needs:
%               .mopStation  (string, e.g. 'D0580') for shore-normal rotation
%     opts  - (optional) struct to override defaults:
%               .segLen   - segment length in samples (default 7200 = 1 hr @ 2 Hz)
%               .nfft     - pwelch sub-segment length (default 256)
%               .overlap  - pwelch fractional overlap (default 0.5)
%               .KpMin    - pressure correction cutoff (default 0.1)
%               .rho      - seawater density kg/m^3 (default 1025)
%               .g        - gravity m/s^2 (default 9.81)
%               .D50      - median grain diameter m (default 0.25e-3)
%               .fIG      - IG band [fLow fHigh] Hz (default [0.004 0.04])
%               .fSS      - SS band [fLow fHigh] Hz (default [0.04 0.25])
%               .doRotate - shore-normal rotation flag (default true)
%               .nanMaxFrac - max NaN fraction to accept per segment (default 0.10)
%
%   OUTPUT
%     L2 - struct with spectral results, bulk params, and metadata
%
%   REQUIRES
%     On MATLAB path: pressure_correction_wu, compute_bulk_params,
%     bed_velocity_ifft, bed_stress, compute_reynolds_stress,
%     compute_velocity_moments, rotate_shorenormal, get_wavenumber, get_cg
% Author: Holden Leslie-Bole, 2026

%% ======================== DEFAULTS ========================
if nargin < 3, opts = struct(); end

if ~isfield(opts, 'segLen'),     opts.segLen     = 7200;         end
if ~isfield(opts, 'nfft'),       opts.nfft       = 256;          end
if ~isfield(opts, 'overlap'),    opts.overlap     = 0.5;          end
if ~isfield(opts, 'KpMin'),      opts.KpMin      = 0.1;          end
if ~isfield(opts, 'rho'),        opts.rho        = 1025;          end
if ~isfield(opts, 'g'),          opts.g          = 9.81;          end
if ~isfield(opts, 'D50'),        opts.D50        = 0.25e-3;       end  % TODO: replace with real grain size from Laser Particle Analyzer
if ~isfield(opts, 'fIG'),        opts.fIG        = [0.004, 0.04]; end
if ~isfield(opts, 'fSS'),        opts.fSS        = [0.04, 0.25];  end
if ~isfield(opts, 'doRotate'),       opts.doRotate       = true;          end
if ~isfield(opts, 'nanMaxFrac'),     opts.nanMaxFrac     = 0.10;          end
if ~isfield(opts, 'spectralMethod'), opts.spectralMethod = 'mtm_full';     end  % 'welch', 'mtm_hybrid', 'mtm_full'
if ~isfield(opts, 'NW'),            opts.NW             = 4;              end  % time-bandwidth product for multi-taper
if ~isfield(opts, 'HsMaxToHRatio'), opts.HsMaxToHRatio  = 1.5;            end  % unphysical Hs/h threshold; segValid=false if exceeded
if ~isfield(opts, 'depthDeviationMax'), opts.depthDeviationMax = 0.5;     end  % |H - depth_nominal|/depth_nominal threshold; 0 to disable

fs     = PUV.fs;
segLen = opts.segLen;
N      = length(PUV.P);
nSeg   = floor(N / segLen);

% Check for required metadata
if isnan(PUV.doffp)
    error('PUV_L2_spectral:noDoffp', ...
        'doffp is NaN for %s — fill from DeploymentNotes before running L2.', PUV.label);
end

fprintf('  Segmenting: %d samples → %d segments of %d (%.1f min each)\n', ...
    N, nSeg, segLen, segLen / fs / 60);

%% ======================== SHORE-NORMAL ROTATION ========================
if opts.doRotate && isfield(instr, 'mopStation') && ~isempty(instr.mopStation)
    try
        fprintf('  Fetching shore-normal angle for %s...\n', instr.mopStation);
        [U_sn, V_sn, shorenormal] = rotate_shorenormal( ...
            PUV.BuoyCoord.U, PUV.BuoyCoord.V, instr.mopStation);
        fprintf('  Shore-normal angle: %.1f deg\n', shorenormal);
    catch ME
        warning('PUV_L2_spectral:rotationFailed', ...
            'Shore-normal rotation failed: %s\n  Processing in buoy coords (+x WEST, +y NORTH).', ...
            ME.message);
        U_sn = PUV.BuoyCoord.U;
        V_sn = PUV.BuoyCoord.V;
        shorenormal = NaN;
    end
else
    U_sn = PUV.BuoyCoord.U;
    V_sn = PUV.BuoyCoord.V;
    shorenormal = NaN;
    if opts.doRotate
        warning('PUV_L2_spectral:noMopStation', ...
            'No mopStation defined — processing in buoy coords.');
    end
end

W = PUV.BuoyCoord.W;

%% ======================== PRE-ALLOCATE ========================
nfft     = opts.nfft;
noverlap = round(nfft * opts.overlap);

switch opts.spectralMethod
    case 'welch'
        win = hanning(nfft);
        [~, f] = pwelch(zeros(segLen, 1), win, noverlap, nfft, fs);
    case 'mtm_hybrid'
        % DPSS tapers used within Welch sub-segments (same nfft as welch)
        win = [];  % not used; psd_multitaper handles its own tapers
        [~, ~, f] = psd_multitaper(zeros(segLen, 1), [], nfft, fs, opts.NW);
    case 'mtm_full'
        % Full multi-taper on the entire segment (nfft = segLen)
        nfft = segLen;
        noverlap = 0;
        win = [];
        [~, ~, f] = psd_multitaper(zeros(nfft, 1), [], nfft, fs, opts.NW);
    otherwise
        error('PUV_L2_spectral:badMethod', ...
            'Unknown spectralMethod: %s. Use welch, mtm_hybrid, or mtm_full.', ...
            opts.spectralMethod);
end
nf = length(f);

% Spectra [nf x nSeg]
L2.S_eta = NaN(nf, nSeg);
L2.Spp   = NaN(nf, nSeg);
L2.Suu   = NaN(nf, nSeg);
L2.Svv   = NaN(nf, nSeg);
L2.Kp    = NaN(nf, nSeg);
L2.a1    = NaN(nf, nSeg);
L2.b1    = NaN(nf, nSeg);
L2.a2    = NaN(nf, nSeg);
L2.b2    = NaN(nf, nSeg);

% Scalars [nSeg x 1]
nanVec = NaN(nSeg, 1);
L2.time     = NaT(nSeg, 1);
L2.segValid = false(nSeg, 1);
L2.Hs       = nanVec;
L2.Hs_SS    = nanVec;
L2.Hs_IG    = nanVec;
L2.Tp       = nanVec;
L2.Tm02     = nanVec;
L2.meanDir  = nanVec;
L2.Ef       = nanVec;
L2.depth    = nanVec;
L2.fCut     = nanVec;
L2.uBed_rms = nanVec;
L2.vBed_rms = nanVec;
L2.Ub       = nanVec;
L2.tau_b    = nanVec;
L2.fric_w   = nanVec;
L2.Aw       = nanVec;
L2.uMean    = nanVec;
L2.vMean    = nanVec;
L2.wMean    = nanVec;
L2.Tmean    = nanVec;

% Reynolds stress sub-struct
L2.reynolds.uw    = nanVec;
L2.reynolds.vw    = nanVec;
L2.reynolds.uv    = nanVec;
L2.reynolds.TKE   = nanVec;
L2.reynolds.u_rms = nanVec;
L2.reynolds.v_rms = nanVec;
L2.reynolds.w_rms = nanVec;

% Velocity moments sub-struct
L2.vmom.skewness  = nanVec;
L2.vmom.asymmetry = nanVec;
L2.vmom.u_abs3    = nanVec;
L2.vmom.u_uabs2   = nanVec;
% Added 2026-04-09 for Paper_1 transport model (Bailard suspended moment +
% Drake-Calantoni a_spike). compute_velocity_moments already returns these.
L2.vmom.u_uabs3   = nanVec;
L2.vmom.a2        = nanVec;
L2.vmom.a3        = nanVec;

% Z-test: pressure vs velocity consistency (should be ~1.0)
L2.ztest_SS = nanVec;
L2.ztest_IG = nanVec;

% Radiation stress (integrated over SS band, Pa·m = N/m)
L2.Sxx = nanVec;
L2.Syy = nanVec;
L2.Sxy = nanVec;

%% ======================== SEGMENT LOOP ========================
tStart = tic;
nValid = 0;

for i = 1:nSeg
    idx = (i-1)*segLen + 1 : i*segLen;

    % Segment midpoint timestamp
    L2.time(i) = PUV.time(idx(segLen/2));

    % --- Extract raw segment ---
    pSeg = PUV.P(idx);
    uSeg = U_sn(idx);
    vSeg = V_sn(idx);
    wSeg = W(idx);
    tSeg = PUV.T(idx);

    % --- NaN check ---
    nanFrac = sum(isnan(pSeg) | isnan(uSeg) | isnan(vSeg)) / segLen;
    if nanFrac > opts.nanMaxFrac
        continue
    end

    L2.segValid(i) = true;
    nValid = nValid + 1;

    % --- Mean values BEFORE detrending ---
    pMean = mean(pSeg, 'omitnan');
    L2.uMean(i) = mean(uSeg, 'omitnan');
    L2.vMean(i) = mean(vSeg, 'omitnan');
    L2.wMean(i) = mean(wSeg, 'omitnan');
    L2.Tmean(i) = mean(tSeg, 'omitnan');

    % --- Depth from pressure ---
    % pMean is in dBar; 1 dBar = 1e4 Pa
    h_above = pMean * 1e4 / (opts.rho * opts.g);  % water above sensor (m)
    H = h_above + PUV.doffp;                       % total depth, bed to surface (m)
    L2.depth(i) = H;

    % --- Interpolate small NaN gaps ---
    pSeg = fillmissing(pSeg, 'linear');
    uSeg = fillmissing(uSeg, 'linear');
    vSeg = fillmissing(vSeg, 'linear');
    wSeg = fillmissing(wSeg, 'linear');

    % --- Convert pressure to meters of water ---
    pSeg_m = pSeg * 1e4 / (opts.rho * opts.g);

    % --- Detrend ---
    pSeg_m = detrend(pSeg_m);
    uSeg   = detrend(uSeg);
    vSeg   = detrend(vSeg);
    wSeg   = detrend(wSeg);

    % --- Power spectral density and cross-spectra ---
    switch opts.spectralMethod
        case 'welch'
            [Spp, ~] = pwelch(pSeg_m, win, noverlap, nfft, fs);
            [Suu, ~] = pwelch(uSeg,   win, noverlap, nfft, fs);
            [Svv, ~] = pwelch(vSeg,   win, noverlap, nfft, fs);
            [Spu, ~] = cpsd(pSeg_m, uSeg, win, noverlap, nfft, fs);
            [Spv, ~] = cpsd(pSeg_m, vSeg, win, noverlap, nfft, fs);
            [Suv, ~] = cpsd(uSeg,   vSeg, win, noverlap, nfft, fs);
        case {'mtm_hybrid', 'mtm_full'}
            [Spp, ~,   ~] = psd_multitaper(pSeg_m, [],   nfft, fs, opts.NW);
            [Suu, ~,   ~] = psd_multitaper(uSeg,   [],   nfft, fs, opts.NW);
            [Svv, ~,   ~] = psd_multitaper(vSeg,   [],   nfft, fs, opts.NW);
            [~,   Spu, ~] = psd_multitaper(pSeg_m, uSeg, nfft, fs, opts.NW);
            [~,   Spv, ~] = psd_multitaper(pSeg_m, vSeg, nfft, fs, opts.NW);
            [~,   Suv, ~] = psd_multitaper(uSeg,   vSeg, nfft, fs, opts.NW);
    end

    % --- Pressure correction (Wu method) ---
    [S_eta, Kp_seg, fCut] = pressure_correction_wu(Spp, f, H, PUV.doffp, opts.KpMin);

    % --- Store spectra ---
    L2.S_eta(:,i) = S_eta;
    L2.Spp(:,i)   = Spp;
    L2.Suu(:,i)   = Suu;
    L2.Svv(:,i)   = Svv;
    L2.Kp(:,i)    = Kp_seg;
    L2.fCut(i)    = fCut;

    % --- Directional coefficients ---
    % Kp cancels in the ratio, so use raw spectra
    Spp_uv = Suu + Svv;
    L2.a1(:,i) = real(Spu) ./ sqrt(Spp .* Spp_uv + eps);
    L2.b1(:,i) = real(Spv) ./ sqrt(Spp .* Spp_uv + eps);

    % Second-harmonic coefficients (from velocity spectra only)
    L2.a2(:,i) = (Suu - Svv) ./ (Spp_uv + eps);
    L2.b2(:,i) = 2 * real(Suv) ./ (Spp_uv + eps);

    % --- Bulk wave parameters ---
    bulk = compute_bulk_params(S_eta, Suu, Svv, Spu, Spv, f, H, opts);
    L2.Hs(i)      = bulk.Hs;
    L2.Hs_SS(i)   = bulk.Hs_SS;
    L2.Hs_IG(i)   = bulk.Hs_IG;
    L2.Tp(i)      = bulk.Tp;
    L2.Tm02(i)    = bulk.Tm02;
    L2.meanDir(i) = bulk.meanDir;
    L2.Ef(i)      = bulk.Ef;

    % --- Sanity check: unphysical Hs or depth ---
    % Two ways a segment can be contaminated by sensor noise:
    %   (1) Hs > HsMaxToHRatio * h: violates depth-limited breaking
    %       (γ_b ≈ 0.4–0.6 in shallow water).
    %   (2) Segment-mean depth far from depth_nominal: a segment whose
    %       pressure record includes a sensor-failure period will report
    %       an inflated mean pressure and therefore an inflated depth.
    %       For RUBY22/MOP579_6m, contaminated segments showed depth
    %       ~13 m at a 6 m site — both Hs AND depth scaled together so
    %       their ratio stayed plausible, but the absolute depth gives
    %       it away.
    bad_seg = false;
    if isfinite(bulk.Hs) && H > 0 && bulk.Hs > opts.HsMaxToHRatio * H
        bad_seg = true;
    end
    if isfield(instr,'depth_nominal') && ~isnan(instr.depth_nominal) ...
            && opts.depthDeviationMax > 0
        if abs(H - instr.depth_nominal) > opts.depthDeviationMax * instr.depth_nominal
            bad_seg = true;
        end
    end
    if bad_seg
        L2.segValid(i) = false;
        nValid = nValid - 1;
    end

    % --- Z-test: pressure vs velocity consistency ---
    % Convert velocity spectra to equivalent pressure units using linear
    % wave theory transfer function, then compare with measured Spp.
    % Z = Spp / (Suu_pres + Svv_pres). Values near 1.0 indicate
    % consistent P-U-V measurements; departures flag sensor issues.
    omega = 2*pi*f;
    k_seg = get_wavenumber(omega(2:end), H);
    vel2pres = zeros(nf, 1);
    f_nz = f(2:end);
    vel2pres(2:end) = (opts.g * k_seg(:)) ./ (2*pi*f_nz(:)) .* ...
        cosh(k_seg(:) * PUV.doffp) ./ cosh(k_seg(:) * H);
    Spp_from_vel = (Suu + Svv) .* vel2pres.^2;

    iSS = f >= opts.fSS(1) & f <= opts.fSS(2);
    iIG = f >= opts.fIG(1) & f <  opts.fIG(2);

    % Energy-weighted Z-test per band
    if sum(S_eta(iSS)) > 0
        L2.ztest_SS(i) = sum(Spp(iSS) .* S_eta(iSS)) / ...
                         sum(Spp_from_vel(iSS) .* S_eta(iSS) + eps);
    end
    if sum(S_eta(iIG)) > 0
        L2.ztest_IG(i) = sum(Spp(iIG) .* S_eta(iIG)) / ...
                         sum(Spp_from_vel(iIG) .* S_eta(iIG) + eps);
    end

    % --- Radiation stress (Herbers & Guza 1989, after Longuet-Higgins) ---
    % Sxx = rho*g * integral{ S_eta * [n*(1 + a2)/2 + n/2 - 1/2] df }
    % Simplified using n = cg/c:
    %   Sxx(f) = S_eta(f) * [(1.5 + 0.5*a2)*n - 0.5]
    %   Syy(f) = S_eta(f) * [(1.5 - 0.5*a2)*n - 0.5]
    %   Sxy(f) = S_eta(f) * [0.5*b2*n]
    n_ratio = zeros(nf, 1);
    cg_seg = get_cg(k_seg, H);
    c_seg  = omega(2:end) ./ k_seg(:);  % phase speed
    n_ratio(2:end) = cg_seg(:) ./ c_seg(:);  % cg / c
    a2_seg = L2.a2(:,i);
    b2_seg = L2.b2(:,i);

    Sxx_f = S_eta .* ((1.5 + 0.5*a2_seg) .* n_ratio - 0.5);
    Syy_f = S_eta .* ((1.5 - 0.5*a2_seg) .* n_ratio - 0.5);
    Sxy_f = S_eta .* (0.5 * b2_seg .* n_ratio);

    L2.Sxx(i) = opts.rho * opts.g * trapz(f(iSS), Sxx_f(iSS));
    L2.Syy(i) = opts.rho * opts.g * trapz(f(iSS), Syy_f(iSS));
    L2.Sxy(i) = opts.rho * opts.g * trapz(f(iSS), Sxy_f(iSS));

    % --- Near-bed velocity (IFFT method) ---
    [uBed, vBed] = bed_velocity_ifft(uSeg, vSeg, fs, H, PUV.doffp, opts.g);
    L2.uBed_rms(i) = rms(uBed);
    L2.vBed_rms(i) = rms(vBed);
    L2.Ub(i)       = sqrt(mean(uBed.^2 + vBed.^2));

    % --- Bed stress (Swart 1974) ---
    % D50 default is 0.25 mm — TODO: replace with real grain size data
    [L2.tau_b(i), L2.fric_w(i), L2.Aw(i)] = ...
        bed_stress(L2.Ub(i), bulk.Tp, opts.D50, opts.rho);

    % --- Reynolds stress ---
    stress = compute_reynolds_stress(uSeg, vSeg, wSeg);
    L2.reynolds.uw(i)    = stress.uw;
    L2.reynolds.vw(i)    = stress.vw;
    L2.reynolds.uv(i)    = stress.uv;
    L2.reynolds.TKE(i)   = stress.TKE;
    L2.reynolds.u_rms(i) = stress.u_rms;
    L2.reynolds.v_rms(i) = stress.v_rms;
    L2.reynolds.w_rms(i) = stress.w_rms;

    % --- Velocity moments (shore-normal component) ---
    vmom = compute_velocity_moments(uSeg, fs);
    L2.vmom.skewness(i)  = vmom.skewness;
    L2.vmom.asymmetry(i) = vmom.asymmetry;
    L2.vmom.u_abs3(i)    = vmom.u_abs3;
    L2.vmom.u_uabs2(i)   = vmom.u_uabs2;
    L2.vmom.u_uabs3(i)   = vmom.u_uabs3;   % Bailard suspended moment
    L2.vmom.a2(i)        = vmom.a2;        % Drake-Calantoni denominator
    L2.vmom.a3(i)        = vmom.a3;        % Drake-Calantoni numerator

    % --- Progress ---
    if mod(i, 500) == 0
        fprintf('  Segment %d/%d (%.0f%%)...\n', i, nSeg, 100*i/nSeg);
    end
end

elapsed = toc(tStart);
fprintf('  %d/%d segments valid, processed in %.1f min\n', nValid, nSeg, elapsed/60);

%% ======================== METADATA ========================
L2.label          = PUV.label;
L2.deploymentName = PUV.deploymentName;
L2.LATLON         = PUV.LATLON;
L2.doffp          = PUV.doffp;
L2.shorenormal    = shorenormal;
L2.fs             = fs;
L2.f              = f;
L2.params         = opts;

% Store MOP station for validation scripts
if isfield(instr, 'mopStation')
    L2.mopStation = instr.mopStation;
else
    L2.mopStation = '';
end

end
