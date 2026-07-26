% RUN_NONLINEARITY_SWEEP  Full-catalog test of the nonlinearity organization.
%
% Answers three questions on every registered instrument-record:
%
%  (14) Does the linear-model spectral discrepancy organize on Hs/h and Ursell
%       rather than depth, catalog-wide? (An 8-deployment subset said yes:
%       partial rho Hs/h|depth = +0.364, depth|Hs/h = +0.148.)
%
%  (15) Does the swell self-interaction bicoherence order the harmonic excess
%       WITHIN fixed Hs/h bands? Pooled, its partial correlation controlling
%       for Hs/h is only +0.121, and bic_swell_self exceeds b95 in 100% of
%       hours, so the significance test cannot discriminate. If bicoherence
%       still orders the excess inside a band, the coupling mechanism is
%       independently supported; if not, the frequency-profile localization is
%       the sole evidence and the claim must rest on that.
%
%  (16) Reconcile r(bound_frac_raw, Hs/h). PUV_Pipeline memory records +0.93 as
%       a correlation of PER-RECORD MEDIANS over a 42-instrument catalog; the
%       per-hour value on 8 deployments was +0.858. Both are computed here so
%       the unit of analysis is explicit rather than inferred.
%
% Two frequency bands are used deliberately:
%   BAND_NU   0.04-0.18 Hz, fixed, below every fCut -- for nu, so a
%             depth-varying cutoff cannot masquerade as a depth trend.
%   BAND_HARM 0.04-min(0.25,fCut) -- for the harmonic profile, because with
%             fp ~ 0.09 Hz the 0.18 ceiling slices 2*fp in half and
%             manufactures a null. Legitimate here: the harmonic metric is a
%             within-hour ratio on identical bins, not a cross-record measure.
%
% Writes outputs/validation/cross_deployment_nonlinearity.mat
%
% Author: Holden Leslie-Bole, 2026

startup_puv
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

registry = deployment_registry();
names    = sort(keys(registry));
pipeRoot = fileparts(fileparts(mfilename('fullpath')));
outDir   = fullfile(pipeRoot,'outputs','validation');
L4root   = fullfile(pipeRoot,'outputs','L4');

BAND_NU = [0.04 0.18];
xEdges  = 0.6:0.2:3.2;  xCent = 0.5*(xEdges(1:end-1)+xEdges(2:end));

H = struct('hsh',[],'ur',[],'nu',[],'en',[],'harm',[],'bic',[],'bfr',[], ...
           'skew',[],'h',[],'rec',[]);
prof = cell(numel(xCent),1); profHi = prof; profLo = prof;
for i=1:numel(xCent), prof{i}=[]; profHi{i}=[]; profLo{i}=[]; end
REC = struct([]);
seen = containers.Map('KeyType','char','ValueType','logical');

fprintf('\n=========== NONLINEARITY SWEEP ===========\n');
t0 = tic; nRec = 0;

