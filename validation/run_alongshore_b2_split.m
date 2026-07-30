% RUN_ALONGSHORE_B2_SPLIT  Split the model's shore-frame b2 error between
% mean direction and directional spread.  (PUV_paper todo #22, final piece)
%
% Established (findings_alongshore_attribution_2026-07-29.md): FRAME is
% eliminated algebraically; the alongshore b0 = 0.470 deficit is in the
% model's shore-frame second directional moment b2 = r2*sin(2*theta2), not
% in energy (0.986). The stored th_puv/th_mop assume r2 = 1, so they blend
% the two channels. This sweep saves band-averaged (a2, b2) on BOTH sides
% per hour (additive fields in compare_derived_quantities, 2026-07-30) and
% splits them:
%
%     r2     = hypot(a2b, b2b)          spread magnitude (frame-free)
%     theta2 = atan2(b2b, a2b)/2        shore-frame mean direction
%
% Counterfactual models, per hour (band-level; approximates the n(f)
% weighting inside Sxy as separable from the moment swap):
%     DIRECTION-ONLY error: model keeps its direction, adopts PUV spread:
%         b2_cf = r2_puv*sin(2 th_mop)   => Sxy scale factor r2_puv/r2_mop
%     SPREAD-ONLY error: model keeps its spread, adopts PUV direction:
%         b2_cf = r2_mop*sin(2 th_puv)   => factor sin(2 th_puv)/sin(2 th_mop)
%
% Per-record through-origin b0 (the established estimator) is recomputed for
% the actual model and both counterfactuals. The channel whose counterfactual
% moves b0 to ~1 is the channel carrying the error.
%
% PRE-REGISTERED (doc 9, hypothesized with falsifier): mean direction
% dominates; measured sigma1 puts the spread channel at only ~4-12% of the
% deficit and in the right direction. Falsified if the spread-corrected
% counterfactual (b0_dironly) recovers most of the deficit.
%
% CLOSURE: the recomputed actual b0 must reproduce R.Sxy_b0 per record, and
% the n = 60 medians must match the catalog set (gross 0.716, net +0.033,
% b0 0.470, findings_exclusions_2026-07-29.md).
%
% Per-hour directional data are SAVED (not stripped) -- the re-run that
% doc 9 and fig02's retention note both asked for.
%
% Output: outputs/validation/alongshore_b2_split.mat.  THREDDS per record.
% Run from PUV_Pipeline/:  >> run validation/run_alongshore_b2_split
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0 = tic;

reg   = deployment_registry();
names = sort(keys(reg));
seen  = containers.Map('KeyType','char','ValueType','logical');

W = struct('rec', {}, 'station', {}, 'nHr', {}, ...
    'b0_actual', {}, 'b0_sxyb0', {}, 'b0_dironly', {}, 'b0_spronly', {}, ...
    'r2_ratio', {}, 'dth2_med', {}, 'th2_puv_med', {}, ...
    'excluded', {}, 'seg', {});

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        rec = [cfg.name '/' lab];
        S2 = load(fullfile(fl(k).folder, fl(k).name), 'L2');
        try
            R = compare_derived_quantities(S2.L2);
        catch ME
            fprintf('[fail] %s: %s\n', rec, ME.message); continue
        end
        if ~isempty(R.status), fprintf('[skip] %s: %s\n', rec, R.status); continue; end

        s = R.seg;
        g = isfinite(s.Sxy_puv) & isfinite(s.Sxy_mop) & ...
            isfinite(s.a2b_puv) & isfinite(s.b2b_puv) & ...
            isfinite(s.a2b_mop) & isfinite(s.b2b_mop);
        if sum(g) < 20, fprintf('[skip] %s: %d directional hours\n', rec, sum(g)); continue; end

        r2p  = hypot(s.a2b_puv(g), s.b2b_puv(g));
        r2m  = hypot(s.a2b_mop(g), s.b2b_mop(g));
        th2p = 0.5 * atan2(s.b2b_puv(g), s.a2b_puv(g));
        th2m = 0.5 * atan2(s.b2b_mop(g), s.a2b_mop(g));

        x = s.Sxy_puv(g);
        y = s.Sxy_mop(g);
        % counterfactual scale factors (guard near-zero denominators)
        fDir = r2p ./ max(r2m, eps);                    % direction-only error
        sd   = sin(2*th2m);
        fSpr = sin(2*th2p) ./ sd;                       % spread-only error
        fSpr(abs(sd) < 1e-3) = NaN;

        b0    = @(x,y) sum(x.*y, 'omitnan') / max(sum(x(isfinite(y)).^2), eps);
        w = struct('rec', rec, 'station', R.station, 'nHr', sum(g), ...
            'b0_actual',  b0(x, y), ...
            'b0_sxyb0',   R.Sxy_b0, ...
            'b0_dironly', b0(x, y .* fDir), ...
            'b0_spronly', b0(x, y .* fSpr), ...
            'r2_ratio',   median(r2m ./ r2p, 'omitnan'), ...
            'dth2_med',   rad2deg(median(th2m - th2p, 'omitnan')), ...
            'th2_puv_med', rad2deg(median(th2p, 'omitnan')), ...
            'excluded',   excluded_records(cfg.name, lab), ...
            'seg', []);
        % keep the per-hour directional record (doc 9's requested re-run)
        w.seg = struct('g', find(g), 'Sxy_puv', x, 'Sxy_mop', y, ...
            'r2_puv', r2p, 'r2_mop', r2m, 'th2_puv', th2p, 'th2_mop', th2m, ...
            'th_puv', s.th_puv(g), 'th_mop', s.th_mop(g), 'm0_puv', s.m0_puv(g));
        W(end+1) = w; %#ok<SAGROW>

        fprintf('%-22s n=%4d  b0=%7.3f (Sxy_b0 %7.3f)  dirONLY=%7.3f  sprONLY=%7.3f  r2m/r2p=%5.3f  dth2=%+6.2f deg%s\n', ...
            rec, w.nHr, w.b0_actual, w.b0_sxyb0, w.b0_dironly, w.b0_spronly, ...
            w.r2_ratio, w.dth2_med, tern(w.excluded, '  [EXCLUDED]', ''));
    end
end

%% ---- summary ------------------------------------------------------------
use = ~[W.excluded];
fprintf('\n================ ALONGSHORE B2 SPLIT (n = %d) ================\n', sum(use));
mb = @(f) median([W(use).(f)], 'omitnan');
fprintf('b0 actual     : median %.3f   (catalog closure target 0.470; per-record max |b0-Sxy_b0| = %.2e)\n', ...
    mb('b0_actual'), max(abs([W(use).b0_actual] - [W(use).b0_sxyb0])));
fprintf('b0 DIRECTION-only error (spread corrected): median %.3f\n', mb('b0_dironly'));
fprintf('b0 SPREAD-only error (direction corrected): median %.3f\n', mb('b0_spronly'));
fprintf('r2_mop/r2_puv : median %.3f   (spread channel, frame-free)\n', mb('r2_ratio'));
fprintf('dth2          : median %+.2f deg  (shore-frame mean-direction offset)\n', mb('dth2_med'));
fprintf(['\nreading: if b0_spronly ~ b0_actual and b0_dironly ~ 1, spread carries the\n' ...
         'error; if b0_dironly ~ b0_actual and b0_spronly ~ 1, direction carries it.\n']);

meta = struct('created', datetime('now'), 'elapsed_min', toc(t0)/60, ...
    'note', ['Direction-vs-spread split of the alongshore b2 error (todo #22). ' ...
    'Counterfactual scaling is band-level (n(f) weighting treated as separable). ' ...
    'Per-hour directional data retained in W.seg.']);
save(fullfile(root, 'validation', 'alongshore_b2_split.mat'), 'W', 'meta', '-v7.3');
fprintf('\nsaved outputs/validation/alongshore_b2_split.mat (%.1f min)\n', meta.elapsed_min);

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
