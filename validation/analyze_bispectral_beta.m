% ANALYZE_BISPECTRAL_BETA  Per-record bound-energy fraction from L4 bispectra.
%
% PUV_paper todo #56 -- the load-bearing quantification. The HG91 impedance
% route DETECTS bound energy (z^2 anomaly p = 3.0e-11, localized 0.145-0.215
% Hz) but cannot QUANTIFY it: the fully-bound predicted signal is 4-8% in z^2
% against ~2% control systematics, so beta ranges ~0.1-0.5 across defensible
% controls (findings_hg91_impedance_2026-07-29.md). The bispectrum measures
% phase-coupled energy directly:
%
%   E_bound(f3) = sum over unordered pairs (f1 <= f2, f1+f2 = f3) of
%                 [Re B(f1,f2)]^2 / (P(f1) P(f2))
%
% via shared/bound_energy_from_bispectrum.m, whose constants are pinned by
% validation/test_bispectral_bound.m (Rule-4 synthetic closure, passed
% 2026-07-30). beta_bispec = sum(E_bound)/sum(P) over the harmonic band.
%
% P_MEAN RECOVERY (exact, not reconstructed). PUV_L4_bispectra saves B_mean
% and Bic_mean but not P_mean. Since Bic_mean = |B_mean|/sqrt(P1 P2 P3)
% cell-by-cell, every in-grid cell yields the exact equation
%     logP(i) + logP(j) + logP(k) = 2 log(|B_mean|/Bic_mean),  k = i+j-1,
% with three DISTINCT bins (k > j >= i because i >= 2). The sparse
% least-squares solution recovers the P_mean the path actually used, and is
% validated per record by reproducing the saved Bic_mean (closure residual
% ~ machine precision; records failing 1e-6 are flagged closure_ok = false
% and left out of reported statistics). This beats reconstructing P from
% L2.S_eta, which carries estimator (taper) bias and a segment-set
% approximation; the S_eta route is kept as an independent units
% cross-check only.
%
% NOISE FLOOR. For uncoupled components [Re <B>]^2 rectifies to a positive
% floor ~ P1 P2 P3/(2M). The imaginary-part sum measures it empirically:
% [Im B]^2 = [Re(-i B)]^2, so passing -1i*B_mean through the same kernel
% gives the floor under the biphase ~ 0 hypothesis (bound harmonics are
% real-coupled; TEST 5 pinned the cos^2(beta) projection and the -beta sign
% convention). Reported: beta_raw and beta_net = (sum Eb - sum EbIm)/sum P.
%
% Difference (f3 = f1 - f2) interactions are NOT counted -- the one-sided
% grid holds sum interactions only. Bound harmonics are sum-generated, so
% this is the right band; state it in Limitations.
%
% UNITS. bispectrum.m's one-sided P is NOT doubled: P(+f) = a^2/4 carries
% half the variance of the one-sided density convention, so the recovered
% P_mean is 0.5 * integral(S_eta) per merged bin. The S_eta cross-check
% ratio therefore targets 0.5, not 1 (measured ~0.49, the ~2% shortfall
% being the rectangular-window vs L2-estimator bias). beta is a ratio of
% same-convention quantities, so the factor cancels.
%
% OUTPUT  outputs/validation/bispectral_beta.mat
%   R        struct array, one element per record (see fields inline)
%   fGrid    common 62-pt merged frequency grid
%   meta     provenance
%
% Run from PUV_Pipeline/:  >> run validation/analyze_bispectral_beta
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

