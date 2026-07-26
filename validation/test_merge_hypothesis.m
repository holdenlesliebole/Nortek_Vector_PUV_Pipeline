% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% THE MERGE TEST
%
% Question: does the model-observation discrepancy organize on Hs/h or Ursell
% (nonlinearity) rather than on depth? If the spectral discrepancy turns on near
% the same Hs/h ~ 0.10 where second-order bound-wave theory starts over-
% predicting, then the wave-model-validation and wave-nonlinearity papers are
% two probes of ONE boundary and merging has a spine. If it does not organize
% on Hs/h, they share an instrument and nothing else.
%
% Two parts:
%   A) per-record (n = 61, uses the saved sweeps) -- cheap, coarse
%   B) per-HOUR pooled across a depth/exposure-spanning subset -- the real test,
%      because per-record medians wash out exactly the energetic hours where
%      the boundary is crossed.
%
% Ursell (Ruessink et al. 2012):  Ur = (3/8) * Hs * k / (k h)^3, k at the peak.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

L2root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';
valDir = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/validation';

%% ================= PART A: per-record =================================
S1 = load(fullfile(valDir,'cross_deployment_matched_shape.mat'));
R1 = S1.ROWS;
k1 = arrayfun(@(r)[r.deployment '/' r.label], R1, 'UniformOutput', false);
[~,ia] = unique(k1,'stable'); R1 = R1(ia);
bad = strcmp({R1.deployment},'RUBY22') & contains({R1.label},'30m');
R1 = R1(~bad);

fprintf('\n================ PART A: per-record (n = %d) ================\n', numel(R1));

n = numel(R1);
hh = [R1.h_median]'; nur = [R1.nu_ratio]'; qpr = [R1.Qp_ratio]';
hsh = NaN(n,1); hsh90 = NaN(n,1); ur = NaN(n,1);

for i = 1:n
    fn = fullfile(L2root, R1(i).deployment, [R1(i).label '_L2.mat']);
    if ~isfile(fn), continue; end
    S = load(fn); L2 = S.L2; v = L2.segValid;
    Hs = L2.Hs(v); h = L2.depth(v); Tp = L2.Tp(v);
    g = isfinite(Hs)&isfinite(h)&h>0;
    hsh(i)   = median(Hs(g)./h(g));
    hsh90(i) = prctile(Hs(g)./h(g), 90);
    kk = get_wavenumber(2*pi./Tp(g), median(h(g)));
    ur(i) = median( (3/8) * Hs(g) .* kk(:) ./ (kk(:)*median(h(g))).^3 );
end

fprintf('  Hs/h  median across records: %.4f  (range %.4f - %.4f)\n', ...
    median(hsh,'omitnan'), min(hsh), max(hsh));
fprintf('  Hs/h  90th pct: %.4f - %.4f\n', min(hsh90), max(hsh90));
fprintf('  Ursell median: %.3f (range %.3f - %.3f)\n', median(ur,'omitnan'), min(ur), max(ur));

fprintf('\n  %-16s %10s %10s %10s\n','predictor','rho(nu)','rho(Qp)','n');
preds = {'depth h', hh; 'Hs/h (median)', hsh; 'Hs/h (90th pct)', hsh90; 'Ursell', ur};
for j = 1:size(preds,1)
    m = isfinite(preds{j,2}) & isfinite(nur);
    [r1,p1] = corr(preds{j,2}(m), nur(m), 'type','Spearman');
    m2 = isfinite(preds{j,2}) & isfinite(qpr);
    [r2,~]  = corr(preds{j,2}(m2), qpr(m2), 'type','Spearman');
    fprintf('  %-16s %+9.3f%s %+10.3f %10d\n', preds{j,1}, r1, star(p1), r2, sum(m));
end

%% ================= PART B: per-hour, pooled ============================
cases = { 'TOR24S','MOP586_5m'; 'TBR23','MOP586_5m'; 'TOR23W','MOP580_5m'
          'TBR23','MOP586_7m';  'IB18W','MOP045_7m'; 'SOL25B','MOP654_7m'
          'TOR23W','MOP586_10m';'TOR24W','MOP586_15m' };

fprintf('\n================ PART B: per-hour pooled ================\n');
ALL = struct('hsh',[],'ur',[],'nu',[],'en',[],'sh',[],'h',[],'dep',{{}});

