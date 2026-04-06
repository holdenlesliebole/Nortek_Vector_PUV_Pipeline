function [uBed, vBed] = bed_velocity_ifft(segU, segV, fs, hValue, offset, g)
% BED_VELOCITY_IFFT  Near-bed velocity from sensor-level velocity via linear wave theory.
%
%   [uBed, vBed] = bed_velocity_ifft(segU, segV, fs, hValue, offset, g)
%
%   Scales each frequency bin of the velocity FFT by 1/cosh(k*z_sensor),
%   where z_sensor is the sensor height above bed (offset/doffp).
%   Under linear wave theory, horizontal velocity u(z) ~ cosh(kz)/sinh(kh),
%   so the ratio u_bed/u_sensor = 1/cosh(k*z_sensor). Since the bed is
%   below the sensor, the bed velocity is always <= sensor velocity.
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
%   HISTORY
%     Original code used cosh(kH)/cosh(k(H-z)) which is the ratio of
%     velocity at the SURFACE to velocity at the SENSOR — the wrong
%     direction. This amplified velocities (especially at high freq)
%     instead of reducing them to bed level. Fixed April 2026 to use
%     1/cosh(k*offset) which correctly scales sensor→bed.
%
%     The conjugate symmetry enforcement sets U_fft(N-k) = conj(U_fft(k+1))
%     after scaling. The 'symmetric' flag in ifft() handles any residual
%     imaginary components.

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
        % Scale from sensor height (z=offset above bed) to bed (z=0).
        % Under linear wave theory: u(z) ~ cosh(kz) / sinh(kh)
        % At sensor: u_sensor ~ cosh(k*offset)
        % At bed:    u_bed    ~ cosh(0) = 1
        % Ratio bed/sensor = 1 / cosh(k*offset)
        ratio = 1.0 / cosh(kVal * offset);
        U_fft(idxFft) = U_fft(idxFft) * ratio;
        V_fft(idxFft) = V_fft(idxFft) * ratio;
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
