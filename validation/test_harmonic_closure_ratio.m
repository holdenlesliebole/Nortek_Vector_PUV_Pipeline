% TEST_HARMONIC_CLOSURE_RATIO  The sufficient condition: does the PUV/MODEL nu
% RATIO lose its nonlinearity organization when the harmonic band is removed?
%
%   test_harmonic_closure_ratio
%
% test_harmonic_closure established the NECESSARY condition on the PUV spectrum
% alone: rho(Ursell, nu) reverses from +0.294 to -0.406 once the band stops
% below 1.5 fp, so the observed shape statistic's nonlinearity signal is
% harmonic in origin.
%
% The paper's claim is about the model-observation DISCREPANCY, not the
% observation alone. This applies the same fp-relative truncation to both sides
% on a matched grid, and asks whether rho(Ursell, nu_PUV/nu_model) collapses.
%
% PREDICTION, stated before running: if the discrepancy is caused by harmonic
% energy the linear transform does not carry, the ratio's organization should
% fall toward zero below 1.5 fp while the full-band value stays near +0.35. If
% the truncated ratio keeps organizing on Ursell, the discrepancy has a
% component outside the harmonic band and the mechanism is incomplete.
%
% Both sides are binned to the MODEL's native grid before any metric is taken --
% never the model interpolated up -- per findings_resolution_artifact.
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
reg  = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');
CUTS = [1.5 1.75 2.5 Inf];

B = struct('ur',[],'hsh',[],'rec',[]);
% Save nu_PUV and nu_model SEPARATELY, not just their per-hour ratio. The
% established catalog value (nu_ratio = 1.045) is a ratio of per-record MEDIANS
% -- compare_shape_matched.m:314 -- and median(a/b) is not median(a)/median(b).
% Storing both sides lets the same estimator be reconstructed here, which is the
% only way this test can be checked against the established number.
for c = 1:numel(CUTS)
    B.(sprintf('r%d',c)) = [];
    B.(sprintf('p%d',c)) = [];   % nu_PUV
    B.(sprintf('m%d',c)) = [];   % nu_model
