function eta_band = bandpass_freq(eta, fs, fLow, fHigh)
% BANDPASS_FREQ  Sharp frequency-domain bandpass via FFT bin masking.
%
%   eta_band = bandpass_freq(eta, fs, fLow, fHigh)
%
%   Returns the inverse FFT of eta with bins outside [fLow, fHigh] zeroed.
%   Use to extract IG, swell, or sea-band timeseries from a continuous
%   surface elevation record. No window or taper is applied — output
%   inherits the segment endpoints of the input.
%
%   INPUTS
%     eta    - (N x M) timeseries; FFT applied along the first dimension
%     fs     - sampling frequency (Hz)
%     fLow   - lower band edge (Hz, inclusive)
%     fHigh  - upper band edge (Hz, inclusive)
%
%   OUTPUT
%     eta_band - (N x M) bandpassed timeseries
%
%   NOTES
%     Inputs with odd N are truncated to even length to keep the
%     two-sided frequency grid symmetric.
%
%   PROVENANCE
%     Generalised from Athina Lange's timeseries_ss_ig.m (SIO 2019),
%     which hard-coded [0.004 0.04 0.25] Hz bands.
% Author: Holden Leslie-Bole, 2026

if isvector(eta)
    eta = eta(:);
end

N = size(eta, 1);
if mod(N, 2) ~= 0
    eta = eta(1:N-1, :);
    N   = N - 1;
end

% Two-sided frequency grid matching MATLAB's fft layout
freq = [0:fs/N:fs/2, -fs/2 + fs/N:fs/N:-fs/N];

mask = (abs(freq) >= fLow) & (abs(freq) <= fHigh);

etaF = fft(eta, N);
etaF(~mask, :) = 0;

eta_band = real(ifft(etaF, N));
end
