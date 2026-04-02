function [uBed, vBed] = bed_velocity_ifft(segU, segV, fs, hValue, offset, g)
% BED_VELOCITY_IFFT  Near-bed velocity from sensor-level velocity via linear wave theory.
%
%   [uBed, vBed] = bed_velocity_ifft(segU, segV, fs, hValue, offset, g)
%
%   Scales each frequency bin of the velocity FFT by the ratio of
%   cosh(k*h) / cosh(k*(h-z)), where z is the sensor height above bed.
%   This inverts the depth-attenuation of horizontal velocity under linear
%   wave theory to estimate the near-bed (z=0) orbital velocity.
%
%   INPUTS
%     segU    - (N x 1) measured shore-normal velocity at sensor height (m/s)
%     segV    - (N x 1) measured alongshore velocity at sensor height (m/s)
%     fs      - sampling frequency (Hz)
%     hValue  - mean water depth (m)
%     offset  - sensor height above bed (m), i.e. doffp
%     g       - gravitational acceleration (m/s^2)
%
%   OUTPUTS
%     uBed    - (N x 1) estimated near-bed shore-normal velocity (m/s)
%     vBed    - (N x 1) estimated near-bed alongshore velocity (m/s)
%
%   NOTES
%     - Assumes inviscid linear wave theory (no bottom friction or phase lag).
%     - Input segments should be detrended and NaN-free before calling.
%     - Requires get_wavenumber.m on the MATLAB path.
%
%   KNOWN ISSUE
%     The conjugate symmetry enforcement for the negative-frequency bins
%     sets U_fft(N-k) = conj(U_fft(k+1)) AFTER the positive-frequency bin
%     has been scaled. This is correct for k in 1..N/2-1, but the loop
%     structure means k > N/2 bins (which are the negative-frequency bins)
%     are visited again with f > fs/2, hit the 'continue' branch, and are
%     NOT re-scaled. Net result: positive-frequency bins are scaled correctly
%     and their conjugate partners are set correctly in the same iteration.
%     Verify with a synthetic sinusoid test if in doubt.

N = length(segU);

% Detrend to remove any residual mean/trend before spectral scaling
segU = detrend(segU);
segV = detrend(segV);

U_fft = fft(segU);
V_fft = fft(segV);

for k = 0:(N-1)
    f      = k * fs / N;
    idxFft = k + 1;

    % Skip DC and above-Nyquist bins — do not scale
    if f == 0 || f > fs/2
        continue
    end

    omega = 2 * pi * f;
    kVal  = get_wavenumber(omega, hValue);

    if ~isnan(kVal) && kVal > 0
        denomSensor = cosh(kVal * (hValue - offset));
        denomBed    = cosh(kVal * hValue);

        if denomSensor > 0 && denomBed > 0
            ratio = denomBed / denomSensor;
            U_fft(idxFft) = U_fft(idxFft) * ratio;
            V_fft(idxFft) = V_fft(idxFft) * ratio;
        end
    end

    % Enforce conjugate symmetry for the mirrored negative-frequency bin
    kNeg = N - k;
    if kNeg ~= k
        U_fft(kNeg) = conj(U_fft(idxFft));
        V_fft(kNeg) = conj(V_fft(idxFft));
    end
end

uBed = ifft(U_fft, 'symmetric');
vBed = ifft(V_fft, 'symmetric');

end