end
t0 = tic; nRec = 0;

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true;
    for k = 1:numel(cfg.instruments)
        inst = cfg.instruments(k); lab = inst.label;
        f2 = fullfile(cfg.outputDir,'L2',cfg.name,[lab '_L2.mat']);
        if ~isfile(f2), continue; end
        try, w = load(f2,'L2'); L2 = w.L2; catch, continue; end
        v = find(L2.segValid); if numel(v) < 50, continue; end

        station = '';
        if isfield(L2,'refStation') && ~isempty(L2.refStation), station = L2.refStation;
        else
            tok = regexp(lab,'MOP(\d+)','tokens','once');
            if ~isempty(tok), station = ['D0' tok{1}]; end
        end
        if isempty(station), continue; end

        tS = min(L2.time(v)); tE = max(L2.time(v));
        if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end
        try, MOP = read_MOPline2(station, tS, tE); catch, continue; end
        if isempty(MOP.time), continue; end

        h = median(L2.depth(v),'omitnan');
        try
            SH = shoal_mop_to_site(MOP, h);
        catch
            continue
        end
        fMid = SH.frequency(:); fbw = SH.fbw(:);
        if ~isempty(SH.fbounds), fbounds = SH.fbounds;   % [2 x n] or [n x 2]
        else, fbounds = [fMid(:) - fbw(:)/2, fMid(:) + fbw(:)/2]; end
        f = L2.f(:);
        fSS = [0.04 0.25];
        if isfield(L2,'params') && isfield(L2.params,'fSS'), fSS = L2.params.fSS; end

        tP = L2.time(v); if isempty(tP.TimeZone), tP.TimeZone = MOP.time.TimeZone; end
        nAdded = 0; nRec = nRec + 1;
        for t = 1:numel(MOP.time)
            [dt,im] = min(abs(tP - MOP.time(t)));
            if dt > minutes(30), continue; end
            i = v(im);
            sp = double(L2.Spp(:,i)); if all(~isfinite(sp)), continue; end
            sm = double(SH.spec(t,:))';   if all(~isfinite(sm)), continue; end
            fc = L2.fCut(i); if ~isfinite(fc), fc = fSS(2); end

            spb = bin_spectrum_to_grid(f, sp, fbounds);      % PUV down to model grid
            band0 = fMid >= fSS(1) & fMid <= min(fSS(2),fc) & isfinite(spb) & isfinite(sm);
            if sum(band0) < 8, continue; end
            [~,ip] = max(spb .* band0); fp = fMid(ip);
            if ~isfinite(fp) || fp <= 0, continue; end

            hh = median(L2.depth(i),'omitnan'); if ~isfinite(hh), hh = h; end
            Hs = 4*sqrt(sum(spb(band0).*fbw(band0)));
            kk = get_wavenumber(2*pi*fp, hh);
            ur = Hs/(hh*(kk*hh)^2); if ~isfinite(ur), continue; end

            ok = true; rr = nan(1,numel(CUTS)); pp = rr; mm = rr;
            for c = 1:numel(CUTS)
                b = band0 & fMid <= CUTS(c)*fp;
                if sum(b) < 5, ok = false; break; end
                nu = @(s) sqrt(max( sum(s(b).*fbw(b)) * sum(fMid(b).^2.*s(b).*fbw(b)) / ...
                                    max(sum(fMid(b).*s(b).*fbw(b))^2,eps) - 1, 0));
                a1 = nu(spb); a2 = nu(sm);
                if ~isfinite(a1) || ~isfinite(a2) || a2 <= 0, ok = false; break; end
                rr(c) = a1/a2; pp(c) = a1; mm(c) = a2;
            end
            if ~ok, continue; end
            B.ur(end+1,1)=ur; B.hsh(end+1,1)=Hs/hh; B.rec(end+1,1)=nRec;
            for c=1:numel(CUTS)
                B.(sprintf('r%d',c))(end+1,1)=rr(c);
                B.(sprintf('p%d',c))(end+1,1)=pp(c);
                B.(sprintf('m%d',c))(end+1,1)=mm(c);
            end
            nAdded = nAdded + 1;
        end
        fprintf('  %-9s %-13s %d hours\n', cfg.name, lab, nAdded);
    end
end

fprintf('\n%d records, %d hours, %.1f min\n', nRec, numel(B.ur), toc(t0)/60);
fprintf('\n===== SUFFICIENT CONDITION: DOES THE RATIO STOP ORGANIZING? =====\n');
fprintf('TWO ESTIMATORS. "med(a/b)" is the median of per-hour ratios; "med a / med b"\n');
fprintf('is the ratio of per-record medians, which is what compare_shape_matched\n');
fprintf('reports (1.045 full band). They are not the same statistic -- if the\n');
fprintf('second column does not reproduce ~1.045 on the full band, this test is\n');
fprintf('still not measuring what the catalog value measures.\n\n');
uR = unique(B.rec);
fprintf('  %-16s %12s %12s %14s\n','band upper limit','rho(ur,ratio)','med(a/b)','med a / med b');
for c = 1:numel(CUTS)
    y = B.(sprintf('r%d',c)); a = B.(sprintf('p%d',c)); b = B.(sprintf('m%d',c));
    g = isfinite(y)&isfinite(B.ur);
    perRec = nan(numel(uR),1);
    for j = 1:numel(uR)
        m = B.rec==uR(j) & isfinite(a) & isfinite(b);
        if sum(m) < 20, continue; end
        perRec(j) = median(a(m)) / median(b(m));
    end
    lbl='full band'; if isfinite(CUTS(c)), lbl=sprintf('%.2f fp',CUTS(c)); end
    fprintf('  %-16s %+12.3f %12.4f %14.4f\n', lbl, ...
        corr(B.ur(g),y(g),'type','Spearman'), median(y(g)), median(perRec,'omitnan'));
end
save(fullfile(root,'harmonic_closure_ratio.mat'),'B','CUTS');
fprintf('\nSaved: %s\n', fullfile(root,'harmonic_closure_ratio.mat'));