for d = 1:numel(names)
    try, cfgFn = registry(names{d}); cfg = cfgFn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true; %#ok<NASGU>
    l2dir = fullfile(cfg.outputDir,'L2',cfg.name);
    if ~isfolder(l2dir), continue; end
    files = dir(fullfile(l2dir,'*_L2.mat'));

    for k = 1:numel(files)
        lab = erase(files(k).name,'_L2.mat');
        f4  = fullfile(L4root, cfg.name, [lab '_L4.mat']);
        if ~isfile(f4), fprintf('  [no L4] %s/%s\n', cfg.name, lab); continue; end
        try
            S2 = load(fullfile(files(k).folder,files(k).name)); L2 = S2.L2;
            S4 = load(f4); L4 = S4.L4;
        catch ME
            fprintf('  [load fail] %s/%s: %s\n', cfg.name, lab, ME.message); continue
        end
        if ~isfield(L4,'boundwave') || ~isfield(L4,'bispectra') || ~isfield(L4,'ref')
            fprintf('  [L4 incomplete] %s/%s\n', cfg.name, lab); continue
        end

        % L4 segment arrays are NOT guaranteed to align with L2 by index, and
        % equal counts do not prove they do -- a rerun can add a segment at the
        % start and drop one at the end. Always match by TIME.
        % See shared/l4_l2_index_map.m.
        [l4map, ainfo] = l4_l2_index_map(L2, L4);
        if ~ainfo.identity
            fprintf('  [align] %s/%s: L4 %d segs vs L2 %d, max index offset %d, matched %d\n', ...
                cfg.name, lab, ainfo.nL4, ainfo.nL2, ainfo.maxOffset, ainfo.nMatched);
        end
        if all(isnan(l4map)), fprintf('  [align failed] %s/%s\n', cfg.name, lab); continue; end

        % Known-dead record: 6 mm median Hs across 2578 "valid" segments at a
        % 30.6 m open-coast site (see PUV_paper findings_resolution_artifact).
        if strcmp(cfg.name,'RUBY22') && contains(lab,'30m')
            fprintf('  [skip] %s/%s: known-dead record\n', cfg.name, lab); continue
        end
        valid = find(L2.segValid);
        if numel(valid) < 20, continue; end
        station = '';
        if isfield(L2,'refStation')&&~isempty(L2.refStation), station = L2.refStation;
        elseif isfield(L2,'mopStation')&&~isempty(L2.mopStation), station = L2.mopStation; end
        if isempty(station), continue; end

        tS = min(L2.time(valid)); tE = max(L2.time(valid));
        if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end
        try, MOP = read_MOPline2(station, tS, tE); catch, continue; end
        if isempty(MOP.time)||isempty(MOP.spec1D), continue; end

        tP = L2.time(valid); if isempty(tP.TimeZone), tP.TimeZone = MOP.time.TimeZone; end
        pick = NaN(numel(MOP.time),1);
        for t = 1:numel(MOP.time)
            [dt,im] = min(abs(tP - MOP.time(t)));
            if dt < minutes(30), pick(t) = valid(im); end
        end
        keep = find(~isnan(pick)); if numel(keep) < 20, continue; end
        idx = pick(keep);

        MOPk = MOP; MOPk.spec1D = MOP.spec1D(keep,:); MOPk.time = MOP.time(keep);
        try, shd = shoal_mop_to_site(MOPk, L2.depth(idx)); catch, continue; end
        fMid = shd.frequency; fbw = shd.fbw; fbounds = shd.fbounds;
        if isempty(fbounds), continue; end
        f = L2.f(:);
        iNU = fMid >= BAND_NU(1) & fMid <= BAND_NU(2);
        if sum(iNU) < 4, continue; end

        nRec = nRec + 1;
        rowHsh=[]; rowNu=[]; rowEn=[]; rowBfr=[]; rowHarm=[]; rowBic=[];

        for i = 1:numel(keep)
            ii = idx(i); h = L2.depth(ii);
            if ~isfinite(h)||h<=0, continue; end
            s = double(L2.S_eta(:,ii)); if all(~isfinite(s)), continue; end
            sbAll = bin_spectrum_to_grid(f, s, fbounds);

            % --- nu on the fixed band
            sb = sbAll(iNU); sb(~isfinite(sb))=0;
            sm = shd.spec(i,:)'; sm = sm(iNU); sm(~isfinite(sm))=0;
            w = fbw(iNU); fm = fMid(iNU);
            m0p = sum(sb.*w); m0m = sum(sm.*w);
            if m0p<=0||m0m<=0, continue; end
            nu_p = nuf(sb,fm,w); nu_m = nuf(sm,fm,w);
            if ~isfinite(nu_p)||~isfinite(nu_m)||nu_m<=0, continue; end

            j4 = l4map(ii);
            if isnan(j4), continue; end
            hshv = L4.ref.Hs_over_h(j4);
            Tp   = L2.Tp(ii); Hs = L2.Hs(ii);
            if ~isfinite(hshv)||~isfinite(Tp)||Tp<=0||~isfinite(Hs), continue; end
            fp = 1/Tp; kk = get_wavenumber(2*pi*fp, h);
            urv = (3/8)*Hs*kk/(kk*h)^3;

            % --- harmonic profile on the wider band
            fc = L2.fCut(ii); if ~isfinite(fc), fc = 0.25; end
            iH = fMid >= 0.04 & fMid <= min(0.25, fc);
            harmv = NaN;
            if sum(iH) >= 6
                sbh = sbAll(iH); sbh(~isfinite(sbh))=0;
                smh = shd.spec(i,:)'; smh = smh(iH); smh(~isfinite(smh))=0;
                if sum(sbh)>0 && sum(smh)>0
                    x = fMid(iH)/fp;
                    rat = sbh./max(smh,eps);
                    good = isfinite(rat)&rat>0&smh>0.01*max(smh);
                    for b = 1:numel(xCent)
                        mb = good & x>=xEdges(b) & x<xEdges(b+1);
                        if ~any(mb), continue; end
                        vv = median(rat(mb));
                        prof{b}(end+1) = vv;
                        if hshv>0.12, profHi{b}(end+1)=vv; else, profLo{b}(end+1)=vv; end
                    end
                    mPk = good & x>=0.8 & x<=1.2;
                    mHa = good & x>=1.6 & x<=2.4;
                    if any(mPk)&&any(mHa), harmv = median(rat(mHa))/median(rat(mPk)); end
                end
            end

            H.hsh(end+1,1)=hshv;  H.ur(end+1,1)=urv;
            H.nu(end+1,1)=nu_p/nu_m; H.en(end+1,1)=m0m/m0p;
            H.harm(end+1,1)=harmv;
            H.bic(end+1,1)=L4.bispectra.bic_swell_self(j4);
            H.bfr(end+1,1)=L4.boundwave.bound_frac_raw(j4);
            H.skew(end+1,1)=L4.bispectra.skewness(j4);
            H.h(end+1,1)=h;  H.rec(end+1,1)=nRec;

            rowHsh(end+1)=hshv; rowNu(end+1)=nu_p/nu_m; rowEn(end+1)=m0m/m0p; %#ok<AGROW>
            rowBfr(end+1)=L4.boundwave.bound_frac_raw(j4); %#ok<AGROW>
            rowHarm(end+1)=harmv; rowBic(end+1)=L4.bispectra.bic_swell_self(j4); %#ok<AGROW>
        end

        if numel(rowHsh) < 20, nRec = nRec - 1; continue; end
        r.deployment=cfg.name; r.label=lab; r.n=numel(rowHsh);
        r.h=median(L2.depth(idx),'omitnan');
        r.hsh=median(rowHsh,'omitnan');   r.nu=median(rowNu,'omitnan');
        r.en=median(rowEn,'omitnan');     r.bfr=median(rowBfr,'omitnan');
        r.harm=median(rowHarm,'omitnan'); r.bic=median(rowBic,'omitnan');
        if isempty(REC), REC=r; else, REC(end+1)=orderfields(r,REC); end %#ok<AGROW>
        fprintf('  %-9s %-13s h=%5.1f n=%4d  Hs/h %.3f  nu %.3f  bfr %.3f  harm %.3f\n', ...
            cfg.name, lab, r.h, r.n, r.hsh, r.nu, r.bfr, r.harm);
    end
