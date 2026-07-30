% ANALYZE_BOUND_FRACTION_SPECTRAL  Bound fraction at every frequency, with no peak
% frequency and no band reference anywhere in the calculation.
%
% WHY. Every earlier version of this diagnostic defined the harmonic band as
% [1.75, 2.5]*f_ref. That is unsafe: O'Reilly et al. (2016) show fp is unstable in
% southern California when sea and swell peak energies are comparable, and 24.7%
% of our hours are in that regime. It is also conceptually wrong in mixed states --
% a swell peak at 0.075 Hz puts its harmonic at 0.15 Hz, inside the sea band, so a
% peak-referenced band conflates bound swell harmonic with real sea energy.
% Swapping argmax fp for another peak estimator does not fix that, and a centroid
% is worse because the sea drags it upward.
%
% THE METHOD, entirely from spectral shape:
%   kappa_bound(f) = 2 conv(k.*S, S) / conv(S, S)      shared/bound_wavenumber_spectral.m
%   z2_pred(f)     = (k_free(f) / kappa_bound(f))^2
%   z2_obs(f)      = S_pp / [(S_uu+S_vv) (omega/(g k_free))^2]     the pipeline's ztest
%   beta(f)        = (1 - 1/z2_rel) / (1 - 1/z2_pred)   reciprocal mixture
% with z2_rel = z2_obs / z2_ctrl and the control itself reference-free:
%   z2_ctrl = sum(S z2_obs)/sum(S)
% an ENERGY-WEIGHTED mean, which puts nearly all its weight on the energetic
% primary region (where boundness is small) without ever locating a peak. It
% absorbs the ~5% frequency-independent z^2 offset seen in the earlier band
% analysis.
%
% Validated in L2_spectral/test_kp_bound_harmonic.m section 5: kappa_bound
% recovers 2*k0 for a monochromatic primary and k(f1)+k(f2) for a bichromatic
% pair, the case a peak-referenced band cannot represent at all.
%
% All quantities are computed on a COARSE uniform 0.005 Hz grid. kappa_bound is a
% smooth energy-weighted mean, so this costs nothing in accuracy, and it keeps the
% two convolutions per hour cheap over ~72k hours.
%
% Writes outputs/validation/bound_fraction_spectral.mat
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
reg  = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');
g = 9.81;

FC   = (0.04:0.005:0.25)';        % coarse analysis grid
nC   = numel(FC);
WMIN = 1e-4;                      % min share of peak pair-weight to trust beta
PMIN = 1.02;                      % min z2_pred for the inversion to be conditioned

SUMB = struct('rec',[],'ur',[],'hsh',[],'h',[],'betaBand',[],'z2ctrl',[]);
BETA = zeros(0,nC); Z2O = zeros(0,nC); Z2P = zeros(0,nC);
recName = {};

t0 = tic; nRec = 0;
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true;

    for k = 1:numel(cfg.instruments)
        lab = cfg.instruments(k).label;
        if excluded_records(cfg.name, lab), continue; end
        f2 = fullfile(cfg.outputDir,'L2',cfg.name,[lab '_L2.mat']);
        if ~isfile(f2), continue; end
        try, w = load(f2,'L2'); L2 = w.L2; catch, continue; end
        if ~isfield(L2,'Suu') || isempty(L2.Suu), continue; end
        v = find(L2.segValid);
        if numel(v) < 50, continue; end
        nRec = nRec + 1; recName{nRec} = sprintf('%s/%s',cfg.name,lab); %#ok<SAGROW>

        f = L2.f(:);
        nHr = 0; bAcc = [];
        for i = v(:)'
            Se = double(L2.S_eta(:,i)); Sp = double(L2.Spp(:,i));
            Su = double(L2.Suu(:,i));   Sv = double(L2.Svv(:,i));
            if all(~isfinite(Se)) || all(~isfinite(Su)), continue; end
            hh = L2.depth(i); if ~isfinite(hh) || hh <= 0, continue; end
            fc = L2.fCut(i);  if ~isfinite(fc), fc = 0.25; end

            % bin onto the coarse grid (mean of fine bins in each coarse bin)
            Sec = binto(f, Se, FC); Spc = binto(f, Sp, FC);
            Suc = binto(f, Su, FC); Svc = binto(f, Sv, FC);
            ok = isfinite(Sec) & isfinite(Spc) & isfinite(Suc) & Sec > 0 & FC <= fc;
            if sum(ok) < 12, continue; end

            % reference-free bound wavenumber and prediction
            Suse = Sec; Suse(~ok) = 0;
            [kbnd, kfr, z2p, wt] = bound_wavenumber_spectral(FC, Suse, hh, g);

            % observed z^2, exactly the pipeline's form
            u2p = (2*pi*FC) ./ (g * max(kfr, eps));
            z2o = Spc ./ max((Suc + Svc) .* u2p.^2, eps);

            % energy-weighted control: no peak located anywhere
            wc = Sec; wc(~ok) = 0;
            z2c = sum(wc .* z2o, 'omitnan') / max(sum(wc), eps);
            if ~isfinite(z2c) || z2c <= 0, continue; end

            rel = z2o / z2c;
            good = ok & isfinite(z2p) & z2p >= PMIN & wt >= WMIN*max(wt);
            bta = nan(nC,1);
            bta(good) = (1 - 1./rel(good)) ./ (1 - 1./z2p(good));

            m0 = trapz(FC(ok), Sec(ok));
            Hs = 4*sqrt(max(m0,0));
            % Ursell needs a representative k; use the energy-weighted mean k,
            % again reference-free rather than a peak.
            kbar = sum(wc .* kfr, 'omitnan')/max(sum(wc),eps);
            ur = Hs / (hh * (kbar*hh)^2);

            % a fixed ABSOLUTE band where swell harmonics live, for one summary
            % number comparable to the earlier band-referenced beta
            ib = FC >= 0.12 & FC <= 0.20 & good;
            bb = NaN; if sum(ib) >= 4, bb = median(bta(ib),'omitnan'); end

            nHr = nHr + 1;
            BETA(end+1,:) = bta'; Z2O(end+1,:) = rel'; Z2P(end+1,:) = z2p'; %#ok<SAGROW>
            SUMB.rec(end+1,1)=nRec; SUMB.ur(end+1,1)=ur; SUMB.hsh(end+1,1)=Hs/hh;
            SUMB.h(end+1,1)=hh; SUMB.betaBand(end+1,1)=bb; SUMB.z2ctrl(end+1,1)=z2c;
            bAcc(end+1,1) = bb; %#ok<SAGROW>
        end
        fprintf('  %-9s %-13s %5d hours  beta(0.12-0.20 Hz) = %+.4f\n', ...
                cfg.name, lab, nHr, median(bAcc,'omitnan'));
    end
