function [Eb, nPair] = bound_energy_from_bispectrum(B, P, f, opts)
% BOUND_ENERGY_FROM_BISPECTRUM  Bound (phase-coupled) energy per sum-frequency bin.
%
%   [Eb, nPair] = bound_energy_from_bispectrum(B, P, f, opts)
%
%   For each sum frequency f3 on the one-sided grid, sums the per-pair
%   bound power over UNORDERED primary pairs (f1 <= f2, f1 + f2 = f3):
%
%       Eb(i3) = sum_{i1 <= i2, f1+f2=f3} [Re B(i1,i2)]^2 / (P(i1) P(i2))
%
%   For a phase-locked component a_b*cos(theta1 + theta2 + beta) this
%   recovers P_bound = (a_b^2/4)*cos^2(beta) per pair, exactly, in the same
%   variance-per-bin units as P (beta = 0 for shallow-water bound
%   harmonics, so the estimator recovers the full bound power there).
%
%   Bookkeeping (pinned by validation/test_bispectral_bound.m): the sum
%   runs over each unordered pair ONCE, diagonal (f1 = f2) included once.
%   Summing ordered pairs instead double-counts every off-diagonal pair
%   while counting the diagonal once -- do not do that.
%
%   INPUTS
%     B    - complex time-mean bispectrum [nf x nf], symmetric in (f1,f2)
%            (e.g. L4.bispectra.B_mean)
%     P    - power spectrum on the same grid [nf x 1], variance per bin,
%            averaged over the SAME segments as B
%     f    - one-sided frequency grid [nf x 1]; f(1) = 0, uniform spacing
%     opts - optional struct
%            .minP  skip pairs where P(i1) or P(i2) <= minP (default 0).
%                   Real spectra are positive everywhere; the floor exists
%                   for synthetic line spectra where empty bins give 0/0.
%            .minF1 skip pairs whose LOWER primary f(i1) < minF1 (Hz;
%                   default 0 = no restriction). Cells with an IG primary
%                   (f1 ~ 0.01-0.04 Hz, f2 ~ f3 - f1) are the group-bound-IG
%                   triads -- the same three waves as the classic difference
%                   interaction, biphase ~ pi -- in which the BOUND leg is
%                   the IG component, not f3. Counting them misbooks free
%                   sea energy as bound energy at f3. For a bound-harmonic
%                   fraction, set minF1 to the IG/swell boundary (0.04 Hz
%                   in this pipeline) so only sea-swell pairs are summed.
%
%   OUTPUTS
%     Eb    - [nf x 1] bound energy at each sum-frequency bin (m^2 per bin)
%     nPair - [nf x 1] number of pairs summed per bin
%
%   Estimator bias: for uncoupled (random-phase) components <B> only
%   averages toward zero, leaving a positive rectification floor of order
%   P(f3)/(2*M) per pair, with M the number of independent averages in
%   <B>. With the L4 accumulation (~1300 hrs x K sub-segments) this is
%   negligible; see test_bispectral_bound.m TEST 4 for the measured level.
%
%   Context: todo #56 -- the bispectral route to a quotable bound fraction
%   beta, after the impedance route (findings_hg91_impedance_2026-07-29.md)
%   proved detection-only.
% Author: Holden Leslie-Bole, 2026

if nargin < 4, opts = struct(); end
if ~isfield(opts, 'minP'),  opts.minP  = 0; end
if ~isfield(opts, 'minF1'), opts.minF1 = 0; end

f = f(:);
P = P(:);
nf = numel(f);

assert(abs(f(1)) < 1e-12, ...
    'bound_energy_from_bispectrum:grid', 'f(1) must be 0 (got %.3g).', f(1));
df = f(2) - f(1);
assert(max(abs(diff(f) - df)) < 1e-9 * df, ...
    'bound_energy_from_bispectrum:grid', 'f must be uniformly spaced.');
assert(isequal(size(B), [nf nf]), ...
    'bound_energy_from_bispectrum:size', 'B must be [%d x %d].', nf, nf);
assert(numel(P) == nf, ...
    'bound_energy_from_bispectrum:size', 'P must have %d elements.', nf);

Eb    = zeros(nf, 1);
nPair = zeros(nf, 1);

% f(i) = (i-1)*df, so f1 + f2 = f3  <=>  i1 + i2 = i3 + 1.
% i1 >= 2 excludes the DC bin (zeroed inside bispectrum.m anyway).
for i3 = 3:nf
    for i1 = 2:floor((i3 + 1) / 2)
        i2 = i3 + 1 - i1;                    % i2 >= i1 by the loop bound
        if f(i1) < opts.minF1, continue; end
        if P(i1) <= opts.minP || P(i2) <= opts.minP, continue; end
        Eb(i3)    = Eb(i3) + real(B(i1, i2))^2 / (P(i1) * P(i2));
        nPair(i3) = nPair(i3) + 1;
    end
end
end