end

fprintf('\n%d records, %d hours, %.1f min\n', numel(REC), numel(H.hsh), toc(t0)/60);

%% ===================== (14) ORGANIZATION =====================
fprintf('\n===== (14) DOES IT ORGANIZE ON NONLINEARITY? (full catalog) =====\n');
fprintf('  %-14s %12s %12s\n','predictor','rho(nu)','rho(energy)');
P = {'depth h',H.h; 'Hs/h',H.hsh; 'Ursell',H.ur};
for j=1:size(P,1)
    m1 = isfinite(P{j,2})&isfinite(H.nu); [r1,p1]=corr(P{j,2}(m1),H.nu(m1),'type','Spearman');
    m2 = isfinite(P{j,2})&isfinite(H.en); [r2,p2]=corr(P{j,2}(m2),H.en(m2),'type','Spearman');
    fprintf('  %-14s %+11.3f%s %+11.3f%s\n', P{j,1}, r1, star(p1), r2, star(p2));
end
m = isfinite(H.hsh)&isfinite(H.nu)&isfinite(H.h);
fprintf('\n  PARTIAL with nu:  Hs/h|depth = %+.3f   depth|Hs/h = %+.3f\n', ...
    partialcorr(H.hsh(m),H.nu(m),H.h(m),'type','Spearman'), ...
    partialcorr(H.h(m),H.nu(m),H.hsh(m),'type','Spearman'));

