function [Pxx, Pxy, f] = psd_multitaper(x, y, nfft, fs, NW)
% PSD_MULTITAPER  Multi-taper auto- and cross-spectral density estimates.
%
%   [Pxx, Pxy, f] = psd_multitaper(x, y, nfft, fs, NW)
%   [Pxx, [],  f] = psd_multitaper(x, [], nfft, fs, NW)
%
%   Computes one-sided PSD using discrete prolate spheroidal sequence (DPSS)
%   tapers (Thomson, 1982). If y is provided, also returns the cross-spectral
%   density. Both auto and cross spectra use the same tapers, preserving
%   spectral consistency for directional analysis.
%
%   INPUTS
%     x     - input signal [nfft x 1] or [N x 1] (if N > nfft, segments
%             are averaged with 50% overlap, i.e. multi-taper Welch)
%     y     - second signal for cross-spectrum, or [] for auto-only
%     nfft  - FFT length / taper length (samples)
%     fs    - sampling frequency (Hz)
%     NW    - time-bandwidth product (default 4; K = 2*NW-1 tapers used)
%
%   OUTPUTS
%     Pxx   - one-sided auto-PSD of x [nf x 1] (units²/Hz)
%     Pxy   - one-sided cross-PSD of x,y [nf x 1] (complex), or [] if y=[]
%     f     - frequency vector [nf x 1] (Hz)
%
%   The normalization matches MATLAB's pwelch convention: integrating Pxx
%   over frequency gives the variance of x.

if nargin < 5 || isempty(NW), NW = 4; end

% DPSS tapers
[E, V] = dpss(nfft, NW);
K = sum(V > 0.99);  % number of good tapers (eigenvalue > 0.99)
E = E(:, 1:K);
V = V(1:K);

% Each taper is normalized so sum(E(:,k).^2) = 1.
% For PSD normalization matching pwelch convention, we need the
% window energy U = sum(E(:,k).^2) = 1 for each taper.
% PSD = |X_k|^2 / (fs * U) = |X_k|^2 / fs, averaged over tapers.

% Frequency vector (one-sided)
nf = nfft/2 + 1;
f = (0:nf-1)' * fs / nfft;

N = length(x);
doCross = ~isempty(y);

% Segment the data with 50% overlap (multi-taper Welch)
noverlap = round(nfft / 2);
step = nfft - noverlap;
nSegs = max(1, floor((N - noverlap) / step));

Pxx_sum = zeros(nf, 1);
if doCross
    Pxy_sum = zeros(nf, 1);
end
nSegsUsed = 0;

for s = 1:nSegs
    i1 = (s-1)*step + 1;
    i2 = i1 + nfft - 1;
    if i2 > N, break; end
    nSegsUsed = nSegsUsed + 1;

    xSeg = x(i1:i2);
    if doCross, ySeg = y(i1:i2); end

    % Tapered FFTs: each column is one taper
    Xk = fft(xSeg(:) .* E, nfft);  % [nfft x K]
    Xk = Xk(1:nf, :);              % one-sided

    % Auto-spectrum: eigenvalue-weighted average over tapers
    % Each |Xk|^2 already has the taper energy built in (U=1),
    % so PSD_k = |Xk|^2 / fs. Average over tapers with eigenvalue weights.
    Pxx_seg = sum(abs(Xk).^2 .* V', 2) / sum(V);
    Pxx_sum = Pxx_sum + Pxx_seg;

    if doCross
        Yk = fft(ySeg(:) .* E, nfft);
        Yk = Yk(1:nf, :);
        Pxy_seg = sum(conj(Xk) .* Yk .* V', 2) / sum(V);
        Pxy_sum = Pxy_sum + Pxy_seg;
    end
end

% Average over segments, then normalize to PSD (units^2/Hz)
% Factor of 1/fs converts from per-bin to per-Hz.
% Factor of 2 for one-sided spectrum (except DC and Nyquist).
Pxx = Pxx_sum / nSegsUsed / fs;
Pxx(2:end-1) = Pxx(2:end-1) * 2;  % one-sided doubling

if doCross
    Pxy = Pxy_sum / nSegsUsed / fs;
    Pxy(2:end-1) = Pxy(2:end-1) * 2;
else
    Pxy = [];
end

end
