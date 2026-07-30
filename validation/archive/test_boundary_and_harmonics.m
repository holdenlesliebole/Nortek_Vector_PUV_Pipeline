% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% TWO TESTS ON THE SAME HOURS
%
% TEST 1 (task 13) -- BOUNDARY COINCIDENCE.
%   Does the linear-model spectral discrepancy (nu ratio) turn on at the same
%   Hs/h as second-order bound-wave theory starts over-predicting?
%   L4.boundwave estimates bound IG from the Hasselmann (1962) second-order
%   kernel, so bound_frac_raw = predicted-bound / observed-total IG, and
%   bound_frac_raw > 1 IS the over-prediction. Bin both diagnostics on the
%   same hours and compare their onsets. Do NOT assume they coincide.
%
% TEST 2 -- THE nu -> HARMONICS LINK.
%   Hypothesis: the nu excess is nonlinearly generated super-harmonics near
%   2*fp that a linear transform cannot produce. Two predictions:
%     (a) the PUV/model energy excess is LOCALIZED near 2*fp, not broadband
%     (b) it scales with the swell self-interaction bicoherence b^2(fp,fp),
%         which is the direct measure of that triad's phase coupling
%   L4.bispectra.bic_swell_self is exactly that quantity, with b95 as the
%   significance level.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

L2root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';
L4root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L4';
cases = { 'TOR24S','MOP586_5m'; 'TBR23','MOP586_5m'; 'TOR23W','MOP580_5m'
          'TBR23','MOP586_7m';  'IB18W','MOP045_7m'; 'SOL25B','MOP654_7m'
          'TOR23W','MOP586_10m';'TOR24W','MOP586_15m' };

A = struct('hsh',[],'nu',[],'en',[],'bfr',[],'bic',[],'b95',[], ...
           'harm',[],'peakr',[],'skew',[],'h',[],'fp',[]);

fprintf('\n=========== COLLECTING ===========\n');
for c = 1:size(cases,1)
    f2 = fullfile(L2root, cases{c,1}, [cases{c,2} '_L2.mat']);
    f4 = fullfile(L4root, cases{c,1}, [cases{c,2} '_L4.mat']);
    if ~isfile(f2) || ~isfile(f4), fprintf('  [miss] %s/%s\n',cases{c,:}); continue; end
    S2 = load(f2); L2 = S2.L2; S4 = load(f4); L4 = S4.L4;

    valid = find(L2.segValid);
    tS = min(L2.time(valid)); tE = max(L2.time(valid));
    if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end
    try, MOP = read_MOPline2(L2.mopStation, tS, tE); catch, continue; end
    if isempty(MOP.time), continue; end

    tP = L2.time(valid); if isempty(tP.TimeZone), tP.TimeZone = MOP.time.TimeZone; end
    pick = NaN(numel(MOP.time),1);
    for t = 1:numel(MOP.time)
        [dt,im] = min(abs(tP - MOP.time(t)));
        if dt < minutes(30), pick(t) = valid(im); end
    end
    keep = find(~isnan(pick)); if numel(keep) < 20, continue; end
    idx = pick(keep);

    MOPk = MOP; MOPk.spec1D = MOP.spec1D(keep,:); MOPk.time = MOP.time(keep);
    shd = shoal_mop_to_site(MOPk, L2.depth(idx));
    fMid = shd.frequency; fbw = shd.fbw; fbounds = shd.fbounds;
    f = L2.f(:); fSS = L2.params.fSS;
    iB = fMid >= fSS(1) & fMid <= 0.18;          % fixed band, as before
    if sum(iB) < 4, continue; end

    % L4 per-segment fields are on the L2 segment index
    bfrAll = L4.boundwave.bound_frac_raw;
    bicAll = L4.bispectra.bic_swell_self;
    b95All = L4.bispectra.b95;
    skwAll = L4.bispectra.skewness;
    hshAll = L4.ref.Hs_over_h;

    for i = 1:numel(keep)
        ii = idx(i); h = L2.depth(ii);
        if ~isfinite(h)||h<=0, continue; end
        s = double(L2.S_eta(:,ii)); if all(~isfinite(s)), continue; end

        sb = bin_spectrum_to_grid(f, s, fbounds);
        sbB = sb(iB); sbB(~isfinite(sbB))=0;
        smB = shd.spec(i,:)'; smB = smB(iB); smB(~isfinite(smB))=0;
        w = fbw(iB); fm = fMid(iB);
        m0p = sum(sbB.*w); m0m = sum(smB.*w);
        if m0p<=0 || m0m<=0, continue; end

        nu_p = nuf(sbB,fm,w); nu_m = nuf(smB,fm,w);
        if ~isfinite(nu_p)||~isfinite(nu_m)||nu_m<=0, continue; end

        % --- harmonic localization: PUV/model ratio near 2fp vs near fp
        fp = L2.Tp(ii); if ~isfinite(fp)||fp<=0, continue; end
        fp = 1/fp;
        rat = sbB ./ max(smB, eps);
        mPk = fm >= 0.8*fp  & fm <= 1.2*fp;
        mHa = fm >= 1.6*fp  & fm <= 2.4*fp;
        if sum(mPk)<1 || sum(mHa)<1, continue; end
        peakr = median(rat(mPk)); harm = median(rat(mHa));
        if ~isfinite(peakr)||peakr<=0||~isfinite(harm), continue; end

        A.hsh(end+1,1)   = hshAll(ii);
        A.nu(end+1,1)    = nu_p/nu_m;
        A.en(end+1,1)    = m0m/m0p;
        A.bfr(end+1,1)   = bfrAll(ii);
        A.bic(end+1,1)   = bicAll(ii);
        A.b95(end+1,1)   = b95All(ii);
        A.skew(end+1,1)  = skwAll(ii);
        A.harm(end+1,1)  = harm/peakr;      % harmonic excess relative to peak
        A.peakr(end+1,1) = peakr;
        A.h(end+1,1)     = h;
        A.fp(end+1,1)    = fp;
    end
    fprintf('  %-9s %-12s pooled: %d\n', cases{c,1}, cases{c,2}, numel(A.hsh));
