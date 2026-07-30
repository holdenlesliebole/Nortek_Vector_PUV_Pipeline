% RUN_BETA_EXCESS_CLOSURE  Does the model's harmonic-band deficit equal the
% measured bound fraction?  (todo #60 -- the closure between the paper's
% mechanism spine and the bispectral beta.)
%
% PRE-REGISTERED EXPECTATION (written before the numbers were seen).
% MOP is a linear spectral model: it carries no bound harmonics. If the
% observed harmonic band holds free energy E_free (which the model should
% reproduce) plus bound energy E_bound = beta * E_obs, then
%
%     R_harm := E_puv/E_mop (0.12-0.20 Hz)  ~  1/(1-beta)
%     y := R_harm - 1  ~  x := beta/(1-beta),   through-origin slope ~ 1.
%
% Pre-registered confounds and their signatures:
%   (i)  the model's generic energy error (+-5-7%, U-shaped in Hs/h) adds
%        record-level scatter to y. The low band 0.04-0.12 Hz carries ~no
%        bound energy, so R_low measures that error per record and
%        y_corr := R_harm/R_low - 1 removes it. Both fits are reported.
%   (ii) beta is a LOWER bound where the biphase has rotated (5 m records,
%        biphase_ss < ~-0.5): those records should sit ABOVE the 1:1 line.
%   (iii) sanity: median R_harm should echo the known harmonic excess
%        (pooled ratios 1.114 below Hs/h = 0.12, 1.332 above). A median
%        R_harm < 1 would mean a units or band error, not physics.
%
% Uses compare_shape_matched's Eharm_ratio/Elow_ratio (added 2026-07-30,
% additive fields only). Writes its own output file; the spine file
% cross_deployment_matched_shape.mat is NOT touched. THREDDS access per
% record; ~15-20 min for the catalog.
%
% Output: outputs/validation/beta_excess_closure.mat
% Run from PUV_Pipeline/:  >> run validation/run_beta_excess_closure
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0 = tic;

BB  = load(fullfile(root, 'validation', 'bispectral_beta.mat'));
RB  = BB.R;
bOK = [RB.closure_ok] & ~[RB.excluded];
recB = {RB.rec};

reg   = deployment_registry();
names = sort(keys(reg));
seen  = containers.Map('KeyType','char','ValueType','logical');

C = struct('rec', {}, 'h_median', {}, 'nMatched', {}, 'nBinsHarm', {}, ...
    'Eharm_ratio', {}, 'Elow_ratio', {}, 'm0_ratio', {}, ...
    'beta', {}, 'beta_hi', {}, 'biphase_ss', {}, 'ur', {}, 'hsh', {});

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        rec = [cfg.name '/' lab];
        iB  = find(strcmp(recB, rec), 1);
        if isempty(iB) || ~bOK(iB), continue; end   % no beta, or excluded

        try
            Rm = compare_shape_matched(fullfile(fl(k).folder, fl(k).name), ...
                struct('legacy', false, 'verbose', false));
        catch ME
            fprintf('[fail] %s: %s\n', rec, ME.message);
            continue
        end
        if ~isempty(Rm.status)
            fprintf('[skip] %s: %s\n', rec, Rm.status);
            continue
        end
        if ~isfinite(Rm.Eharm_ratio) || Rm.nBinsHarm < 2
            fprintf('[skip] %s: no usable harmonic band (%d bins)\n', rec, Rm.nBinsHarm);
            continue
        end

        c = struct('rec', rec, 'h_median', Rm.h_median, ...
            'nMatched', Rm.nMatched, 'nBinsHarm', Rm.nBinsHarm, ...
            'Eharm_ratio', Rm.Eharm_ratio, 'Elow_ratio', Rm.Elow_ratio, ...
            'm0_ratio', Rm.m0_ratio, ...
            'beta', RB(iB).beta_ss_net, ...
            'beta_hi', RB(iB).beta_ss + RB(iB).noise_ss, ...
            'biphase_ss', RB(iB).biphase_ss, ...
            'ur', RB(iB).ur, 'hsh', RB(iB).hsh);
        C(end+1) = c; %#ok<SAGROW>
        fprintf('%-22s h=%5.1f  Rharm=%6.3f  Rlow=%6.3f  beta=%6.3f  biph=%+6.3f\n', ...
            rec, c.h_median, c.Eharm_ratio, c.Elow_ratio, c.beta, c.biphase_ss);
    end
end

%% ---- regression --------------------------------------------------------
n  = numel(C);
x  = [C.beta] ./ (1 - [C.beta]);
y  = [C.Eharm_ratio] - 1;
y2 = [C.Eharm_ratio] ./ [C.Elow_ratio] - 1;
rot = [C.biphase_ss] < -0.5;          % pre-registered lower-bound set

fprintf('\n================ BETA-EXCESS CLOSURE (n = %d) ================\n', n);
fprintf('median R_harm = %.3f, median R_low = %.3f  (sanity: harmonic excess > low-band)\n', ...
    median([C.Eharm_ratio]), median([C.Elow_ratio]));
fprintf('\ny = R_harm - 1 vs x = beta/(1-beta):\n');
report_fit(x, y);
fprintf('\ny_corr = R_harm/R_low - 1 vs x (low-band model error removed):\n');
report_fit(x, y2);
fprintf('\nrotated-biphase records (biphase_ss < -0.5, beta a lower bound): %d of %d\n', sum(rot), n);
if any(rot) && any(~rot)
    fprintf('  median (y_corr - x): rotated %+.3f, others %+.3f  (pre-registered: rotated above)\n', ...
        median(y2(rot) - x(rot)), median(y2(~rot) - x(~rot)));
end

meta = struct('created', datetime('now'), 'harmBand', [0.12 0.20], ...
    'lowBand', [0.04 0.12], 'elapsed_min', toc(t0)/60, ...
    'note', ['Per-record harmonic-band PUV/MOP energy ratio vs bispectral ' ...
    'bound fraction. Pre-registered: slope ~1 if the model harmonic ' ...
    'deficit is the omitted bound energy. beta = beta_ss_net (lower bound ' ...
    'under biphase rotation); beta_hi = beta_ss + noise_ss.']);
save(fullfile(root, 'validation', 'beta_excess_closure.mat'), 'C', 'meta');
fprintf('\nsaved outputs/validation/beta_excess_closure.mat (%.1f min)\n', meta.elapsed_min);

function report_fit(x, y)
ok = isfinite(x) & isfinite(y);
x = x(ok); y = y(ok);
[rho, p] = corr(x(:), y(:), 'type', 'Spearman');
b0 = (x(:)' * y(:)) / (x(:)' * x(:));
fprintf('  Spearman rho = %.3f (p = %.3g), through-origin slope b0 = %.3f, median(y - x) = %+.3f, n = %d\n', ...
    rho, p, b0, median(y - x), numel(x));
end
