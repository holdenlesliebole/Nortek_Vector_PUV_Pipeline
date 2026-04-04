function L2 = PUV_L2_spectral(PUV, instr, opts)
% PUV_L2_SPECTRAL  Level-2 spectral analysis for one PUV instrument.
%
%   L2 = PUV_L2_spectral(PUV, instr, opts)
%
%   Segments the L1 QC'd timeseries into 17-minute (2048-sample @ 2 Hz)
%   windows and computes:
%     - Surface elevation spectrum (Wu pressure correction)
%     - Bulk wave parameters (Hs, Tp, mean direction, energy flux)
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
%               .segLen   - segment length in samples (default 2048)
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

%% ======================== DEFAULTS ========================
if nargin < 3, opts = struct(); end

if ~isfield(opts, 'segLen'),     opts.segLen     = 2048;         end
if ~isfield(opts, 'nfft'),       opts.nfft       = 256;          end
if ~isfield(opts, 'overlap'),    opts.overlap     = 0.5;          end
if ~isfield(opts, 'KpMin'),      opts.KpMin      = 0.1;          end
if ~isfield(opts, 'rho'),        opts.rho        = 1025;          end
if ~isfield(opts, 'g'),          opts.g          = 9.81;          end
if ~isfield(opts, 'D50'),        opts.D50        = 0.25e-3;       end  % TODO: replace with real grain size from Laser Particle Analyzer
if ~isfield(opts, 'fIG'),        opts.fIG        = [0.004, 0.04]; end
if ~isfield(opts, 'fSS'),        opts.fSS        = [0.04, 0.25];  end
if ~isfield(opts, 'doRotate'),   opts.doRotate   = true;          end
if ~isfield(opts, 'nanMaxFrac'), opts.nanMaxFrac = 0.10;          end

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
% Get frequency vector from a dummy pwelch call
nfft     = opts.nfft;
noverlap = round(nfft * opts.overlap);
win      = hanning(nfft);
[~, f]   = pwelch(zeros(segLen, 1), win, noverlap, nfft, fs);
nf       = length(f);

% Spectra [nf x nSeg]
L2.S_eta = NaN(nf, nSeg);
L2.Spp   = NaN(nf, nSeg);
L2.Suu   = NaN(nf, nSeg);
L2.Svv   = NaN(nf, nSeg);
L2.Kp    = NaN(nf, nSeg);
L2.a1    = NaN(nf, nSeg);
L2.b1    = NaN(nf, nSeg);

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

    % --- Power spectral density (Welch) ---
    [Spp, ~] = pwelch(pSeg_m, win, noverlap, nfft, fs);
    [Suu, ~] = pwelch(uSeg,   win, noverlap, nfft, fs);
    [Svv, ~] = pwelch(vSeg,   win, noverlap, nfft, fs);

    % --- Cross-spectra for directional analysis ---
    [Spu, ~] = cpsd(pSeg_m, uSeg, win, noverlap, nfft, fs);
    [Spv, ~] = cpsd(pSeg_m, vSeg, win, noverlap, nfft, fs);

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

    % --- Bulk wave parameters ---
    bulk = compute_bulk_params(S_eta, Suu, Svv, Spu, Spv, f, H, opts);
    L2.Hs(i)      = bulk.Hs;
    L2.Hs_SS(i)   = bulk.Hs_SS;
    L2.Hs_IG(i)   = bulk.Hs_IG;
    L2.Tp(i)      = bulk.Tp;
    L2.Tm02(i)    = bulk.Tm02;
    L2.meanDir(i) = bulk.meanDir;
    L2.Ef(i)      = bulk.Ef;

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

end
