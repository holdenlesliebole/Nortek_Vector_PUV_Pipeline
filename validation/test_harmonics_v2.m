% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% TEST 2 REDONE -- the first version's harmonic band was truncated.
%
% With fp ~ 0.09 Hz, 2*fp ~ 0.18 Hz sits exactly at the 0.18 Hz band ceiling
% used for the nu comparisons, so the harmonic band [1.6fp, 2.4fp] =
% [0.144, 0.216] Hz was cut roughly in half and the "no localization" result
% (0.989) may have been manufactured by that choice.
%
% Here the band runs to min(0.25, fCut) so 2*fp is fully inside it. The fCut
% confound that motivated the 0.18 cap does not apply: this is a WITHIN-HOUR
% ratio of two spectra on identical bins, not a cross-record comparison.
%
% Also resolves the frequency structure directly: the median PUV/model ratio
% as a function of f/fp. If super-harmonics are the mechanism there must be a
% bump near f/fp = 2.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

L2root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';
L4root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L4';
cases = { 'TOR24S','MOP586_5m'; 'TBR23','MOP586_5m'; 'TOR23W','MOP580_5m'
          'TBR23','MOP586_7m';  'IB18W','MOP045_7m'; 'SOL25B','MOP654_7m'
          'TOR23W','MOP586_10m';'TOR24W','MOP586_15m' };

% ratio profile accumulator on an f/fp axis
xEdges = 0.6:0.2:3.2; xCent = 0.5*(xEdges(1:end-1)+xEdges(2:end));
prof = cell(numel(xCent),1); for i=1:numel(xCent), prof{i}=[]; end
profHi = prof; profLo = prof;     % split by Hs/h

A = struct('hsh',[],'bic',[],'harm',[],'nu',[],'skew',[]);

fprintf('\n=========== TEST 2 v2: HARMONIC LOCALIZATION ===========\n');
for c = 1:size(cases,1)
    f2 = fullfile(L2root, cases{c,1}, [cases{c,2} '_L2.mat']);
    f4 = fullfile(L4root, cases{c,1}, [cases{c,2} '_L4.mat']);
    if ~isfile(f2)||~isfile(f4), continue; end
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
    keep = find(~isnan(pick)); if numel(keep)<20, continue; end
    idx = pick(keep);

    MOPk = MOP; MOPk.spec1D = MOP.spec1D(keep,:); MOPk.time = MOP.time(keep);
    shd = shoal_mop_to_site(MOPk, L2.depth(idx));
    fMid = shd.frequency; fbounds = shd.fbounds; f = L2.f(:);

    for i = 1:numel(keep)
        ii = idx(i);
        s = double(L2.S_eta(:,ii)); if all(~isfinite(s)), continue; end
        fc = L2.fCut(ii); if ~isfinite(fc), fc = 0.25; end
        hi = min(0.25, fc);
        iB = fMid >= 0.04 & fMid <= hi;
        if sum(iB) < 6, continue; end

        sb = bin_spectrum_to_grid(f, s, fbounds); sbB = sb(iB); sbB(~isfinite(sbB))=0;
        smB = shd.spec(i,:)'; smB = smB(iB); smB(~isfinite(smB))=0;
        fm = fMid(iB);
        if sum(sbB)<=0 || sum(smB)<=0, continue; end

        Tp = L2.Tp(ii); if ~isfinite(Tp)||Tp<=0, continue; end
        fp = 1/Tp;
        x = fm/fp;
        rat = sbB ./ max(smB, eps);
        good = isfinite(rat) & rat>0 & smB > 0.01*max(smB);   % ignore near-zero model bins

        hshv = L4.ref.Hs_over_h(ii);
        for b = 1:numel(xCent)
            m = good & x>=xEdges(b) & x<xEdges(b+1);
            if ~any(m), continue; end
            v = median(rat(m));
            prof{b}(end+1) = v;
            if hshv > 0.12, profHi{b}(end+1) = v; else, profLo{b}(end+1) = v; end
        end

        mPk = good & x>=0.8 & x<=1.2;
        mHa = good & x>=1.6 & x<=2.4;
        if any(mPk) && any(mHa)
            A.harm(end+1,1) = median(rat(mHa))/median(rat(mPk));
            A.hsh(end+1,1)  = hshv;
            A.bic(end+1,1)  = L4.bispectra.bic_swell_self(ii);
            A.skew(end+1,1) = L4.bispectra.skewness(ii);
            A.nu(end+1,1)   = NaN;
        end
    end
    fprintf('  %-9s %-12s  n=%d\n', cases{c,1}, cases{c,2}, numel(A.harm));
end

fprintf('\n  PUV/model energy ratio vs f/fp  (a harmonic bump would show at 2.0)\n');
fprintf('  %-12s %8s %10s %10s %10s\n','f/fp','n','all','Hs/h<0.12','Hs/h>0.12');
for b = 1:numel(xCent)
    if numel(prof{b}) < 50, continue; end
    lo = NaN; hi2 = NaN;
    if numel(profLo{b})>25, lo = median(profLo{b}); end
    if numel(profHi{b})>25, hi2 = median(profHi{b}); end
    fprintf('  %5.1f-%5.1f %8d %10.3f %10.3f %10.3f\n', xEdges(b), xEdges(b+1), ...
        numel(prof{b}), median(prof{b}), lo, hi2);
end

fprintf('\n  harmonic excess (2fp band / peak band): median %.3f  (n=%d)\n', ...
    median(A.harm), numel(A.harm));
m = isfinite(A.harm)&isfinite(A.bic);
[r1,p1] = corr(A.bic(m), A.harm(m), 'type','Spearman');
[r2,p2] = corr(A.hsh(m), A.harm(m), 'type','Spearman');
[r3,p3] = corr(A.skew(m),A.harm(m), 'type','Spearman');
fprintf('  rho(bicoherence, harmonic excess) = %+.3f (p=%.2g)\n', r1, p1);
fprintf('  rho(Hs/h,        harmonic excess) = %+.3f (p=%.2g)\n', r2, p2);
fprintf('  rho(skewness,    harmonic excess) = %+.3f (p=%.2g)\n', r3, p3);
pr = partialcorr(A.bic(m), A.harm(m), A.hsh(m), 'type','Spearman');
fprintf('  PARTIAL bicoherence | Hs/h -> harmonic excess : %+.3f\n', pr);

fprintf('\n  binned by Hs/h:\n  %-14s %8s %12s\n','Hs/h','n','harm excess');
he = [0 0.06 0.08 0.10 0.12 0.15 0.20 1];
for b=1:numel(he)-1
    mm = A.hsh>=he(b)&A.hsh<he(b+1);
    if sum(mm)<25, continue; end
    fprintf('  %5.2f - %5.2f %8d %12.3f\n', he(b), he(b+1), sum(mm), median(A.harm(mm)));
end

save(fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation','harmonics_v2.mat'),'A','prof','profHi','profLo','xCent','xEdges');
fprintf('\n=========== DONE ===========\n\n');
