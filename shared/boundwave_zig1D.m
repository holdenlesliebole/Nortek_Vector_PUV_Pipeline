function [Z_IG, U_IG] = boundwave_zig1D(eta, depth, fs, opts)
% BOUNDWAVE_ZIG1D  Estimate 1D collinear forced (bound) IG timeseries.
%
%   Z_IG          = boundwave_zig1D(eta, depth, fs, opts)
%   [Z_IG, U_IG]  = boundwave_zig1D(eta, depth, fs, opts)
%
%   Returns the bound-wave IG surface-elevation timeseries Z_IG forced
%   by difference-frequency interactions of swell-band pairs in `eta`,
%   following the Hasselmann (1962) / Schaffer & Madsen (1995) second-
%   order weakly nonlinear theory as implemented in SWASH. For each
%   pair of positive swell frequencies (f1, f2) with f2 > f1 and
%   f3 = f2 - f1 in the IG band, the complex bound amplitude at f3 is
%
%       b(f3) = D(f1, f2, k1, k2, h) * a(f1) * conj(a(f2))
%
%   where D = T1 + T2 + T3*C uses the Hasselmann interaction kernel
%   (Schaffer & Madsen 1995, eq. 11). cos(theta1 - theta2) is taken
%   as -1 (1D collinear / SWASH boundary-condition convention; in
%   FFT-phase land this absorbs the difference-frequency sign flip).
%
%   When the second output is requested, the corresponding bound-wave
%   shore-normal velocity U_IG is also returned. In the shallow-water
%   limit (kh_3 << 1, which holds for IG at PUV depths), conservation
%   of mass gives u_bound(f3) = (omega_3 / (h * k_3)) * eta_bound(f3),
%   where omega_3 / k_3 is the swell-group velocity (positive = shore-
%   ward for shoreward swell). U_IG is therefore eta_bound * c_3 / h
%   accumulated per pair, with the same complex phase as Z_IG. Sign
%   convention: U_IG > 0 means onshore (matches the post-rotation
%   shore-normal frame used by L2 / L4_reflection).
%
%   The contribution from every swell pair sharing a given f3 is
%   summed coherently into a single complex Fourier bin, the result is
%   masked to the IG band, and the inverse FFT (with symmetric flag,
%   so the conjugate-symmetric negative frequencies are reconstructed)
%   gives a real bound-IG timeseries on the input sample grid.
%
%   INPUTS
%     eta    - (N x 1) input surface-elevation timeseries (m). The
%              caller must pre-convert from pressure to eta if needed.
%     depth  - scalar segment-mean depth (m).
%     fs     - sample rate (Hz).
%     opts   - optional struct
%              .bandSwell  [fLow fHigh] swell band edges (default [0.04 0.25])
%              .bandIG     [fLow fHigh] IG  band edges  (default [0.004 0.04])
%              .khmin      lower kh cutoff (default 0.265, ~f=0.04 at h=5m)
%              .khmax      upper kh cutoff (default 10)
%              .g          gravity (default 9.81)
%
%   OUTPUT
%     Z_IG   - (N x 1) bound-IG surface-elevation timeseries (m).
%
%   ALGORITHM NOTES
%     - The (f1, f2) pair sum is vectorized over only swell-band bins
%       (pre-masked by khmin/khmax), so cost is O(nSwell^2) rather than
%       O(N^2) (~580k pairs at fs=2 Hz, segLen=7200 vs 51M).
%     - Pair accumulation uses accumarray on the discrete f3 bin
%       index `round(f3/df)+1`. f3 bins outside the IG band are dropped.
%
%   REFERENCES
%     Hasselmann, K. (1962), J. Fluid Mech. 12, 481-500.
%     Schaffer, H.A. & Madsen, P.A. (1995), Coastal Eng. 26, 1-14.
%     Athina Lange's loop-based prior implementation (Level3_QC/
%     boundwave_zig1D.m in PUV_Processing-main).
% Author: Holden Leslie-Bole, 2026 (vendored + vectorized from Lange/SWASH).

if nargin < 4, opts = struct(); end
if ~isfield(opts, 'bandSwell'), opts.bandSwell = [0.04 0.25]; end
if ~isfield(opts, 'bandIG'),    opts.bandIG    = [0.004 0.04]; end
if ~isfield(opts, 'khmin'),     opts.khmin     = 0.265; end
if ~isfield(opts, 'khmax'),     opts.khmax     = 10;    end
if ~isfield(opts, 'g'),         opts.g         = 9.81;  end

eta = eta(:);
N   = numel(eta);
if N == 0 || isnan(depth) || depth <= 0
    Z_IG = zeros(N, 1);
    U_IG = zeros(N, 1);
    return
end
wantU = (nargout >= 2);

