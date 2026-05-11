function L4eta = PUV_L4_eta(PUV, L2, opts)
% PUV_L4_eta  Pressure → surface elevation timeseries per L2 segment, in three bands.
%
%   L4eta = PUV_L4_eta(PUV, L2)
%   L4eta = PUV_L4_eta(PUV, L2, opts)
%
%   For each L2 segment, take the corresponding span of PUV.P (in dBar),
%   convert to meters of water (P/(rho*g) with the dBar→Pa factor 1e4),
%   compute the linear-wave-theory pressure transfer
%       Kp(f) = cosh(k*doffp) / cosh(k*H)
%   using the segment-mean depth from L2.depth, divide P_FFT by Kp(f), and
%   inverse-FFT to surface elevation eta. Then bandpass into IG, swell, and
%   total-band timeseries via bandpass_freq.
%
%   Bins where Kp drops below opts.KpMin are zeroed, matching the L2
%   spectrum cutoff behaviour. The cutoff frequency per segment is
%   recorded in L4eta.fCut.
%
%   INPUTS
%     PUV   - L1 struct with .P (Nx1 m), .doffp
%     L2    - L2 struct with .time, .depth, .segValid, .params.segLen,
%             .fs, .doffp, .params.KpMin
%     opts  - optional struct
%             .KpMin       (default = L2.params.KpMin or 0.1)
%             .nanMaxFrac  (default = L2.params.nanMaxFrac or 0.05)
%             .rho         (default = L2.params.rho or 1025 kg/m^3)
%             .g           (default = L2.params.g   or 9.81 m/s^2)
%             .bands struct with .total, .swell, .ig — each [fLow, fHigh] Hz
%
%   OUTPUT (struct L4eta)
%     L4eta.time      - (nSeg x 1) datetime, copied from L2.time
%     L4eta.fs        - sampling frequency (Hz)
%     L4eta.segLen    - segment length (samples)
%     L4eta.depth     - (nSeg x 1) per-segment H, copied from L2.depth
%     L4eta.eta_total - (segLen x nSeg) total-band eta (m)
%     L4eta.eta_swell - (segLen x nSeg) swell-band eta (m)
%     L4eta.eta_ig    - (segLen x nSeg) IG-band eta (m)
%     L4eta.bands     - struct of band edges used
%     L4eta.fCut      - (nSeg x 1) Kp cutoff frequency per segment (Hz)
%     L4eta.segValid  - (nSeg x 1) logical, copied from L2.segValid
%
%   REQUIRES
%     get_wavenumber.m, bandpass_freq.m on the MATLAB path.
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end

% --- Defaults ---
defaultBands.total = [0.004, 0.25];
defaultBands.swell = [0.04,  0.25];
defaultBands.ig    = [0.004, 0.04];
if ~isfield(opts, 'bands'),  opts.bands = defaultBands; end
opts = inheritFromL2(opts, L2, 'KpMin',      0.1);
opts = inheritFromL2(opts, L2, 'nanMaxFrac', 0.05);
opts = inheritFromL2(opts, L2, 'rho',        1025);
opts = inheritFromL2(opts, L2, 'g',          9.81);

fs     = L2.fs;
segLen = L2.params.segLen;
nSeg   = numel(L2.time);
doffp  = L2.doffp;

L4eta.time      = L2.time;
L4eta.fs        = fs;
L4eta.segLen    = segLen;
L4eta.depth     = L2.depth;
L4eta.bands     = opts.bands;
L4eta.eta_total = NaN(segLen, nSeg);
L4eta.eta_swell = NaN(segLen, nSeg);
L4eta.eta_ig    = NaN(segLen, nSeg);
L4eta.fCut      = NaN(nSeg, 1);
L4eta.segValid  = false(nSeg, 1);
if isfield(L2, 'segValid')
    L4eta.segValid = L2.segValid;
end

% MATLAB fft frequency layout for length-segLen transform
freq = (0:segLen-1)' * fs / segLen;
freq(freq > fs/2) = freq(freq > fs/2) - fs;

for i = 1:nSeg
    if ~L4eta.segValid(i) || isnan(L2.depth(i))
        continue
    end

    idx = (i-1)*segLen + 1 : i*segLen;
    if idx(end) > numel(PUV.P)
        continue
    end
    pSeg = PUV.P(idx);

    nanFrac = sum(isnan(pSeg)) / segLen;
    if nanFrac > opts.nanMaxFrac
        continue
    end
    pSeg = fillmissing(pSeg, 'linear');

    % dBar → meters of water
    pSeg = pSeg * 1e4 / (opts.rho * opts.g);

    H = L2.depth(i);

    pSeg = detrend(pSeg);
    pSeg = pSeg - mean(pSeg);

    % FFT and Kp on the timeseries grid
    Pf       = fft(pSeg);
    omegaAbs = 2 * pi * abs(freq);
    Kp       = ones(segLen, 1);

    nonDC = omegaAbs > 0;
    k = nan(segLen, 1);
    k(nonDC) = get_wavenumber(omegaAbs(nonDC), H);
    valid = nonDC & ~isnan(k) & k > 0;
    Kp(valid) = cosh(k(valid) * doffp) ./ cosh(k(valid) * H);

    % High-frequency cutoff: zero bins where Kp < KpMin (positive freq side
    % defines the cutoff that gets reported)
    belowCut = (Kp < opts.KpMin) & (freq > 0);
    if any(belowCut)
        L4eta.fCut(i) = min(freq(belowCut));
    else
        L4eta.fCut(i) = fs / 2;
    end
    cutMask          = (Kp < opts.KpMin);
    Kp(cutMask)      = Inf;

    % Eta FFT and inverse to full-spectrum eta
    EtaF = Pf ./ Kp;
    eta  = real(ifft(EtaF));

    % Bandpass into the three target bands
    L4eta.eta_total(:, i) = bandpass_freq(eta, fs, opts.bands.total(1), opts.bands.total(2));
    L4eta.eta_swell(:, i) = bandpass_freq(eta, fs, opts.bands.swell(1), opts.bands.swell(2));
    L4eta.eta_ig(:, i)    = bandpass_freq(eta, fs, opts.bands.ig(1),    opts.bands.ig(2));
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