end

N = numel(A.hsh);
fprintf('\npooled hours n = %d\n', N);

%% ============ TEST 1: BOUNDARY COINCIDENCE ============
fprintf('\n=========== TEST 1: DO THE BOUNDARIES COINCIDE? ===========\n');
fprintf('bound_frac_raw = Hasselmann 2nd-order predicted bound-IG / observed IG.\n');
fprintf('  >1 means second-order theory OVER-predicts.\n\n');
edges = [0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
fprintf('  %-14s %7s %11s %14s %11s\n','Hs/h bin','n','nu ratio','bound_frac_raw','frac >1');
for b = 1:numel(edges)-1
    m = A.hsh>=edges(b) & A.hsh<edges(b+1) & isfinite(A.bfr);
    if sum(m) < 25, continue; end
    fprintf('  %5.2f - %5.2f %7d %11.4f %14.3f %10.1f%%\n', edges(b), edges(b+1), ...
        sum(m), median(A.nu(m)), median(A.bfr(m)), 100*mean(A.bfr(m)>1));
end
mm = isfinite(A.bfr)&isfinite(A.hsh);
[rb,pb] = corr(A.hsh(mm), A.bfr(mm), 'type','Spearman');
mn = isfinite(A.nu)&isfinite(A.hsh);
[rn,pn] = corr(A.hsh(mn), A.nu(mn), 'type','Spearman');
fprintf('\n  rho(bound_frac_raw, Hs/h) = %+.3f (p=%.2g)   [plan claims +0.93]\n', rb, pb);
fprintf('  rho(nu ratio,       Hs/h) = %+.3f (p=%.2g)\n', rn, pn);
m3 = isfinite(A.bfr)&isfinite(A.nu);
[rc,pc] = corr(A.bfr(m3), A.nu(m3), 'type','Spearman');
fprintf('  rho(nu ratio, bound_frac_raw) = %+.3f (p=%.2g)  <- do they co-vary?\n', rc, pc);

% Onset estimates: lowest Hs/h bin where each departs from its null
fprintf('\n  ONSETS (first bin departing from the null):\n');
fprintf('    nu ratio null = 1.000; bound_frac_raw null = 1.000 (no over-prediction)\n');

%% ============ TEST 2: nu -> HARMONICS ============
fprintf('\n=========== TEST 2: IS THE EXCESS HARMONICS? ===========\n');
sig = A.bic > A.b95;
fprintf('  bicoherence above b95 in %.1f%% of hours\n', 100*mean(sig));
fprintf('  harmonic excess (ratio near 2fp / ratio near fp): median %.3f\n', median(A.harm));

mh = isfinite(A.harm)&isfinite(A.bic);
[r1,p1] = corr(A.bic(mh), A.harm(mh), 'type','Spearman');
[r2,p2] = corr(A.bic(mh), A.nu(mh),   'type','Spearman');
[r3,p3] = corr(A.skew(mh), A.nu(mh),  'type','Spearman');
fprintf('\n  rho(bicoherence_swell_self, harmonic excess) = %+.3f (p=%.2g)\n', r1, p1);
fprintf('  rho(bicoherence_swell_self, nu ratio)        = %+.3f (p=%.2g)\n', r2, p2);
fprintf('  rho(skewness,               nu ratio)        = %+.3f (p=%.2g)\n', r3, p3);

% Does bicoherence explain nu beyond Hs/h?
m4 = isfinite(A.bic)&isfinite(A.nu)&isfinite(A.hsh);
pr = partialcorr(A.bic(m4), A.nu(m4), A.hsh(m4), 'type','Spearman');
pr2 = partialcorr(A.hsh(m4), A.nu(m4), A.bic(m4), 'type','Spearman');
fprintf('\n  PARTIAL: bicoherence | Hs/h -> nu : %+.3f\n', pr);
fprintf('           Hs/h | bicoherence -> nu : %+.3f\n', pr2);

fprintf('\n  BINNED BY BICOHERENCE:\n');
be = prctile(A.bic, [0 20 40 60 80 100]);
fprintf('  %-16s %7s %10s %12s %10s\n','bic quintile','n','nu ratio','harm excess','Hs/h');
for b = 1:numel(be)-1
    m = A.bic>=be(b) & A.bic<be(b+1);
    if sum(m)<25, continue; end
    fprintf('  %6.3f-%6.3f %7d %10.4f %12.3f %10.4f\n', be(b), be(b+1), sum(m), ...
        median(A.nu(m)), median(A.harm(m)), median(A.hsh(m)));
end

save(fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation','boundary_harmonics.mat'),'A');
fprintf('\n=========== DONE ===========\n\n');

function v = nuf(s,fm,w)
    m0 = sum(s.*w); if m0<=0, v=NaN; return; end
    m1 = sum(fm.*s.*w); m2 = sum(fm.^2.*s.*w);
    v = sqrt(max(m0*m2/m1^2 - 1, 0));
end
