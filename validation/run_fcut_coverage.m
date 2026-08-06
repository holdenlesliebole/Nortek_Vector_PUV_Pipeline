% RUN_FCUT_COVERAGE  How much of the 0.12-0.20 Hz harmonic band is actually
% observable through the pressure inversion?  (2026-08-06 audit, item 2.2)
%
% The linear pressure correction zeros frequencies above the hour-specific
% fCut (where Kp < KpMin), and the paper's mechanism lives in the most
% pressure-attenuated part of the spectrum. This sweep reports, per record
% and catalog-wide: the fCut distribution over valid hours, the fraction of
% hours with FULL harmonic-band coverage (fCut >= 0.20 Hz), and coverage at
% a conservative common ceiling (>= 0.25 Hz).
%
% Output: outputs/validation/fcut_coverage.mat
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

REC = struct('rec', {}, 'h_med', {}, 'nValid', {}, 'fcut_med', {}, ...
    'fcut_p10', {}, 'frac_full020', {}, 'frac_025', {}, 'excluded', {});

reg = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');
allF = []; allH = [];
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;
    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        f2 = fullfile(fl(k).folder, fl(k).name);
        try
            fc = h5read(f2, '/L2/fCut'); fc = fc(:);
            sv = logical(h5read(f2, '/L2/segValid'));
            hh = h5read(f2, '/L2/depth'); hh = hh(:);
        catch
            S = load(f2, 'L2'); fc = S.L2.fCut(:); sv = logical(S.L2.segValid); hh = S.L2.depth(:);
        end
        fc = fc(sv); hv = hh(sv);
        REC(end+1) = struct('rec', [cfg.name '/' lab], ...
            'h_med', median(hv, 'omitnan'), 'nValid', numel(fc), ...
            'fcut_med', median(fc, 'omitnan'), 'fcut_p10', quantile(fc, 0.10), ...
            'frac_full020', mean(fc >= 0.20), 'frac_025', mean(fc >= 0.25), ...
            'excluded', excluded_records(cfg.name, lab)); %#ok<SAGROW>
        allF = [allF; fc]; allH = [allH; hv]; %#ok<AGROW>
        fprintf('%-22s h=%5.1f  fCut med %.3f p10 %.3f  full-band %5.1f%%  >=0.25 %5.1f%%\n', ...
            REC(end).rec, REC(end).h_med, REC(end).fcut_med, REC(end).fcut_p10, ...
            100*REC(end).frac_full020, 100*REC(end).frac_025);
    end
end

use = ~[REC.excluded];
fprintf('\n=========== FCUT COVERAGE (n = %d records) ===========\n', sum(use));
fprintf('per-record median fCut: catalog median %.3f Hz, min %.3f\n', ...
    median([REC(use).fcut_med]), min([REC(use).fcut_med]));
fprintf('fraction of hours with FULL harmonic band (fCut >= 0.20): catalog %5.1f%%; worst record %5.1f%%\n', ...
    100*mean(allF >= 0.20), 100*min([REC(use).frac_full020]));
byH = [15 12 10 8 6 0];
for i = 1:numel(byH)-1
    m = allH <= byH(i) & allH > byH(i+1);
    if any(m), fprintf('  depth %2d-%2d m: %6d hrs, full-band %5.1f%%\n', ...
        byH(i+1), byH(i), sum(m), 100*mean(allF(m) >= 0.20)); end
end

meta = struct('created', datetime('now'), 'note', 'fCut coverage of the 0.12-0.20 Hz band (audit 2.2).');
save(fullfile(root, 'validation', 'fcut_coverage.mat'), 'REC', 'meta');
fprintf('saved outputs/validation/fcut_coverage.mat\n');
