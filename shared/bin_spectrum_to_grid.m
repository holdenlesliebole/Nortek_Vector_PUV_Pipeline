% BIN_SPECTRUM_TO_GRID  Variance-conserving rebinning of a spectrum onto a
% coarser frequency grid defined by bin edges.
%
% function [S_binned, fbw_out, coverage] = bin_spectrum_to_grid(f_in, S_in, fbounds)
%
% Integrates spectral density over each target bin and divides by the bin
% width, so that the variance carried by the input spectrum within a bin is
% exactly preserved:
%
%     S_out(j) * (f_hi(j) - f_lo(j))  ==  integral_{f_lo(j)}^{f_hi(j)} S_in(f) df
%
% This is the correct direction for comparing a high-resolution in-situ
% spectrum against a coarse model spectrum. The reverse operation --
% interpolating the coarse spectrum UP onto the fine grid -- manufactures a
% broad, smooth peak whose width is set by the model's bin spacing rather
% than by physics, and simultaneously depresses int(S^2 df). Both effects
% bias spectral-shape metrics (half-power bandwidth, Goda Qp) in the
% direction of "the model peak is broader". Bin down, never interpolate up.
%
% INPUTS
%   f_in     - input frequency vector (Hz), monotonic increasing [nf x 1]
%   S_in     - input spectral density (m^2/Hz), [nf x 1] or [nf x nSeg].
%              Columns are treated as independent spectra.
%   fbounds  - target bin edges (Hz), either
%                [2 x nBins] as returned by read_MOPline2 (row 1 = lower
%                edge, row 2 = upper edge), or
%                [nBins+1 x 1] contiguous edge vector.
%
% OUTPUTS
%   S_binned - binned spectral density (m^2/Hz), [nBins x nSeg]
%   fbw_out  - width of each target bin (Hz), [nBins x 1]
%   coverage - fraction of each target bin actually spanned by the input
%              frequency range, [nBins x 1]. Bins with coverage < 1 are
%              only partially resolved by the input spectrum (e.g. model
%              bins extending past the PUV high-frequency cutoff); the
%              caller should decide whether to trust or mask them.
%              Bins with coverage == 0 return NaN.
%
% NOTES
%   - Integration is trapezoidal on the input grid, with linear
%     interpolation of S_in at the bin edges so that partial input
%     intervals at the edges are accounted for exactly. For a uniform fine
%     input grid this conserves variance to round-off.
%   - Model bin edges are generally NOT contiguous or uniform (CDIP MOP
%     bandwidths vary across the band), which is why edges are taken as
%     explicit intervals rather than derived from bin centres.
%   - NaNs in S_in propagate to any bin whose integration interval touches
%     them, rather than being silently skipped.
%
% Author: Holden Leslie-Bole, 2026

function [S_binned, fbw_out, coverage] = bin_spectrum_to_grid(f_in, S_in, fbounds)

f_in = double(f_in(:));
if isvector(S_in)
    S_in = double(S_in(:));
else
    S_in = double(S_in);
end

if size(S_in, 1) ~= numel(f_in)
    error('bin_spectrum_to_grid:sizeMismatch', ...
        'S_in must have size(S_in,1) == numel(f_in) (got %d vs %d).', ...
        size(S_in, 1), numel(f_in));
end
if any(diff(f_in) <= 0)
    error('bin_spectrum_to_grid:notMonotonic', ...
        'f_in must be monotonically increasing.');
end

% --- Normalize bin edges to [nBins x 2] --------------------------------
fbounds = double(fbounds);
if isvector(fbounds)
    edges = fbounds(:);
    if numel(edges) < 2
        error('bin_spectrum_to_grid:badBounds', ...
            'Edge vector must contain at least 2 entries.');
    end
    fLo = edges(1:end-1);
    fHi = edges(2:end);
elseif size(fbounds, 1) == 2
    fLo = fbounds(1, :).';
    fHi = fbounds(2, :).';
elseif size(fbounds, 2) == 2
    fLo = fbounds(:, 1);
    fHi = fbounds(:, 2);
else
    error('bin_spectrum_to_grid:badBounds', ...
        'fbounds must be [2 x nBins], [nBins x 2], or an edge vector.');
end

if any(fHi <= fLo)
    error('bin_spectrum_to_grid:badBounds', ...
        'Every bin must have upper edge > lower edge.');
end

nBins = numel(fLo);
nSeg  = size(S_in, 2);

fbw_out  = fHi - fLo;
coverage = zeros(nBins, 1);
S_binned = NaN(nBins, nSeg);

fMin = f_in(1);
fMax = f_in(end);

for j = 1:nBins

    % Clip the target bin to the span the input spectrum actually covers
    lo = max(fLo(j), fMin);
    hi = min(fHi(j), fMax);

    if hi <= lo
        coverage(j) = 0;
        continue    % leaves NaN
    end
    coverage(j) = (hi - lo) / fbw_out(j);

    % Input samples strictly inside (lo, hi), plus interpolated endpoints.
    % Building the integration abscissa explicitly keeps partial intervals
    % at the bin edges exact instead of snapping to the nearest sample.
    inner = f_in > lo & f_in < hi;
    fq = [lo; f_in(inner); hi];

    Sq = [interp1(f_in, S_in, lo, 'linear'); ...
          S_in(inner, :); ...
          interp1(f_in, S_in, hi, 'linear')];

    if nSeg == 1
        Sq = Sq(:);
    end

    % Variance in the bin, then back to a density over the FULL bin width.
    % Dividing by fbw_out (not by hi-lo) means a partially covered bin
    % reports the density implied by the energy actually observed, which is
    % what a caller comparing against a model bin wants.
    m0_bin = trapz(fq, Sq, 1);
    S_binned(j, :) = m0_bin ./ fbw_out(j);
end
