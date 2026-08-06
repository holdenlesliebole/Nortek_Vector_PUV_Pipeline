% TEST_BIC_NULL_OVERLAP  Monte Carlo null for bicoherence with the ACTUAL
% overlapping-subsegment estimator.  (2026-08-06 audit, P0 item 1.1e)
%
% L4 averages K = 6 fifty-percent-overlapping 2048-sample subsegments and
% sums their DOF as if independent, giving edof = 60 and the Haubrich
% threshold b95 = sqrt(6/60) = 0.316. Overlapping rectangular-window
% segments are NOT independent, so the true null 95th percentile of the
% amplitude bicoherence b = |B|/sqrt(P1 P2 P3) is higher. This test runs
% Gaussian noise hours through the exact production hour-path (bispectrum()
% per subsegment, complex-mean B, mean P, then b from the averages) and
% reports the empirical null 95th percentile, pooled over interior cells.
%
% Then it re-checks the manuscript claim "b(fp,fp) exceeds b95 in
% essentially every hour" against the corrected threshold, using the saved
% per-segment bic_swell_self across the catalog.
%
% Output: outputs/validation/bic_null_overlap.mat
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0 = tic;

M = 400;                    % synthetic hours
fs = 2; segLen = 7200; nfftSub = 2048; mg = 5; fOut = 0.3;
step = nfftSub/2; subStarts = 1:step:(segLen-nfftSub+1); K = numel(subStarts);
rng(806, 'twister');

probe = bispectrum(zeros(nfftSub,1), fs, mg, fOut);
nf = numel(probe.f); fG = probe.f(:);

% interior cells: primaries in the swell/sea band, sum on grid
[I1, I2] = meshgrid(1:nf, 1:nf);
K3 = I1 + I2 - 1;
cells = I1 >= 9 & I2 >= I1 & K3 <= nf & fG(I1) >= 0.04 & fG(min(K3,nf)) <= 0.25;

bAll = NaN(M, sum(cells(:)));
for m = 1:M
    x = randn(segLen, 1);
    Bs = zeros(nf,nf); Ps = zeros(nf,1);
    for j = 1:K
        bs = bispectrum(x(subStarts(j):subStarts(j)+nfftSub-1), fs, mg, fOut);
        Bs = Bs + bs.B; Ps = Ps + bs.P;
    end
    Bs = Bs/K; Ps = Ps/K;
    Bic = abs(Bs) ./ sqrt(Ps(I1) .* Ps(I2) .* Ps(min(K3,nf)));
    bAll(m,:) = Bic(cells).';
end

b95_eff = quantile(bAll(:), 0.95);
fprintf('\nnull b (amplitude): median %.3f, 95th pct %.3f, 99th %.3f  (Haubrich b95 = 0.316)\n', ...
    median(bAll(:)), b95_eff, quantile(bAll(:), 0.99));
edof_eff = 6 / b95_eff^2;
fprintf('implied effective DOF 6/b95^2 = %.1f  (claimed 60; independent-K would be %.0f)\n', ...
    edof_eff, 60);

% real-data recheck: fraction of hours with bic_swell_self above thresholds
reg = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');
bic = [];
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;
    fl = dir(fullfile(root, 'L4', cfg.name, '*_L4.mat'));
    for k = 1:numel(fl)
        try
            v = h5read(fullfile(fl(k).folder, fl(k).name), '/L4/bispectra/bic_swell_self');
            bic = [bic; v(isfinite(v))]; %#ok<AGROW>
        catch, end
    end
end
fprintf('catalog bic_swell_self: %d hours; > 0.316: %.1f%%;  > %.3f (corrected): %.1f%%\n', ...
    numel(bic), 100*mean(bic > 0.316), b95_eff, 100*mean(bic > b95_eff));

meta = struct('created', datetime('now'), 'M', M, 'b95_eff', b95_eff, ...
    'edof_eff', edof_eff, 'elapsed_min', toc(t0)/60);
save(fullfile(root, 'validation', 'bic_null_overlap.mat'), 'bAll', 'b95_eff', 'edof_eff', 'bic', 'meta');
fprintf('saved outputs/validation/bic_null_overlap.mat (%.1f min)\n', meta.elapsed_min);