end
fprintf('\n%d records, %d hours, %.1f min\n', nRec, numel(SUMB.ur), toc(t0)/60);

%% ---- results ----------------------------------------------------------
fprintf('\n=============================================================\n');
fprintf(' beta(f) with NO peak frequency and NO band reference\n');
fprintf('=============================================================\n');
fprintf('  z2 control (energy-weighted, reference-free): median %.4f\n', ...
        median(SUMB.z2ctrl,'omitnan'));
fprintf('\n  %-14s %-10s %-10s %-10s %s\n','freq (Hz)','z2_pred','z2_rel','beta','n');
for j = 1:nC
    gj = isfinite(BETA(:,j));
    if sum(gj) < 500, continue; end
    fprintf('  %-14.3f %-10.4f %-10.4f %-10.4f %d\n', FC(j), ...
        median(Z2P(gj,j),'omitnan'), median(Z2O(gj,j),'omitnan'), ...
        median(BETA(gj,j),'omitnan'), sum(gj));
end

fprintf('\n  Per-record beta over the fixed 0.12-0.20 Hz band (comparable to the\n');
fprintf('  earlier band-referenced 0.106):\n');
ru = unique(SUMB.rec);
pr = nan(numel(ru),2);
for q = 1:numel(ru)
    s = SUMB.rec == ru(q);
    if sum(s) > 50
        pr(q,1) = median(SUMB.betaBand(s),'omitnan');
        pr(q,2) = median(SUMB.ur(s),'omitnan');
    end
end
pr = pr(all(isfinite(pr),2),:);
fprintf('    n = %d records   median beta = %.4f   IQR %.4f - %.4f\n', ...
    size(pr,1), median(pr(:,1)), prctile(pr(:,1),25), prctile(pr(:,1),75));
if size(pr,1) > 10
    [rho,pv] = corr(pr(:,2), pr(:,1), 'type','Spearman');
    fprintf('    rho(Ursell, beta) = %+.3f  (p = %.3g)\n', rho, pv);
    pv2 = signrank(pr(:,1));
    fprintf('    signrank beta vs 0: p = %.3g\n', pv2);
end

meta = struct('created',datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
              'nRecords',nRec,'nHours',numel(SUMB.ur), ...
              'note','reference-free: no peak frequency, no band, energy-weighted control');
save(fullfile(root,'bound_fraction_spectral.mat'), ...
     'SUMB','BETA','Z2O','Z2P','FC','recName','meta','WMIN','PMIN');
fprintf('\nSaved bound_fraction_spectral.mat\n');

%% ---- helper ----------------------------------------------------------
function y = binto(f, S, FC)
    df = median(diff(FC));
    y  = nan(numel(FC),1);
    for j = 1:numel(FC)
        b = f >= FC(j)-df/2 & f < FC(j)+df/2 & isfinite(S);
        if any(b), y(j) = mean(S(b)); end
    end
end