BAND = [0.12 0.20];          % harmonic band for beta (todo #56)
F1MIN = 0.04;                % IG/swell boundary: pairs with f1 < F1MIN are
                             % group-bound-IG triads (bound leg = IG, biphase
                             % ~ pi), not bound harmonics at f3 -- see the
                             % kernel's minF1 doc. beta_ss (restricted) is
                             % the quotable bound-harmonic fraction; the
                             % IG-cell share is reported as its own number.
CLOSURE_TOL = 1e-6;          % max |Bic_rec - Bic_saved| accepted

% Impedance results for the per-record comparison (n = 60 set + ur, hsh)
IMP = load(fullfile(root, 'validation', 'bound_fraction_spectral.mat'), 'SUMB', 'recName');

reg   = deployment_registry();
names = sort(keys(reg));
seen  = containers.Map('KeyType','char','ValueType','logical');

R = struct('rec', {}, 'deployment', {}, 'label', {}, 'nValid', {}, ...
    'excluded', {}, 'in60', {}, 'closure_ok', {}, 'closure_resid', {}, ...
    'beta_raw', {}, 'beta_net', {}, 'noise_frac', {}, 'biphase_w', {}, ...
    'beta_ss', {}, 'beta_ss_net', {}, 'noise_ss', {}, 'biphase_ss', {}, ...
    'Eb', {}, 'EbIm', {}, 'Eb_ss', {}, 'EbIm_ss', {}, 'P', {}, ...
    'ratio_seta', {}, 'ur', {}, 'hsh', {}, 'beta_imped', {});
fGrid = [];

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        f4  = fullfile(root, 'L4', cfg.name, [lab '_L4.mat']);
        rec = [cfg.name '/' lab];
        if ~isfile(f4), fprintf('[skip] %s: no L4 file\n', rec); continue; end

        % --- read the bispectra sub-product (partial h5 read; load fallback)
        try
            Bs   = h5read(f4, '/L4/bispectra/B_mean');
            B    = complex(Bs.real, Bs.imag);
            Bic  = h5read(f4, '/L4/bispectra/Bic_mean');
            fG   = h5read(f4, '/L4/bispectra/f');
            nVal = double(h5read(f4, '/L4/bispectra/nValid'));
        catch
            S4 = load(f4, 'L4');
            if ~isfield(S4.L4, 'bispectra')
                fprintf('[skip] %s: no bispectra sub-product\n', rec); continue;
            end
            B    = S4.L4.bispectra.B_mean;
            Bic  = S4.L4.bispectra.Bic_mean;
            fG   = S4.L4.bispectra.f;
            nVal = double(S4.L4.bispectra.nValid);
        end
        fG = fG(:);
        nf = numel(fG);
        if nVal < 1 || all(~isfinite(B(:)))
            fprintf('[skip] %s: no valid segments in bispectra\n', rec); continue;
        end
        if isempty(fGrid), fGrid = fG; end
        assert(numel(fGrid) == nf && max(abs(fGrid - fG)) < 1e-12, ...
            'analyze_bispectral_beta:grid', '%s: bispectra grid differs.', rec);

        % --- recover the exact P_mean from |B_mean|/Bic_mean ---------------
        [P_rec, resid] = recover_P(B, Bic, nf);

        % closure: reproduce the saved Bic_mean on every cell it defines
        [I1, I2] = meshgrid(1:nf, 1:nf);
        K3 = I1 + I2 - 1;
        chk = K3 <= nf & isfinite(Bic) & Bic > 0;
        Bic_rec = NaN(nf, nf);
        Bic_rec(chk) = abs(B(chk)) ./ ...
            sqrt(P_rec(I1(chk)) .* P_rec(I2(chk)) .* P_rec(K3(chk)));
        closure = max(abs(Bic_rec(chk) - Bic(chk)));
        ok = closure < CLOSURE_TOL;
        if ~ok
            fprintf('[FLAG] %s: Bic closure residual %.3g (LS resid %.3g) -- excluded from stats\n', ...
                rec, closure, resid);
        end

        % --- bound energy and beta -----------------------------------------
        Eb     = bound_energy_from_bispectrum(B, P_rec, fG);
        EbIm   = bound_energy_from_bispectrum(-1i * B, P_rec, fG);
        oSS    = struct('minF1', F1MIN);           % sea-swell pairs only
        EbSS   = bound_energy_from_bispectrum(B, P_rec, fG, oSS);
        EbImSS = bound_energy_from_bispectrum(-1i * B, P_rec, fG, oSS);

        inBand = fG >= BAND(1) & fG <= BAND(2);
        sumP  = sum(P_rec(inBand));
        bRaw  = sum(Eb(inBand))     / sumP;
        bIm   = sum(EbIm(inBand))   / sumP;
        bNet  = bRaw - bIm;
        bSS   = sum(EbSS(inBand))   / sumP;
        bImSS = sum(EbImSS(inBand)) / sumP;
        bSSn  = bSS - bImSS;

        % energy-weighted mean biphase over cells feeding the band
        % (weight = each cell's contribution to Eb), full and SS-restricted
        [biphW, biphSS] = deal_biphase(B, P_rec, fG, inBand, F1MIN);

        % --- independent units cross-check vs L2.S_eta ---------------------
        % Approximate segment set (segValid; misses eta-NaN drops and the 3
        % known index-shifted records -- median-level check only).
        ratioSeta = NaN;
        try
            f2f  = fullfile(root, 'L2', cfg.name, [lab '_L2.mat']);
            Se   = h5read(f2f, '/L2/S_eta');
            sv   = logical(h5read(f2f, '/L2/segValid'));
            fL2  = h5read(f2f, '/L2/f'); fL2 = fL2(:);
            Sbar = mean(Se(:, sv), 2, 'omitnan');
            df2  = fL2(2) - fL2(1);
            dfm  = fG(2) - fG(1);
            P_L2 = NaN(nf, 1);
            for n = 2:nf
                sel = fL2 >= fG(n) - dfm/2 & fL2 < fG(n) + dfm/2;
                P_L2(n) = sum(Sbar(sel)) * df2;
            end
            ratioSeta = median(P_rec(inBand) ./ P_L2(inBand), 'omitnan');
            % expected ~0.5: bisp P is one-sided but NOT doubled (see header)
        catch ME
            fprintf('  [warn] %s: S_eta cross-check failed: %s\n', rec, ME.message);
        end

        % --- flags and joins ----------------------------------------------
        excl = excluded_records(cfg.name, lab);
        i60  = find(strcmp(IMP.recName, rec), 1);
        r = struct('rec', rec, 'deployment', cfg.name, 'label', lab, ...
            'nValid', nVal, 'excluded', excl, 'in60', ~isempty(i60), ...
            'closure_ok', ok, 'closure_resid', closure, ...
            'beta_raw', bRaw, 'beta_net', bNet, 'noise_frac', bIm, ...
            'biphase_w', biphW, ...
            'beta_ss', bSS, 'beta_ss_net', bSSn, 'noise_ss', bImSS, ...
            'biphase_ss', biphSS, ...
            'Eb', Eb, 'EbIm', EbIm, 'Eb_ss', EbSS, 'EbIm_ss', EbImSS, ...
            'P', P_rec, ...
            'ratio_seta', ratioSeta, 'ur', NaN, 'hsh', NaN, 'beta_imped', NaN);
        if ~isempty(i60)
            % SUMB is PER-HOUR; .rec holds the recName index. Per-record medians.
            hh = IMP.SUMB.rec == i60;
            r.ur         = median(IMP.SUMB.ur(hh), 'omitnan');
            r.hsh        = median(IMP.SUMB.hsh(hh), 'omitnan');
            r.beta_imped = median(IMP.SUMB.betaBand(hh), 'omitnan');
        end
        R(end+1) = r; %#ok<SAGROW>

        fprintf('%-22s nValid=%5d  beta_ss=%7.4f (net %7.4f, noise %6.4f, biph %+6.3f)  igcell=%7.4f  beta_full=%7.4f  rSeta=%6.3f%s%s\n', ...
            rec, nVal, bSS, bSSn, bImSS, biphSS, bRaw - bSS, bRaw, ratioSeta, ...
            tern(excl, '  [EXCLUDED]', ''), tern(ok, '', '  [CLOSURE FAIL]'));
    end
end

%% ---- summary -----------------------------------------------------------
use  = [R.closure_ok] & ~[R.excluded] & [R.in60];
nUse = sum(use);
if nUse == 0
    fprintf('\nNO USABLE RECORDS -- summary skipped. Check closure flags above.\n');
    return
end
bS = [R(use).beta_ss];   bSn = [R(use).beta_ss_net];  bI = [R(use).beta_imped];
bF = [R(use).beta_raw];  ur  = [R(use).ur];           biphS = [R(use).biphase_ss];

fprintf('\n================ SUMMARY (n = %d: in the 60-set, closure ok) ================\n', nUse);
fprintf('beta_ss      : median %.4f  IQR [%.4f, %.4f]   (sea-swell pairs, the quotable one)\n', ...
    median(bS), quantile(bS, 0.25), quantile(bS, 0.75));
fprintf('beta_ss_net  : median %.4f  IQR [%.4f, %.4f]   (noise floor median %.4f)\n', ...
    median(bSn), quantile(bSn, 0.25), quantile(bSn, 0.75), median([R(use).noise_ss]));
fprintf('IG-cell share: median %.4f  (beta_full - beta_ss; group-triad cells, NOT bound-harmonic energy)\n', ...
    median(bF - bS));
p_sign = signrank(bSn);
fprintf('signed-rank beta_ss_net vs 0: p = %.3g\n', p_sign);
fprintf('biphase (SS cells): median %+.3f rad, IQR [%+.3f, %+.3f]\n', ...
    median(biphS), quantile(biphS, 0.25), quantile(biphS, 0.75));
fprintf('vs impedance betaBand: Spearman rho = %.3f (p = %.3g); impedance range was ~0.1-0.5\n', ...
    corr(bSn(:), bI(:), 'type', 'Spearman', 'rows', 'complete'), ...
    corr_p(bSn(:), bI(:)));
fprintf('vs Ursell: Spearman rho = %.3f (p = %.3g)\n', ...
    corr(bSn(:), ur(:), 'type', 'Spearman', 'rows', 'complete'), corr_p(bSn(:), ur(:)));

% localization: absolute SS-restricted Eb, each record normalized by its max
EbM = cat(2, R(use).Eb_ss);
EbN = EbM ./ max(EbM, [], 1);
locMed = median(EbN, 2, 'omitnan');
[~, iPk] = max(locMed);
ii = find(locMed > 0.5 * max(locMed));
fprintf('localization (abs Eb_ss): peak %.4f Hz, half-max %.4f-%.4f Hz (impedance: peak 0.180, 0.145-0.215)\n', ...
    fGrid(iPk), fGrid(min(ii)), fGrid(max(ii)));

nCF = sum(~[R.closure_ok]);
fprintf('records: %d total, %d in 60-set, %d closure-flagged, %d excluded\n', ...
    numel(R), sum([R.in60]), nCF, sum([R.excluded]));

meta = struct('created', datetime('now'), 'band', BAND, ...
    'note', ['P_mean recovered exactly from |B_mean|/Bic_mean (log-LS); ' ...
    'estimator pinned by test_bispectral_bound.m; beta_net subtracts the ' ...
    'Im-part rectification floor; difference interactions not counted.']);
save(fullfile(root, 'validation', 'bispectral_beta.mat'), 'R', 'fGrid', 'meta');
fprintf('\nsaved outputs/validation/bispectral_beta.mat\n');

%% ---- local functions ---------------------------------------------------
function [P, resid] = recover_P(B, Bic, nf)
% Exact P_mean from Bic = |B|/sqrt(P1 P2 P3): sparse log-linear LS.
% Bin 1 (the merged near-DC bin) is a real unknown: only the exact DC line
% is zeroed before merging, so merged bin 1 carries IG energy and the saved
% Bic has finite cells on row/column 1. For i = 1 the sum index k equals j,
% so that unknown appears twice in the equation -- sparse() accumulates
% duplicate (row,col) entries, which handles the coefficient automatically.
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

function [biphAll, biphSS] = deal_biphase(B, P, f, inBand, f1min)
% Energy-weighted mean biphase over cells feeding the band bins, full
% anti-diagonal and sea-swell-restricted. Weight = the cell's contribution
% to Eb, direction = the cell's B phase.
wAll = 0; wSS = 0;
for i3 = find(inBand(:))'
    for i1 = 2:floor((i3 + 1)/2)
        i2 = i3 + 1 - i1;
        w  = real(B(i1,i2))^2 / (P(i1) * P(i2));
        u  = w * B(i1,i2) / abs(B(i1,i2));
        wAll = wAll + u;
        if f(i1) >= f1min, wSS = wSS + u; end
    end
end
biphAll = angle(wAll);
biphSS  = angle(wSS);
end

function p = corr_p(a, b)
[~, p] = corr(a(:), b(:), 'type', 'Spearman', 'rows', 'complete');
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
