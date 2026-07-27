% DIAGNOSE_SXY_HEADING  Are the negative-Sxy records L1 heading flips?
%
% 10 of 61 records showed a NEGATIVE PUV-vs-model correlation in alongshore
% radiation stress Sxy. A same-transect contrast (MOP586_10m: +0.91 / +0.89 /
% -0.63 / +0.76 across four deployments) exonerated the rotation and localized
% the problem per-deployment.
%
% MECHANISM. A 180-degree L1 heading error flips the shore-normal velocity,
% u_sn -> -u_sn. Under that flip:
%     a1 = Re(Spu)/...        -> FLIPS SIGN
%     b1 = Re(Spv)/...        -> unchanged
%     a2 = (Suu-Svv)/...      -> unchanged  (u enters squared)
%     b2 = 2*Re(Suv)/...      -> FLIPS SIGN
% and Sxy = rho*g*int S*n*(b2/2) df, so Sxy flips too. A heading flip is
% therefore an exact match for the observed signature.
%
% This bug class has already been caught twice in this pipeline by a different
% route -- per-band reflection R^2 (R2_swell >> R2_IG), which found a 180-degree
% spreadsheet typo at TBR23/MOP580_5m and a miscalibrated auto-compass at
% TOR24S/MOP586_7m. Both were fixed. None of the 10 records flagged here is one
% of those, so these would be additional cases.
%
% THREE INDEPENDENT PROBES, all computed per record:
%   1. sign of a1 at the spectral peak. Shoaling waves carry energy onshore, and
%      the pipeline's a1 is referenced to the onshore direction, so a1 > 0 is
%      required. a1 < 0 means u_sn points offshore -- a flip.
%   2. per-band reflection R^2 (the known diagnostic). R2_swell >> R2_IG is the
%      established smoking gun; IG cannot see the flip because bound waves make
%      eta-u phase non-zero there.
%   3. PUV-vs-model mean wave direction offset. A heading error is a roughly
%      CONSTANT angular offset; genuine local refraction varies with incident
%      direction. Reported as circular mean and spread.
%
% Agreement among all three is confirmation. Disagreement means the cause is
% something else and the records should not be silently "corrected".
%
% Author: Holden Leslie-Bole, 2026

startup_puv
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

pipeRoot = fileparts(fileparts(mfilename('fullpath')));
outDir   = fullfile(pipeRoot,'outputs','validation');
L4root   = fullfile(pipeRoot,'outputs','L4');

% the records flagged by run_consequences_sweep (Sxy_R < 0)
flagged = { 'COR16B','MOP158_9m'; 'IB18W','MOP045_7m'; 'IB19W','MOP045_6m'
            'RUBY22','MOP578_10m'; 'RUBY22','MOP579_6m'; 'SOL24','MOP654_7m'
            'TOR14C','MOP591_9m'; 'TOR17B','MOP591_9m'; 'TOR24W','MOP586_10m'
            'TOR24W','MOP586_15m' };

registry = deployment_registry(); names = sort(keys(registry));
seen = containers.Map('KeyType','char','ValueType','logical');

fprintf('\n============ Sxy / HEADING DIAGNOSIS ============\n');
fprintf('%-9s %-13s %5s %9s %9s %9s %9s %10s %6s\n', ...
    'deploy','label','flag','a1@peak','R2_IG','R2_swell','dDir(med)','dDir(IQR)','verdict');

