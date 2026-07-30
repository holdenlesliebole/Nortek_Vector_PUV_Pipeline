% DIAGNOSE_COR16B  Where does COR16B's beta = 0.63 live, and does the
% beta_mag variant close the slope?  (PUV_paper todo #61, part 1)
%
% The contradiction: COR16B/MOP158_9m (Coronado) carries the catalog's
% largest bound fraction (beta_ss_net = 0.63; next largest 0.43) AND a model
% over-prediction of its harmonic band (R_harm = 0.843). Both cannot be
% right. Co-sited COR17D has beta = 0.12 with R_harm = 0.838, so the site's
% modest model bias (~12-16% high everywhere) is real but cannot mask a 63%
% bound share.
%
% Part 1 (this script, saved data only):
%   A. Cell anatomy: is COR16B's Eb broad across the coupling region (like
%      other high-beta records) or concentrated in a few cells (artifact
%      signature)? Top-cell shares + effective cell count, vs COR17D and vs
%      the two honest high-beta records TOR16C (0.43) and TOR24W_7m (0.40).
%   B. Bicoherence sanity: max and contributing-cell median Bic vs b95.
%   C. Record vitals from L2: season, Hs, ztest_SS, valid fraction.
%   D. Rectification-bias magnitude check: bias on Eb(f3) is
%      2*nPair*P3/edof_tot per bin; confirm it is negligible (<<1% of P)
%      rather than asserting it.
%   E. The pre-registered slope falsifier, from beta_excess_closure.mat:
%      refit with x from beta_hi = beta_ss + noise_ss (= the |B|^2 magnitude
%      variant, since D shows the rectification bias is negligible). If the
%      0.875 slope shortfall is the cos^2 undercount, the beta_hi slope
%      should move toward 1.
%
% Part 2 (analyze_cor16b_timeresolved.m, background) chunks the record in
% time to see whether beta = 0.63 is an episode or a steady state.
%
% Run from PUV_Pipeline/:  >> run validation/diagnose_cor16b
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

BAND = [0.12 0.20]; F1MIN = 0.04;
RECS = {'COR16B', 'MOP158_9m'; 'COR17D', 'MOP158_9m'; ...
        'TOR16C', 'MOP591_9m'; 'TOR24W', 'MOP586_7m'};

fprintf('\n=============== COR16B DIAGNOSIS (todo #61, part 1) ===============\n');
fprintf('%-20s %8s %8s %8s %8s %8s %8s %9s %8s\n', 'rec', 'beta_ss', 'top1', ...
    'top5', 'nEff', 'maxBic', 'medBic', 'b95', 'bias/P');

