function data = bispectrum(x, fs, mg, fOut)
% BISPECTRUM  FFT-direct power bispectrum, bicoherence, biphase, skewness, asymmetry.
%
%   data = bispectrum(x, fs, mg, fOut)
%
%   Computes the bispectrum B(f1,f2) = E[A(f1) A(f2) A*(f1+f2)] of a
%   single segment x using a rectangular window (no taper) so that the
%   bispectral skewness/asymmetry match statistical estimates from the
%   timeseries (Elgar & Guza 1985). Bicoherence uses the Haubrich (1965)
%   normalisation b = |B| / sqrt(P(f1) P(f2) P(f1+f2)).
%
%   INPUTS
%     x     - segment timeseries (column vector, length N)
%     fs    - sampling frequency (Hz)
%     mg    - frequency merge bandwidth in BINS (odd integer); pass []
%             for no merging. Merging averages adjacent bins to inflate
%             edof and improve bicoherence stability.
%     fOut  - upper frequency limit (Hz) for the returned bispectrum.
%             The full FFT is computed internally; outputs are trimmed
%             to the [0, fOut] x [0, fOut] quadrant. Default: fs/2.
%
%   OUTPUT (struct)
%     data.f         - one-sided frequency grid (Hz), length nf
%     data.df        - frequency resolution (Hz)
%     data.P         - power spectrum (m^2), length nf
%     data.B         - bispectrum (m^3), [nf x nf]
%     data.Bic       - bicoherence (Haubrich 1965), [nf x nf]
%     data.Bip       - biphase (rad), [nf x nf]
%     data.skewness  - bispectral skewness (Elgar & Guza 1985)
%     data.asymmetry - bispectral asymmetry (Elgar & Guza 1985)
%     data.edof      - equivalent degrees of freedom (Welch 1967)
%     data.b95       - 95%% significance level on zero bicoherence,
%                      sqrt(6/edof) (Haubrich 1965)
%     data.merge     - frequency-merge bandwidth in bins (0 if none)
%
%   REFERENCES
%     Hasselmann, K. et al. (1963), in Time Series Analysis, ed. Rosenblatt.
%     Haubrich, R.A. (1965), J. Geophys. Res., 70(6).
%     Elgar, S. & Guza, R.T. (1985), J. Fluid Mech., 161, 425-448.
%     Hinich, M.J. (1982), J. Time Series Anal., 3(3).
%
%   PROVENANCE
%     Ported from Kévin Martins' fun_compute_bispectrum_H1982_nowindow.m
%     (Sept 2020). Cleanup: removed unused nblock loop, exposed fOut,
%     replaced rectwin with ones(), wired compute_edof.
% Author: Holden Leslie-Bole, 2026

x = x(:);
lx = length(x);

if nargin < 3, mg = []; end
if nargin < 4 || isempty(fOut), fOut = fs / 2; end

% FFT length forced even so frequencies bracket zero
nfft = lx - rem(lx, 2);
if nfft ~= lx
    x = x(1:nfft);
end

if isempty(mg)
    merge = false;
else
    merge = true;
    mg    = mg - rem(mg + 1, 2);  % force odd
end

% Two-sided frequency grid centred on zero
freqs = (-nfft/2:nfft/2)' / nfft * fs;
nmid  = nfft/2 + 1;

% --- FFT (single block, rectangular window) ---
xseg = detrend(x);
xseg = xseg - mean(xseg);

A_loc = fft(xseg, nfft) / nfft;
A     = [A_loc(nmid:nfft); A_loc(1:nmid)];   % fftshift to centre on zero
A(nmid) = 0;                                 % zero the DC bin

% --- Bispectrum and PSD ---
[ifr1, ifr2] = meshgrid(1:nfft+1, 1:nfft+1);
ifr3   = nmid + (ifr1 - nmid) + (ifr2 - nmid);
inSum  = (ifr3 >= 1) & (ifr3 <= nfft+1);
ifr3(~inSum) = 1;

CA = conj(A);
B  = A(ifr1) .* A(ifr2) .* CA(ifr3);
B(~inSum) = 0;
P  = abs(A.^2);

% --- Bispectral skewness and asymmetry (Elgar & Guza 1985, eq. for one quadrant) ---
ifreq  = (nmid:nmid + nfft/2)';
sumtmp = 6 * B(nmid, nmid);                     % first diagonal term
for ff = 2:length(ifreq)
    indf   = ifreq(ff);
    sumtmp = sumtmp + 6  * B(indf, indf);
    sumtmp = sumtmp + 12 * sum(B(indf, nmid:indf-1));
end
varX      = mean((x - mean(x, 'omitnan')).^2, 'omitnan');
skewness  = real(sumtmp) / varX^(3/2);
asymmetry = imag(sumtmp) / varX^(3/2);

% --- Optional frequency merging (rectangular bandwidth average) ---
if merge
    mm   = (mg - 1) / 2;
    ifrm = [fliplr(nmid:-mg:1+mm), nmid+mg : mg : nfft+1-mm]';

    nm = length(ifrm);
    Bm = zeros(nm, nm);
    Pm = zeros(nm, 1);

    for j1 = 1:nm
        ifb1 = ifrm(j1);
        Pm(j1) = sum(P(ifb1-mm:ifb1+mm));
        for j2 = 1:nm
            ifb2 = ifrm(j2);
            Bm(j1, j2) = sum(sum(B(ifb1-mm:ifb1+mm, ifb2-mm:ifb2+mm)));
        end
    end

    fAll  = freqs(ifrm);
    nmid  = (nm - 1) / 2 + 1;
    [ifr1, ifr2] = meshgrid(1:nm, 1:nm);
    ifr3  = nmid + (ifr1 - nmid) + (ifr2 - nmid);
    inSum = (ifr3 >= 1) & (ifr3 <= nm);
    ifr3(~inSum) = 1;

    Bic = abs(Bm) ./ sqrt(Pm(ifr1) .* Pm(ifr2) .* Pm(ifr3));
    Bic(~inSum) = 0;
    Bip = atan2(imag(Bm), real(Bm));

    B    = Bm;
    P    = Pm;
else
    Bic  = abs(B) ./ sqrt(P(ifr1) .* P(ifr2) .* P(ifr3));
    Bic(~inSum) = 0;
    Bip  = atan2(imag(B), real(B));
    fAll = freqs;
    nmid = nfft/2 + 1;
end

% --- Equivalent degrees of freedom (rectangular window, single segment) ---
nfftFull = lx - rem(lx, 2);
edof = compute_edof(ones(nfftFull, 1), nfftFull, lx, 0);
if merge
    edof = edof * mg;   % Elgar (1987) edof inflation under bin-merging
end

% --- Trim to one-sided positive frequencies up to fOut ---
[~, iCut] = min(abs(fAll - fOut));
keep = nmid:iCut;

data.f         = fAll(keep);
data.df        = abs(fAll(2) - fAll(1));
data.P         = P(keep);
data.B         = B(keep, keep);
data.Bic       = Bic(keep, keep);
data.Bip       = Bip(keep, keep);
data.skewness  = skewness;
data.asymmetry = asymmetry;
data.edof      = edof;
data.b95       = sqrt(6 / edof);
if merge
    data.merge = mg;
else
    data.merge = 0;
end
end