for c = 1:size(cases,1)
    fn = fullfile(L2root, cases{c,1}, [cases{c,2} '_L2.mat']);
    if ~isfile(fn), continue; end
    S = load(fn); L2 = S.L2; valid = find(L2.segValid);
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
    sh = shoal_mop_to_site(MOPk, L2.depth(idx));
    fMid = sh.frequency; fbw = sh.fbw; fbounds = sh.fbounds;
    f = L2.f(:); fSS = L2.params.fSS;
    fCut = median(L2.fCut(idx),'omitnan'); if ~isfinite(fCut), fCut = fSS(2); end
    % FIXED band, below every cutoff, so the band cannot masquerade as a trend
    iB = fMid >= fSS(1) & fMid <= 0.18;
    if sum(iB) < 4, continue; end

    nK = numel(keep);
    for i = 1:nK
        s = double(L2.S_eta(:,idx(i))); if all(~isfinite(s)), continue; end
        h = L2.depth(idx(i)); if ~isfinite(h)||h<=0, continue; end
        sb = bin_spectrum_to_grid(f, s, fbounds); sb = sb(iB); sb(~isfinite(sb))=0;
        sm = sh.spec(i,:)'; sm = sm(iB); sm(~isfinite(sm))=0;
        w = fbw(iB); fm = fMid(iB);
        m0p = sum(sb.*w); m0m = sum(sm.*w);
        if m0p<=0 || m0m<=0, continue; end

        nu_p = nuf(sb,fm,w); nu_m = nuf(sm,fm,w);
        if ~isfinite(nu_p)||~isfinite(nu_m)||nu_m<=0, continue; end

        Hs_i = L2.Hs(idx(i)); Tp_i = L2.Tp(idx(i));
        if ~isfinite(Hs_i)||~isfinite(Tp_i)||Tp_i<=0, continue; end
        kk = get_wavenumber(2*pi/Tp_i, h);

        ALL.hsh(end+1,1) = Hs_i/h;
        ALL.ur(end+1,1)  = (3/8)*Hs_i*kk/(kk*h)^3;
        ALL.nu(end+1,1)  = nu_p/nu_m;
        ALL.en(end+1,1)  = m0m/m0p;                 % model/obs energy
        ALL.h(end+1,1)   = h;
        ALL.dep{end+1,1} = cases{c,1};
    end
    fprintf('  %-9s %-12s h=%5.1f  hours pooled so far: %d\n', ...
        cases{c,1}, cases{c,2}, median(L2.depth(idx),'omitnan'), numel(ALL.hsh));
end

N = numel(ALL.hsh);
fprintf('\n  pooled hours n = %d,  Hs/h range %.4f - %.4f\n', N, min(ALL.hsh), max(ALL.hsh));

fprintf('\n  %-18s %10s %10s\n','predictor','rho(nu)','rho(energy)');
P = {'depth h', ALL.h; 'Hs/h', ALL.hsh; 'Ursell', ALL.ur};
for j = 1:size(P,1)
    m = isfinite(P{j,2}) & isfinite(ALL.nu);
    [r1,p1] = corr(P{j,2}(m), ALL.nu(m), 'type','Spearman');
    m2 = isfinite(P{j,2}) & isfinite(ALL.en);
    [r2,p2] = corr(P{j,2}(m2), ALL.en(m2), 'type','Spearman');
    fprintf('  %-18s %+9.3f%s %+9.3f%s\n', P{j,1}, r1, star(p1), r2, star(p2));
end

% Partial: does Hs/h survive controlling for depth, and vice versa?
m = isfinite(ALL.hsh)&isfinite(ALL.nu)&isfinite(ALL.h);
pr1 = partialcorr(ALL.hsh(m), ALL.nu(m), ALL.h(m), 'type','Spearman');
pr2 = partialcorr(ALL.h(m),   ALL.nu(m), ALL.hsh(m),'type','Spearman');
fprintf('\n  PARTIAL correlations with nu:\n');
fprintf('    Hs/h  controlling for depth : %+0.3f\n', pr1);
fprintf('    depth controlling for Hs/h  : %+0.3f\n', pr2);
fprintf('    -> whichever survives is the organizing variable.\n');

% Threshold behaviour: bin by Hs/h and look for a knee near 0.10
edges = [0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
fprintf('\n  BINNED BY Hs/h (the second-order breakdown is claimed at ~0.10):\n');
fprintf('  %-14s %7s %10s %10s\n','Hs/h bin','n','nu ratio','energy');
for b = 1:numel(edges)-1
    m = ALL.hsh>=edges(b) & ALL.hsh<edges(b+1);
    if sum(m) < 25, continue; end
    fprintf('  %5.2f - %5.2f %7d %10.4f %10.4f\n', edges(b), edges(b+1), ...
        sum(m), median(ALL.nu(m)), median(ALL.en(m)));
end

save(fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation','merge_test.mat'),'ALL','hsh','hsh90','ur','hh','nur','qpr');
fprintf('\n================ DONE ================\n\n');

function v = nuf(s,fm,w)
    m0 = sum(s.*w); if m0<=0, v=NaN; return; end
    m1 = sum(fm.*s.*w); m2 = sum(fm.^2.*s.*w);
    v = sqrt(max(m0*m2/m1^2 - 1, 0));
end
function s = star(p), if p<0.001, s='***'; elseif p<0.05, s='*  '; else, s='   '; end, end