% MATLAB FFT frequency layout: [0, fs/N, ..., fs/2, -fs/2+fs/N, ..., -fs/N]
freq      = (0:N-1).' * fs / N;
freq(freq > fs/2) = freq(freq > fs/2) - fs;
freqAbs   = abs(freq);
df        = fs / N;

A     = fft(eta, N);
amp   = abs(A) / N;
amp(2:end-1) = 2 * amp(2:end-1);   % match Athina's one-sided normalization
phase = angle(A);

% Wavenumbers
omegaAbs = 2 * pi * freqAbs;
k        = zeros(N, 1);
nonDC    = omegaAbs > 0;
k(nonDC) = get_wavenumber(omegaAbs(nonDC), depth);
kh       = k * depth;

% Positive-frequency swell-band mask
swellMask = (kh > opts.khmin) & (kh < opts.khmax) ...
            & (freq > 0) & (freq >= opts.bandSwell(1)) & (freq <= opts.bandSwell(2));
swellIdx  = find(swellMask);
nS        = numel(swellIdx);

if nS < 2
    Z_IG = zeros(N, 1);
    if wantU, U_IG = zeros(N, 1); end
    return
end

% All upper-triangular swell pairs (i < j → f3 = freq(j) - freq(i) > 0)
[J, I] = meshgrid(1:nS, 1:nS);
pairMask = I < J;
ii = swellIdx(I(pairMask));
jj = swellIdx(J(pairMask));

f1 = freq(ii);  f2 = freq(jj);
A1 = amp(ii);   A2 = amp(jj);
p1 = phase(ii); p2 = phase(jj);
k1 = k(ii);     k2 = k(jj);

% Difference frequency
f3      = f2 - f1;
igPair  = f3 >= opts.bandIG(1) & f3 <= opts.bandIG(2);
if ~any(igPair)
    Z_IG = zeros(N, 1);
    if wantU, U_IG = zeros(N, 1); end
    return
end
f1=f1(igPair); f2=f2(igPair);
A1=A1(igPair); A2=A2(igPair);
p1=p1(igPair); p2=p2(igPair);
k1=k1(igPair); k2=k2(igPair);
f3=f3(igPair);

% Schaffer-Madsen 1D collinear convention: cos(theta1-theta2) = -1, flip omega2
omega1   = 2*pi*f1;
omega2s  = -2*pi*f2;          % signed for difference-frequency formulation
cosdt    = -1;
g        = opts.g;

k3 = real(sqrt(k1.^2 + k2.^2 + 2*k1.*k2*cosdt));

C  = (omega1 + omega2s) .* ((omega1.*omega2s).^2 / g^2 - k1.*k2*cosdt) ...
     - 0.5 * (omega1 .* k2.^2 ./ cosh(k2*depth).^2 ...
             + omega2s .* k1.^2 ./ cosh(k1*depth).^2);
T1 = -g .* k1 .* k2 .* cosdt ./ (2 .* omega1 .* omega2s);
T2 = (omega1.^2 + omega2s.^2 + omega1.*omega2s) / (2*g);
T3 = g .* (omega1 + omega2s) ...
     ./ ((g .* k3 .* tanh(k3*depth) - (omega1 + omega2s).^2) .* (omega1 .* omega2s));
D  = T1 + T2 + T3 .* C;

A3      = abs(D) .* A1 .* A2;
phase3  = p2 - p1 + pi;                 % SWASH bound-wave phase
contrib_eta = A3 .* exp(1i * phase3);

% Bound-wave velocity per pair (shallow-water mass-conservation):
%   u_bound(f3) = (c_3 / h) * eta_bound(f3)
% with c_3 = omega_3 / k_3 = swell-group velocity, positive = onshore
if wantU
    c3        = (2*pi*f3) ./ k3;        % phase speed of bound wave
    uFactor   = c3 ./ depth;            % real, positive (shoreward swell)
    contrib_u = contrib_eta .* uFactor;
end

% Accumulate complex contributions into discrete IG bins
binIdx = round(f3 / df) + 1;            % 1-based positive-frequency bin
eta_pos = accumarray(binIdx, contrib_eta, [N, 1], @sum, complex(0, 0));

% Match Athina's normalization (amp had a factor 2/N applied to one-sided
% bins; reconstructing the full FFT array uses N/2 to invert that)
eta_norm = eta_pos * (N / 2);

% Mask to IG band, then ifft with conjugate symmetry to produce a real
% timeseries reconstructed from positive frequencies only
nonIG = (freqAbs < opts.bandIG(1)) | (freqAbs > opts.bandIG(2));
eta_norm(nonIG) = 0;

Z_IG = real(ifft(eta_norm, 'symmetric'));

if wantU
    u_pos = accumarray(binIdx, contrib_u, [N, 1], @sum, complex(0, 0));
    u_norm = u_pos * (N / 2);
    u_norm(nonIG) = 0;
    U_IG = real(ifft(u_norm, 'symmetric'));
end
end