edges=[0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
fprintf('\n  %-14s %8s %10s %10s %12s %10s\n','Hs/h','n','nu','energy','bound_raw','harm');
for b=1:numel(edges)-1
    mb = H.hsh>=edges(b)&H.hsh<edges(b+1);
    if sum(mb)<50, continue; end
    fprintf('  %5.2f - %5.2f %8d %10.4f %10.4f %12.3f %10.3f\n', edges(b),edges(b+1),sum(mb), ...
        median(H.nu(mb),'omitnan'), median(H.en(mb),'omitnan'), ...
        median(H.bfr(mb),'omitnan'), median(H.harm(mb),'omitnan'));
end

fprintf('\n  HARMONIC PROFILE (PUV/model vs f/fp):\n');
fprintf('  %-12s %9s %9s %11s %11s\n','f/fp','n','all','Hs/h<0.12','Hs/h>0.12');
for b=1:numel(xCent)
    if numel(prof{b})<100, continue; end
    lo=NaN; hi=NaN;
    if numel(profLo{b})>50, lo=median(profLo{b}); end
    if numel(profHi{b})>50, hi=median(profHi{b}); end
    fprintf('  %5.1f-%5.1f %9d %9.3f %11.3f %11.3f\n', xEdges(b),xEdges(b+1), ...
        numel(prof{b}), median(prof{b}), lo, hi);
end

%% ===================== (15) BICOHERENCE WITHIN BANDS =====================
fprintf('\n===== (15) DOES BICOHERENCE ORDER THE EXCESS WITHIN Hs/h BANDS? =====\n');
bands = [0.04 0.06; 0.06 0.08; 0.08 0.10; 0.10 0.12; 0.12 0.15; 0.15 0.20; 0.20 1.0];
fprintf('  %-14s %7s %14s %14s %12s\n','Hs/h band','n','rho(bic,harm)','rho(bic,nu)','bic Q1->Q5 harm');
for b = 1:size(bands,1)
    mb = H.hsh>=bands(b,1)&H.hsh<bands(b,2)&isfinite(H.harm)&isfinite(H.bic);
    if sum(mb)<100, continue; end
    [r1,p1]=corr(H.bic(mb),H.harm(mb),'type','Spearman');
    mn = H.hsh>=bands(b,1)&H.hsh<bands(b,2)&isfinite(H.nu)&isfinite(H.bic);
    [r2,~]=corr(H.bic(mn),H.nu(mn),'type','Spearman');
    q = prctile(H.bic(mb),[20 80]);
    lowH = median(H.harm(mb & H.bic<=q(1)),'omitnan');
    hiH  = median(H.harm(mb & H.bic>=q(2)),'omitnan');
    fprintf('  %4.2f - %4.2f %8d %+13.3f%s %+13.3f %6.3f -> %.3f\n', ...
        bands(b,1),bands(b,2),sum(mb), r1, star(p1), r2, lowH, hiH);
end
fprintf('  A consistently positive within-band rho means bicoherence carries\n');
fprintf('  information beyond Hs/h. Near zero means it does not.\n');

%% ===================== (16) RECONCILE +0.93 =====================
fprintf('\n===== (16) r(bound_frac_raw, Hs/h): UNIT OF ANALYSIS =====\n');
mh = isfinite(H.bfr)&isfinite(H.hsh);
[rh,ph] = corr(H.hsh(mh),H.bfr(mh),'type','Spearman');
[rhp,~] = corr(H.hsh(mh),H.bfr(mh),'type','Pearson');
rb = [REC.bfr]'; rr = [REC.hsh]';
mr = isfinite(rb)&isfinite(rr);
[rm,pm] = corr(rr(mr),rb(mr),'type','Spearman');
[rmp,~] = corr(rr(mr),rb(mr),'type','Pearson');
fprintf('  per-HOUR pooled   (n=%6d): Spearman %+.3f  Pearson %+.3f\n', sum(mh), rh, rhp);
fprintf('  per-RECORD median (n=%6d): Spearman %+.3f  Pearson %+.3f\n', sum(mr), rm, rmp);
fprintf('\n  PUV_Pipeline memory records +0.93 for "r(median raw ratio, Hs/h)"\n');
fprintf('  over a 42-instrument catalog -- i.e. the per-RECORD row above.\n');

meta = struct('created',datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
              'nRecords',numel(REC),'nHours',numel(H.hsh), ...
              'band_nu',BAND_NU,'note', ...
              'Full-catalog nonlinearity organization, bicoherence-within-band, bound_frac reconciliation'); %#ok<TNOW1,DATST>
save(fullfile(outDir,'cross_deployment_nonlinearity.mat'), ...
     'H','REC','prof','profHi','profLo','xCent','xEdges','meta','-v7.3');
fprintf('\nSaved: %s\n\n', fullfile(outDir,'cross_deployment_nonlinearity.mat'));

function v = nuf(s,fm,w)
    m0=sum(s.*w); if m0<=0, v=NaN; return; end
    m1=sum(fm.*s.*w); m2=sum(fm.^2.*s.*w);
    v=sqrt(max(m0*m2/m1^2-1,0));
end
function s = star(p), if p<0.001, s='***'; elseif p<0.05, s='*  '; else, s='   '; end, end