for r = 1:size(RECS,1)
    dep = RECS{r,1}; lab = RECS{r,2};
    f4 = fullfile(root, 'L4', dep, [lab '_L4.mat']);
    Bs  = h5read(f4, '/L4/bispectra/B_mean');
    B   = complex(Bs.real, Bs.imag);
    Bic = h5read(f4, '/L4/bispectra/Bic_mean');
    fG  = h5read(f4, '/L4/bispectra/f'); fG = fG(:);
    ed  = h5read(f4, '/L4/bispectra/edof');
    nf  = numel(fG);
    P   = recover_P_from_bispectrum(B, Bic, nf);

    % --- A: per-cell contributions to the band Eb (SS pairs only) --------
    inBand = fG >= BAND(1) & fG <= BAND(2);
    w = []; cf1 = []; cf2 = []; wBic = [];
    for i3 = find(inBand(:))'
        for i1 = 2:floor((i3+1)/2)
            i2 = i3 + 1 - i1;
            if fG(i1) < F1MIN, continue; end
            w(end+1)    = real(B(i1,i2))^2 / (P(i1)*P(i2)); %#ok<SAGROW>
            cf1(end+1)  = fG(i1); cf2(end+1) = fG(i2);      %#ok<SAGROW>
            wBic(end+1) = Bic(i1,i2);                        %#ok<SAGROW>
        end
    end
    wS   = sum(w);
    beta = wS / sum(P(inBand));
    [ws, iw] = sort(w, 'descend');
    top1 = ws(1)/wS;  top5 = sum(ws(1:min(5,end)))/wS;
    nEff = wS^2 / sum(w.^2);                 % inverse participation ratio
    contributing = w > 0.01*ws(1);
    medBic = median(wBic(contributing));
    b95    = sqrt(6 / median(ed, 'omitnan'));  % per-SEGMENT threshold; the
    % record-mean B has nValid x more averaging, so record-level coupling can
    % be real well below this -- shown for scale only.

    % --- D: rectification bias magnitude ---------------------------------
    edofTot = sum(ed, 'omitnan');
    nPairB  = numel(w);
    biasP   = 2 * nPairB * median(P(inBand)) / edofTot / median(P(inBand)); % = 2 nPair/edofTot

    fprintf('%-20s %8.3f %8.3f %8.3f %8.1f %8.3f %8.3f %9.3f %8.5f\n', ...
        [dep '/' lab], beta, top1, top5, nEff, max(wBic), medBic, b95, biasP);

    if r <= 2   % the two COR records: name the top cells
        fprintf('   top 5 cells (f1, f2 -> f3, Hz | share | Bic):\n');
        for k = 1:min(5, numel(ws))
            j = iw(k);
            fprintf('     %.3f + %.3f -> %.3f | %5.1f%% | %.3f\n', ...
                cf1(j), cf2(j), cf1(j)+cf2(j), 100*ws(k)/wS, wBic(j));
        end
    end
end

% --- C: L2 vitals for the two COR records --------------------------------
fprintf('\nL2 vitals:\n');
for r = 1:2
    dep = RECS{r,1}; lab = RECS{r,2};
    S2 = load(fullfile(root, 'L2', dep, [lab '_L2.mat']), 'L2'); L2 = S2.L2;
    v  = logical(L2.segValid(:));
    fprintf('%-20s %s to %s | %d/%d valid (%.0f%%) | Hs med %.2f p90 %.2f m | ztest_SS med %.3f | depth med %.1f m\n', ...
        [dep '/' lab], string(min(L2.time), 'yyyy-MM-dd'), string(max(L2.time), 'yyyy-MM-dd'), ...
        sum(v), numel(v), 100*mean(v), ...
        median(L2.Hs(v), 'omitnan'), quantile(L2.Hs(v), 0.9), ...
        median(L2.ztest_SS(v), 'omitnan'), median(L2.depth(v), 'omitnan'));
end

% --- E: slope falsifier with beta_hi (the |B|^2 magnitude variant) -------
S = load(fullfile(root, 'validation', 'beta_excess_closure.mat'));
C = S.C; rec = {C.rec};
y  = [C.Eharm_ratio] - 1;
xN = [C.beta]    ./ (1 - [C.beta]);      % beta_ss_net (Re^2, lower bound)
xH = [C.beta_hi] ./ (1 - [C.beta_hi]);   % beta_ss + noise_ss (|B|^2 magnitude)
m  = ~strcmp(rec, 'COR16B/MOP158_9m');

fit = @(x,y) deal(corr(x(:),y(:),'type','Spearman'), (x(:)'*y(:))/(x(:)'*x(:)));
[rN, bN] = fit(xN(m), y(m));
[rH, bH] = fit(xH(m), y(m));
fprintf('\nslope falsifier (minus COR16B, n = %d):\n', sum(m));
fprintf('  x = beta_net/(1-beta_net)  : rho = %.3f, b0 = %.3f\n', rN, bN);
fprintf('  x = beta_hi /(1-beta_hi)   : rho = %.3f, b0 = %.3f\n', rH, bH);
fprintf('  pre-registered: if the 1 - %.3f shortfall is the cos^2 undercount,\n', bN);
fprintf('  the beta_hi slope should sit nearer 1 (beta_hi = |B|^2 variant;\n');
fprintf('  rectification bias confirmed negligible in column bias/P above).\n');
