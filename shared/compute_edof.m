function v = compute_edof(w, M, N, overlap)
% COMPUTE_EDOF  Equivalent degrees of freedom for a Welch PSD estimate.
%
%   v = compute_edof(w, M, N, overlap)
%
%   Welch (1967) equivalent DOF accounting for overlap and window
%   autocorrelation. Used by bispectrum.m to set the b95 significance
%   threshold sqrt(6/edof).
%
%   INPUTS
%     w       - window vector (length M)
%     M       - FFT length (samples)
%     N       - total number of points in the timeseries
%     overlap - overlap percentage [0..100] used to step the FFT window
%
%   OUTPUT
%     v       - equivalent degrees of freedom in the PSD estimate
%
%   REFERENCES
%     Welch, P.D. (1967), IEEE Trans. Audio Electroacoust., 15(2).
%     Solomon, O.M. Jr. (1991), Sandia report SAND91-1533 UC-706.
%
%   PROVENANCE
%     Ported from Kévin Martins' fun_compute_edof.m (Sept 2020).
%     Ports to PUV_Pipeline/shared/ — Holden Leslie-Bole, 2026.

s = 0.0;

% Number of new points in each FFT
S = fix(M * (100 - overlap) / 100);
k = 1 + (N - M) / S;

for i = 1:k-1
    if (i * S < M - 1)
        s = s + (k - i) / k * compute_rho(w, M, i, overlap);
    end
end

v = 2.0 * k / (1.0 + 2.0 * s);
end


function r = compute_rho(w, M, k, overlap)
% Window autocorrelation function (Welch 1967, Solomon 1991).

S = fix(M * (100 - overlap) / 100);

Pw = sum(w .* w) / M;

r = 0.0;
for i = 1:M - k*S - 1
    r = r + w(i) * w(i + k*S);
end
r = sqrt(r / (M * Pw));
end
