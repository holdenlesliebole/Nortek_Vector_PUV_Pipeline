% SWEEP_HEADING_FLIPS  Catalog-wide search for 180-degree instrument-heading errors.
%
% READ-ONLY. Diagnoses only; the fix is a separate, confirmed step.
%
% WHY THIS BUG RECURS. A Nortek Vector is close to rotationally symmetric apart
% from subtle cues, so a diver working in poor visibility or swell can mount it
% 180 degrees off without it being obvious. The config either records an explicit
% heading (which can carry a spreadsheet typo) or leaves heading = NaN and
% auto-computes from the onboard compass (which can be miscalibrated). All three
% routes produce the same signature.
%
% THE SIGNATURE. A 180-degree error flips the shore-normal velocity, u_sn -> -u_sn.
% Because a1 = Re(Spu)/sqrt(Spp*Spp_uv) is the normalised real part of the
% pressure-velocity cross-spectrum, a1 IS the eta-u phase diagnostic in
% normalised form:
%       a1 > 0  <=>  eta-u phase near 0 deg    (shoreward energy, physical)
%       a1 < 0  <=>  eta-u phase near 180 deg  (the flip)
% For free shoaling waves in the swell band eta and u_sn are highly coherent
% (0.7-0.93), so a1 there is decisive. IG cannot see it: bound waves make the
% eta-u phase non-zero, which is why IG-only reflection analysis missed the two
% cases found in May 2026.
%
% FOUR PROBES per record:
%   1. energy-weighted mean a1 over the swell band, median over segments  [primary]
%   2. fraction of valid segments with negative swell-band a1             [catches
%      partial flips, e.g. an instrument disturbed mid-deployment]
%   3. a1 at the spectral peak
%   4. per-band reflection R^2 -- R2_swell >> R2_IG is the previously established
%      smoking gun (catalog median R2_swell ~ 0.008; confirmed flips ran 87-150)
%
% Thresholds are reported against the catalog distribution rather than asserted,
% so the classification can be checked rather than trusted.
%
% Known prior cases (both FIXED May 2026 -- expect these to come back CLEAN):
%   TBR23/MOP580_5m   heading 270.7361 -> 90.7361  (spreadsheet typo)
%   TOR24S/MOP586_7m  auto 258.7 -> explicit 78.7  (miscalibrated compass)
%
% Author: Holden Leslie-Bole, 2026

startup_puv

pipeRoot = fileparts(fileparts(mfilename('fullpath')));
outDir   = fullfile(pipeRoot,'outputs','validation');
L4root   = fullfile(pipeRoot,'outputs','L4');

BAND_SWELL = [0.04 0.14];      % highest eta-u coherence for free shoaling waves

registry = deployment_registry(); names = sort(keys(registry));
seen = containers.Map('KeyType','char','ValueType','logical');

fprintf('\n================ HEADING-FLIP SWEEP ================\n');
fprintf('%-9s %-13s %6s %9s %8s %9s %9s %9s  %s\n', ...
    'deploy','label','nSeg','a1_swell','fracNeg','a1_peak','R2_IG','R2_swell','class');

