% test_psd_normalization.m — verify multi-taper PSD matches pwelch normalization
% Author: Holden Leslie-Bole, 2026
cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

rng(42);
x = randn(2048, 1);
fs = 2;

[Pw, fw] = pwelch(x, hanning(256), 128, 256, fs);
[Pm, ~, fm] = psd_multitaper(x, [], 256, fs, 4);
[Pf, ~, ff] = psd_multitaper(x, [], 2048, fs, 4);

fprintf('Variance of x:        %.4f\n', var(x));
fprintf('Welch integral:       %.4f\n', trapz(fw, Pw));
fprintf('MTM hybrid integral:  %.4f\n', trapz(fm, Pm));
fprintf('MTM full integral:    %.4f\n', trapz(ff, Pf));

% Cross-spectrum test: should match cpsd
y = 0.5*x + 0.5*randn(2048, 1);
[~, Cw] = cpsd(x, y, hanning(256), 128, 256, fs);
[~, Cm, ~] = psd_multitaper(x, y, 256, fs, 4);

fprintf('\nCross-spectrum integral (real part):\n');
fprintf('  cpsd:       %.4f\n', trapz(fw, real(Cw)));
fprintf('  MTM hybrid: %.4f\n', trapz(fm, real(Cm)));
fprintf('  Covariance: %.4f\n', mean(x .* y));