R = struct([]);
for d = 1:numel(names)
    try, fn = registry(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true; %#ok<NASGU>
    fl = dir(fullfile(cfg.outputDir,'L2',cfg.name,'*_L2.mat'));

    for k = 1:numel(fl)
        lab = erase(fl(k).name,'_L2.mat');
        if strcmp(cfg.name,'RUBY22') && contains(lab,'30m'), continue; end
        S2 = load(fullfile(fl(k).folder,fl(k).name)); L2 = S2.L2;
        v = find(L2.segValid);
        if numel(v) < 20, continue; end
        if ~isfield(L2,'a1') || isempty(L2.a1), continue; end

        isFlag = any(strcmp(cfg.name,flagged(:,1)) & strcmp(lab,flagged(:,2)));

        % ---- probe 1: sign of a1 at the spectral peak
        f = L2.f(:); fSS = L2.params.fSS;
        iSS = f>=fSS(1) & f<=fSS(2);
        a1pk = NaN(numel(v),1);
        for i = 1:numel(v)
            s = double(L2.S_eta(iSS, v(i)));
            a = double(L2.a1(iSS, v(i)));
            if all(~isfinite(s)), continue; end
            [~,ip] = max(s);
            a1pk(i) = a(ip);
        end
        a1med = median(a1pk,'omitnan');

        % ---- probe 2: per-band reflection R^2
        R2ig = NaN; R2sw = NaN;
        f4 = fullfile(L4root, cfg.name, [lab '_L4.mat']);
        if isfile(f4)
            S4 = load(f4,'L4');
            if isfield(S4.L4,'ref')
                rf = S4.L4.ref;
                if isfield(rf,'R2_IG'), R2ig = median(rf.R2_IG(isfinite(rf.R2_IG)),'omitnan'); end
                if isfield(rf,'byBand')
                    bb = rf.byBand;
                    fn2 = fieldnames(bb);
                    for q = 1:numel(fn2)
                        if contains(lower(fn2{q}),'swell')
                            x = bb.(fn2{q});
                            if isstruct(x) && isfield(x,'R2'), x = x.R2; end
                            if isnumeric(x), R2sw = median(x(isfinite(x)),'omitnan'); end
                        end
                    end
                end
            end
        end

        % ---- probe 3: PUV vs model mean direction offset (shore-relative)
        dDirMed = NaN; dDirIqr = NaN;
        station = '';
        if isfield(L2,'refStation')&&~isempty(L2.refStation), station=L2.refStation;
        elseif isfield(L2,'mopStation')&&~isempty(L2.mopStation), station=L2.mopStation; end
        if ~isempty(station)
            try
                tS=min(L2.time(v)); tE=max(L2.time(v));
                if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end
                MOP = read_MOPline2(station,tS,tE);
                if ~isempty(MOP.time) && isfield(MOP,'a1') && ~isempty(MOP.a1)
                    tP=L2.time(v); if isempty(tP.TimeZone), tP.TimeZone=MOP.time.TimeZone; end
                    nM=numel(MOP.time); dd=NaN(nM,1);
                    fM=double(MOP.frequency(:));
                    al = deg2rad(double(MOP.shorenormal));
                    for t=1:nM
                        [dt,im]=min(abs(tP-MOP.time(t)));
                        if dt>=minutes(30), continue; end
                        ii=v(im);
                        sM=double(MOP.spec1D(t,:))'; if all(~isfinite(sM)), continue; end
                        [~,ipM]=max(sM);
                        aM=double(MOP.a1(t,ipM)); bM=double(MOP.b1(t,ipM));
                        % geographic -> shore-relative (first moments rotate by alpha)
                        aMr =  aM*cos(al) + bM*sin(al);
                        bMr = -aM*sin(al) + bM*cos(al);
                        dirM = atan2d(bMr, aMr);

                        sP=double(L2.S_eta(iSS,ii)); aP=double(L2.a1(iSS,ii)); bP=double(L2.b1(iSS,ii));
                        if all(~isfinite(sP)), continue; end
                        [~,ipP]=max(sP);
                        dirP = atan2d(bP(ipP), aP(ipP));
                        dd(t) = wrapTo180(dirP - dirM);
                    end
                    g=isfinite(dd);
                    if sum(g)>20
                        dDirMed = rad2deg(angle(mean(exp(1i*deg2rad(dd(g))))));
                        dDirIqr = prctile(dd(g),75)-prctile(dd(g),25);
                    end
                end
            catch
            end
        end

        % ---- verdict
        flip = a1med < 0;
        vtxt = '';
        if flip, vtxt = 'FLIP'; elseif isFlag, vtxt = '??'; end
        fprintf('%-9s %-13s %5s %9.3f %9.2f %9.2f %9.1f %10.1f %6s\n', ...
            cfg.name, lab, tern(isFlag,'NEG',''), a1med, R2ig, R2sw, dDirMed, dDirIqr, vtxt);

        r.dep=cfg.name; r.lab=lab; r.isFlag=isFlag; r.a1=a1med;
        r.R2ig=R2ig; r.R2sw=R2sw; r.dDir=dDirMed; r.dDirIqr=dDirIqr; r.flip=flip;
        if isempty(R), R=r; else, R(end+1)=orderfields(r,R); end %#ok<AGROW>
    end
end

%% ---- cross-tabulate
fprintf('\n============ CROSS-TABULATION ============\n');
isFlag=[R.isFlag]'; flip=[R.flip]';
fprintf('  records: %d   Sxy-negative: %d   a1<0 (flip): %d\n', numel(R), sum(isFlag), sum(flip));
fprintf('\n  %-24s %8s %8s\n','','a1<0','a1>0');
fprintf('  %-24s %8d %8d\n','Sxy negative', sum(isFlag&flip), sum(isFlag&~flip));
fprintf('  %-24s %8d %8d\n','Sxy positive', sum(~isFlag&flip), sum(~isFlag&~flip));

if sum(isFlag&flip)==sum(isFlag) && sum(~isFlag&flip)==0
    fprintf('\n  PERFECT AGREEMENT: every Sxy-negative record has a1<0 and no other does.\n');
    fprintf('  -> the negative Sxy IS the heading flip. Data-quality issue, not physics.\n');
elseif sum(isFlag&flip)>0
    fprintf('\n  PARTIAL agreement -- %d of %d Sxy-negative records have a1<0.\n', sum(isFlag&flip), sum(isFlag));
    fprintf('  The rest need a different explanation; do not correct them blindly.\n');
else
    fprintf('\n  NO agreement: a1 sign does not explain the negative Sxy.\n');
    fprintf('  The heading hypothesis is FALSIFIED; look elsewhere.\n');
end

fprintf('\n  direction offset for Sxy-negative records (heading error => near-constant):\n');
for i=1:numel(R)
    if R(i).isFlag
        fprintf('    %-9s %-13s dDir = %+7.1f deg (IQR %5.1f)\n', R(i).dep, R(i).lab, R(i).dDir, R(i).dDirIqr);
    end
end

save(fullfile(outDir,'sxy_heading_diagnosis.mat'),'R');
fprintf('\nSaved: %s\n\n', fullfile(outDir,'sxy_heading_diagnosis.mat'));

function s=tern(c,a,b), if c, s=a; else, s=b; end, end
