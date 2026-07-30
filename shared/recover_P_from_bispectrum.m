function [P, resid] = recover_P_from_bispectrum(B, Bic, nf)
% RECOVER_P_FROM_BISPECTRUM  Exact P_mean from saved B_mean and Bic_mean.
%
%   [P, resid] = recover_P_from_bispectrum(B, Bic, nf)
%
% PUV_L4_bispectra saves B_mean and Bic_mean but not the P_mean used to
% normalize them. Since Bic = |B|/sqrt(P1 P2 P3) cell-by-cell, every in-grid
% cell (k = i+j-1 <= nf) gives the exact linear equation in log space
%
%     logP(i) + logP(j) + logP(k) = 2 log(|B(i,j)|/Bic(i,j)),
%
% and the sparse least-squares solution recovers the P_mean the L4 path
% actually used. Bin 1 (the merged near-DC bin) is a real unknown: only the
% exact DC line is zeroed before mg-merging, so merged bin 1 carries IG
% energy. For i = 1 the sum index k equals j, so that unknown appears twice
% in the equation -- sparse() accumulates duplicate (row,col) entries, which
% handles the coefficient automatically.
%
% Validation: reproducing the saved Bic_mean from the recovered P closes at
% machine precision on all 65 catalog records (LS resid ~1e-14); see
% validation/analyze_bispectral_beta.m, which flags any record whose closure
% exceeds 1e-6.
%
% INPUTS
%   B    - complex mean bispectrum [nf x nf] (e.g. L4.bispectra.B_mean)
%   Bic  - bicoherence computed from B and the unsaved P [nf x nf]
%   nf   - grid size
%
% OUTPUTS
%   P     - [nf x 1] recovered power spectrum, variance per merged bin.
%           NOTE the convention: bispectrum.m's one-sided P is NOT doubled,
%           so P = 0.5 * integral(S_eta) per bin.
%   resid - rms log-space LS residual (~1e-14 when B/Bic are consistent)
%
% Author: Holden Leslie-Bole, 2026

rows = []; cols = []; rhs = [];
nEq = 0;
for i = 1:nf
    for j = i:nf
        kk = i + j - 1;
        if kk > nf, break; end
        if ~isfinite(Bic(i,j)) || ~(Bic(i,j) > 0) || ~(abs(B(i,j)) > 0), continue; end
        nEq = nEq + 1;
        rows = [rows; nEq; nEq; nEq]; %#ok<AGROW>
        cols = [cols; i; j; kk]; %#ok<AGROW>
        rhs  = [rhs; 2 * log(abs(B(i,j)) / Bic(i,j))]; %#ok<AGROW>
    end
end
A = sparse(rows, cols, 1, nEq, nf);
x = A \ rhs;
resid = sqrt(mean((A * x - rhs).^2));
P = exp(x);
end
