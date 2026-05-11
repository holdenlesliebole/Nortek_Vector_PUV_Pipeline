function [mem, x, y] = mem_est(a1, a2, b1, b2)
% MEM_EST  Maximum-entropy directional spectrum from cross-spectral moments.
%
%   [mem, x, y] = mem_est(a1, a2, b1, b2)
%
%   Builds a 360-direction maximum-entropy directional response from the
%   first four Longuet-Higgins (1975) directional Fourier coefficients.
%   One row of (a1,a2,b1,b2) yields one directional distribution; vector
%   inputs (one row per frequency bin) yield a (Nfreq x 360) matrix.
%
%   INPUTS
%     a1, a2, b1, b2  - directional Fourier coefficients per frequency bin
%                       (column vectors of length Nfreq)
%
%   OUTPUTS
%     mem  - (Nfreq x 360) MEM directional spectrum, normalised so each
%            row integrates to 1 across direction (1-deg bins)
%     x, y - intermediate denominator/numerator (kept for inspection)
%
%   PROVENANCE
%     Original "Bill's code" (Bill O'Reilly), used by Athina Lange in the
%     prior PUV_Processing repo. Vendored without algorithmic change.
% Author: Holden Leslie-Bole, 2026 (port only)

d1 = a1; d2 = b1; d3 = a2; d4 = b2;

c1 = complex(1., 0) .* d1 + complex(0, 1.) .* d2;
c2 = complex(1., 0) .* d3 + complex(0, 1.) .* d4;

p1 = (c1 - c2 .* conj(c1)) ./ (1 - abs(c1).^2);
p2 = c2 - c1 .* p1;

x = 1. - p1 .* conj(c1) - p2 .* conj(c2);

% 1-degree directional resolution
a = (1:360) * pi / 180;
e1 = complex(1., 0) * cos(a)   - complex(0, 1.) * sin(a);
e2 = complex(1., 0) * cos(2*a) - complex(0, 1.) * sin(2*a);
y = abs(complex(1., 0) - p1 * e1 - p2 * e2).^2;

mem = abs((x * ones(1, 360)) ./ y);

% Normalise so each row sums to 1
mem = ((1 ./ sum(mem, 2)) * ones(1, 360)) .* mem;

% Direction indices reverse after the matrix calc; flip back to native
mem = fliplr(mem);
end
