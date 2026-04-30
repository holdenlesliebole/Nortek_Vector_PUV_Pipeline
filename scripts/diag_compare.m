% diag_compare.m - quick diagnostics on the matched arrays
% Author: Holden Leslie-Bole, 2026
cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

R = load('outputs/validation/Ruby2D/ruby2d_582_6m_compare.mat');
p = R.results.paired;

dT = p.Tp_o - p.Tp_a;
fprintf('Tp diff stats:\n');
fprintf('  N = %d\n', sum(~isnan(dT)));
fprintf('  median diff = %.3f s\n', median(dT, 'omitnan'));
fprintf('  IQR diff    = %.3f s\n', iqr(dT));
fprintf('  max  |diff| = %.3f s\n', max(abs(dT)));
fprintf('  mean diff   = %.3f s\n', mean(dT, 'omitnan'));
fprintf('  >10 s off   = %d segments\n', sum(abs(dT) > 10));
fprintf('  >50 s off   = %d segments\n', sum(abs(dT) > 50));

fprintf('\nTp range Legacy: %.2f - %.2f s\n', min(p.Tp_a), max(p.Tp_a));
fprintf('Tp range Ours  : %.2f - %.2f s\n', min(p.Tp_o), max(p.Tp_o));

% Outlier indices
outIdx = find(abs(dT) > 10);
fprintf('\nFirst 10 outliers (|dT|>10):\n');
fprintf('  k     time            Hs_a  Tp_a    Tp_o\n');
for kk = 1:min(10, numel(outIdx))
    k = outIdx(kk);
    fprintf('  %4d  %s  %.2f  %6.2f  %6.2f\n', k, ...
        string(p.time(k)), p.Hs_a(k), p.Tp_a(k), p.Tp_o(k));
end

% ---- Legacy rep spectrum NaN check ----
A = load('raw_cache/Ruby2D/legacy_bulk_582_6m.mat');
fprintf('\nLegacy rep spectrum NaNs:\n');
fprintf('  fm  : %d / %d\n', sum(isnan(A.rep.fm)),  numel(A.rep.fm));
fprintf('  SSE : %d / %d\n', sum(isnan(A.rep.SSE)), numel(A.rep.SSE));
fprintf('  fm range: %.4f - %.4f Hz\n', min(A.rep.fm), max(A.rep.fm));
fprintf('  fm step (median): %.6f Hz\n', median(diff(A.rep.fm), 'omitnan'));
ix = ~isnan(A.rep.SSE) & ~isnan(A.rep.fm);
fprintf('  Hs from SSE (NaN-masked, full range): %.3f m\n', ...
    4*sqrt(trapz(A.rep.fm(ix), A.rep.SSE(ix))));
isub = ix & A.rep.fm >= 0.04 & A.rep.fm <= 0.25;
fprintf('  Hs from SSE (NaN-masked, SS band)   : %.3f m\n', ...
    4*sqrt(trapz(A.rep.fm(isub), A.rep.SSE(isub))));