R = struct([]);
for d = 1:numel(names)
    try, fn = registry(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true; %#ok<NASGU>
    fl = dir(fullfile(cfg.outputDir,'L2',cfg.name,'*_L2.mat'));

    for k = 1:numel(fl)
        lab = erase(fl(k).name,'_L2.mat');
        try, S2 = load(fullfile(fl(k).folder,fl(k).name)); L2 = S2.L2; catch, continue; end
        v = find(L2.segValid);
        if numel(v) < 20, continue; end
        if ~isfield(L2,'a1') || isempty(L2.a1), continue; end

        f = L2.f(:);
        iSW = f>=BAND_SWELL(1) & f<=BAND_SWELL(2);
        fSS = [0.04 0.25];
        if isfield(L2,'params') && isfield(L2.params,'fSS'), fSS = L2.params.fSS; end
        iSS = f>=fSS(1) & f<=fSS(2);

        a1sw = NaN(numel(v),1); a1pk = NaN(numel(v),1);
        for i = 1:numel(v)
            s = double(L2.S_eta(:,v(i)));
            a = double(L2.a1(:,v(i)));
            ssw = s(iSW); asw = a(iSW);
            ok = isfinite(ssw)&isfinite(asw)&ssw>0;
            if any(ok), a1sw(i) = sum(ssw(ok).*asw(ok))/sum(ssw(ok)); end   % energy-weighted
            sss = s(iSS); ass = a(iSS);
            if any(isfinite(sss))
                [~,ip] = max(sss);
                a1pk(i) = ass(ip);
            end
        end
        g = isfinite(a1sw);
        if sum(g) < 20, continue; end
        a1swMed = median(a1sw(g));
        fracNeg = mean(a1sw(g) < 0);
        a1pkMed = median(a1pk(isfinite(a1pk)));

        % per-band reflection R^2
        R2ig = NaN; R2sw = NaN;
        f4 = fullfile(L4root, cfg.name, [lab '_L4.mat']);
        if isfile(f4)
            try
                S4 = load(f4,'L4');
                if isfield(S4.L4,'ref')
                    rf = S4.L4.ref;
                    if isfield(rf,'R2_IG'), R2ig = median(rf.R2_IG(isfinite(rf.R2_IG))); end
                    if isfield(rf,'byBand')
                        bb = rf.byBand; fns = fieldnames(bb);
                        for q = 1:numel(fns)
                            if contains(lower(fns{q}),'swell')
                                x = bb.(fns{q});
                                if isstruct(x) && isfield(x,'R2'), x = x.R2; end
                                if isnumeric(x) && ~isempty(x), R2sw = median(x(isfinite(x))); end
                            end
                        end
                    end
                end
            catch
            end
        end

        % classify
        if a1swMed < -0.3 && fracNeg > 0.7
            cls = 'FLIP';
        elseif a1swMed < 0.15 || fracNeg > 0.35
            cls = 'SUSPECT';
        else
            cls = 'clean';
        end

        fprintf('%-9s %-13s %6d %9.3f %8.2f %9.3f %9.2f %9.2f  %s\n', ...
            cfg.name, lab, sum(g), a1swMed, fracNeg, a1pkMed, R2ig, R2sw, cls);

        r.dep=cfg.name; r.lab=lab; r.n=sum(g); r.a1sw=a1swMed; r.fracNeg=fracNeg;
        r.a1pk=a1pkMed; r.R2ig=R2ig; r.R2sw=R2sw; r.cls=cls;
        if isempty(R), R=r; else, R(end+1)=orderfields(r,R); end %#ok<AGROW>
    end
end

%% ---- ground the thresholds in the catalog distribution
a = [R.a1sw]'; cls = {R.cls}';
fprintf('\n================ CATALOG DISTRIBUTION ================\n');
fprintf('  energy-weighted swell-band a1, all %d records:\n', numel(R));
fprintf('    min %.3f | p5 %.3f | p25 %.3f | median %.3f | p75 %.3f | max %.3f\n', ...
    min(a), prctile(a,5), prctile(a,25), median(a), prctile(a,75), max(a));
fprintf('  A physical record should sit well above 0. The distribution should be\n');
fprintf('  bimodal if flips are present -- a clean cluster near +0.7 and a\n');
fprintf('  mirrored one near -0.7.\n');

fprintf('\n  histogram of a1_swell (bin width 0.1):\n');
edges = -1:0.1:1;
h = histcounts(a, edges);
for b = 1:numel(h)
    if h(b)==0, continue; end
    fprintf('   %+5.1f to %+5.1f | %s %d\n', edges(b), edges(b+1), repmat('#',1,h(b)), h(b));
end

fprintf('\n================ CLASSIFICATION ================\n');
for C = {'FLIP','SUSPECT'}
    m = strcmp(cls, C{1});
    fprintf('\n  %s (%d):\n', C{1}, sum(m));
    for i = find(m)'
        fprintf('    %-9s %-13s  a1_sw %+.3f  fracNeg %.2f  a1_pk %+.3f  R2_sw %.2f\n', ...
            R(i).dep, R(i).lab, R(i).a1sw, R(i).fracNeg, R(i).a1pk, R(i).R2sw);
    end
end
fprintf('\n  clean: %d\n', sum(strcmp(cls,'clean')));

fprintf('\n  CONTROL -- the two flips fixed in May 2026 should read clean:\n');
for i = 1:numel(R)
    if (strcmp(R(i).dep,'TBR23')&&strcmp(R(i).lab,'MOP580_5m')) || ...
       (strcmp(R(i).dep,'TOR24S')&&strcmp(R(i).lab,'MOP586_7m'))
        fprintf('    %-9s %-13s  a1_sw %+.3f  -> %s\n', R(i).dep, R(i).lab, R(i).a1sw, R(i).cls);
    end
end

save(fullfile(outDir,'heading_flip_sweep.mat'),'R');
fprintf('\nSaved: %s\n\n', fullfile(outDir,'heading_flip_sweep.mat'));
