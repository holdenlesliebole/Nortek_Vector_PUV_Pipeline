% RUN_SKEWNESS_ENERGY_FREQ  Bill's MOP511 frequency-resolved skewness
% correlation, catalog-wide.  (Wave_model_validation_paper todo #66)
%
% Source idea: W. O'Reilly memo "SIO MOP 511 6m PUV Measurements"
% (Paper_1/feedback/), Figs 6-9: the correlation of hourly u-velocity
% skewness with pressure energy density AS A FUNCTION OF FREQUENCY, at one
% site. He found peaks at ~0.082 Hz (short swell) and ~0.005 Hz (IG), and an
% r^2 ceiling of ~0.42 for any energy-only predictor of skewness.
%
% This sweep runs the same curve on all catalog records using the SURFACE
% spectrum (L2.S_eta -- the memo used raw pressure spectra; S_eta avoids the
% Kp tail suppression documented in CLAUDE.md) and hourly u skewness
% (L2.vmom.skewness). Spearman rank correlation, so the sqrt-vs-linear
% predictor choice in the memo's Figs 8-9 is immaterial here.
%
% The catalog question a single site cannot answer: is the predictive
% frequency FIXED near 0.08 Hz (a SoCal climate artifact), or does it track
% each record's primary peak (as the bound-harmonic mechanism predicts,
% since the coupling amplitude scales with the primary's energy)? Saved per
% record: r(f), the peak-r frequency, and the record's median fp for the
% ratio f_peak-r / fp.
%
% Doc 8 (findings_skewness_proxy_2026-07-29.md) is the companion result:
% energy-only predictors cap because phase coupling is a second, separable
% dimension of skewness. This sweep locates WHERE in frequency the energy
% information lives; doc 8 says what it necessarily misses.
%
% Cost: L2 loads only, no THREDDS. ~15-25 min for the catalog.
% Output: outputs/validation/skewness_energy_freq.mat
% Run from PUV_Pipeline/:  >> run validation/run_skewness_energy_freq
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0 = tic;

FMAX  = 0.35;         % Hz; correlations above this are noise-dominated
SMOOTH_HZ = 0.012;    % memo Fig 7's frequency smoothing window for S(f)

REC = struct('rec', {}, 'nHr', {}, 'fpk', {}, 'rpk', {}, ...
    'fp_med', {}, 'ratio', {}, 'r_at_fp', {}, 'r_at_2fp', {}, ...
    'rIG', {}, 'excluded', {});
Rf = [];   % [nf x nRec] correlation curves
fGrid = [];

reg   = deployment_registry();
names = sort(keys(reg));
seen  = containers.Map('KeyType','char','ValueType','logical');

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;
    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        rec = [cfg.name '/' lab];
        S2 = load(fullfile(fl(k).folder, fl(k).name), 'L2'); L2 = S2.L2;

        sk = L2.vmom.skewness(:);
        g  = logical(L2.segValid(:)) & isfinite(sk);
        if sum(g) < 100
            fprintf('[skip] %s: %d usable hours\n', rec, sum(g)); continue;
        end

        f  = L2.f(:);
        iF = f > 0 & f <= FMAX;
        if isempty(fGrid), fGrid = f(iF); end

        S  = double(L2.S_eta(iF, g)).';          % [nHr x nf]
        % light frequency smoothing, as in the memo's Fig 7
        w  = max(1, round(SMOOTH_HZ / (f(2)-f(1))));
        S  = movmean(S, w, 2);

        r  = corr(S, sk(g), 'type', 'Spearman', 'rows', 'pairwise');

        % peak of the sea-swell part of the curve (exclude IG for the peak)
        fSS = fGrid >= 0.04;
        [rpk, ip] = max(r(fSS));
        fss = fGrid(fSS); fpk = fss(ip);

        % record's median peak frequency (argmax of S_eta per hour, SS band)
        [~, ipk] = max(L2.S_eta(iF & f >= 0.04, g), [], 1);
        fs2 = f(iF & f >= 0.04);
        fpMed = median(fs2(ipk), 'omitnan');

        r_fp  = interp1(fGrid, r, fpMed, 'linear', NaN);
        r_2fp = interp1(fGrid, r, min(2*fpMed, FMAX), 'linear', NaN);
        rIG   = max(r(fGrid < 0.04));

        REC(end+1) = struct('rec', rec, 'nHr', sum(g), 'fpk', fpk, ...
            'rpk', rpk, 'fp_med', fpMed, 'ratio', fpk/fpMed, ...
            'r_at_fp', r_fp, 'r_at_2fp', r_2fp, 'rIG', rIG, ...
            'excluded', excluded_records(cfg.name, lab)); %#ok<SAGROW>
        Rf(:, end+1) = r(:); %#ok<SAGROW>

        fprintf('%-22s n=%5d  peak r=%5.2f at %.3f Hz  (fp %.3f, ratio %.2f)  r@fp=%5.2f r@2fp=%5.2f rIG=%5.2f\n', ...
            rec, sum(g), rpk, fpk, fpMed, fpk/fpMed, r_fp, r_2fp, rIG);
    end
end

use = ~[REC.excluded];
fprintf('\n=========== SKEWNESS-ENERGY-FREQUENCY (n = %d) ===========\n', sum(use));
fprintf('peak-r frequency: median %.3f Hz  IQR [%.3f %.3f]  (memo, MOP511: 0.082)\n', ...
    median([REC(use).fpk]), quantile([REC(use).fpk],0.25), quantile([REC(use).fpk],0.75));
fprintf('peak-r / fp     : median %.2f  IQR [%.2f %.2f]  (1 = primary tracks, 2 = harmonic)\n', ...
    median([REC(use).ratio]), quantile([REC(use).ratio],0.25), quantile([REC(use).ratio],0.75));
fprintf('peak r          : median %.2f;  r at fp: %.2f;  r at 2fp: %.2f;  IG-band max r: %.2f\n', ...
    median([REC(use).rpk]), median([REC(use).r_at_fp]), ...
    median([REC(use).r_at_2fp]), median([REC(use).rIG]));

meta = struct('created', datetime('now'), 'fmax', FMAX, 'smooth_hz', SMOOTH_HZ, ...
    'elapsed_min', toc(t0)/60, 'note', ...
    'Catalog-wide version of the O''Reilly MOP511 memo Figs 6-7: Spearman r(u-skewness, S_eta(f)) vs f.');
save(fullfile(root, 'validation', 'skewness_energy_freq.mat'), 'REC', 'Rf', 'fGrid', 'meta');
fprintf('saved outputs/validation/skewness_energy_freq.mat (%.1f min)\n', meta.elapsed_min);
