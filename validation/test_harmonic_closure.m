% TEST_HARMONIC_CLOSURE  Does the harmonic band ACCOUNT FOR the nu excess, or
% merely accompany it?
%
%   test_harmonic_closure
%
% THE GAP THIS FILLS. The paper argues that the spectral-shape discrepancy is
% caused by energy the linear transform does not carry into a bound second
% harmonic. The evidence so far is that (a) nu organizes on nonlinearity and
% (b) the excess is localized near f/fp = 2. That is consistent with the claim
% but does not close it: a mechanism must ACCOUNT for the effect, not just sit
% beside it.
%
% The original falsifier (findings_resolution_artifact section 7) truncated the
% band at fixed ABSOLUTE frequencies and ran on four deployments, returning a
% mixed verdict -- falsified at Torrey, surviving at Coronado. Absolute
% truncation confounds the harmonic band with the depth-dependent pressure
% cutoff fCut, and four records cannot settle it.
%
% THE SHARPER TEST. Truncate RELATIVE TO fp. If the mechanism is right, then nu
% computed over a band that stops below the harmonic (f < 1.5 fp) should lose
% its organization on nonlinearity, while nu over the full band retains it. The
% prediction is specific and falsifiable:
%
%   rho(Ursell, nu | f < 1.5 fp)  ->  ~0     if harmonics account for it
%   rho(Ursell, nu | full band)   ->  +0.35  (the established value)
%
% If the truncated rho stays high, the excess is broadband and the harmonic
% localization is a coincidence -- which would weaken the mechanism claim
% substantially and should be reported as such.
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
reg  = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');

CUTS = [1.5 1.75 2.5 Inf];      % band upper limit as a multiple of fp

% WHICH SPECTRUM (added 2026-07-29). This test was originally written against
% L2.Spp, the raw PRESSURE spectrum. That is NOT the quantity the paper's shape
% metric uses: compare_shape_matched.m uses L2.S_eta, the surface spectrum, and
% S_pp = Kp^2 * S_eta with Kp = cosh(kd)/cosh(kh). The missing 1/Kp^2 suppresses
% the high-frequency tail -- roughly 4x more at 0.20 Hz than at a 0.08 Hz peak --
% which deflates m2 and hence nu. Feeding Spp is what made
% test_harmonic_closure_ratio.m return a full-band nu ratio of 0.842 against the
% catalog's 1.045.
%
% Here the consequence is milder, because this test reports a rank correlation
% and a within-test comparison ACROSS cuts rather than an absolute nu level. But
% the suppression sits exactly in the harmonic band the argument is about, so the
% result must be shown to survive on S_eta before it can be quoted alongside the
% paper's nu.
%
% Default is 'Spp' so the published numbers in
% findings_harmonic_closure_2026-07-29.md still reproduce byte-for-byte. Set
% SPECTRUM = 'S_eta' for the robustness check.
if ~exist('SPECTRUM','var') || isempty(SPECTRUM), SPECTRUM = 'Spp'; end
fprintf('Spectrum: L2.%s\n', SPECTRUM);

A = struct('ur',[],'hsh',[],'rec',[]);
for c = 1:numel(CUTS), A.(sprintf('nu%d',c)) = []; end

t0 = tic; nRec = 0;
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true;
    for k = 1:numel(cfg.instruments)
        lab = cfg.instruments(k).label;
        f2 = fullfile(cfg.outputDir,'L2',cfg.name,[lab '_L2.mat']);
        f4 = fullfile(cfg.outputDir,'L4',cfg.name,[lab '_L4.mat']);
        if ~isfile(f2) || ~isfile(f4), continue; end
        try
            w = load(f2,'L2'); L2 = w.L2;
        catch, continue; end
        v = find(L2.segValid);
        if numel(v) < 50, continue; end
        nRec = nRec + 1;

        f  = L2.f(:);
        fSS = [0.04 0.25]; if isfield(L2,'params') && isfield(L2.params,'fSS'), fSS = L2.params.fSS; end
        h  = median(L2.depth(v),'omitnan');

        for i = v(:)'
            s = double(L2.(SPECTRUM)(:,i));
            if all(~isfinite(s)), continue; end
            fc = L2.fCut(i); if ~isfinite(fc), fc = fSS(2); end
            band0 = f >= fSS(1) & f <= min(fSS(2),fc) & isfinite(s);
            if sum(band0) < 20, continue; end
            [~,ip] = max(s .* band0);
            fp = f(ip);
            if ~isfinite(fp) || fp <= 0, continue; end
            Hs = 4*sqrt(trapz(f(band0), s(band0)));
            hh = median(L2.depth(i),'omitnan'); if ~isfinite(hh), hh = h; end
            kk = get_wavenumber(2*pi*fp, hh);
            ur = Hs / (hh * (kk*hh)^2);          % Ursell, same form as the sweep
            if ~isfinite(ur), continue; end

            ok = true; nus = nan(1,numel(CUTS));
            for c = 1:numel(CUTS)
                b = band0 & f <= CUTS(c)*fp;
                if sum(b) < 15, ok = false; break; end
                m0 = trapz(f(b), s(b));
                m1 = trapz(f(b), f(b).*s(b));
                m2 = trapz(f(b), f(b).^2.*s(b));
                nus(c) = sqrt(max(m0*m2/m1^2 - 1, 0));
            end
            if ~ok || any(~isfinite(nus)), continue; end
            A.ur(end+1,1)  = ur;
            A.hsh(end+1,1) = Hs/hh;
            A.rec(end+1,1) = nRec;
            for c = 1:numel(CUTS), A.(sprintf('nu%d',c))(end+1,1) = nus(c); end
        end
        fprintf('  %-9s %-13s  %d hours\n', cfg.name, lab, sum(A.rec==nRec));
    end
end

fprintf('\n%d records, %d hours, %.1f min\n', nRec, numel(A.ur), toc(t0)/60);
fprintf('\n===== DOES THE ORGANIZATION SURVIVE BAND TRUNCATION? =====\n');
fprintf('NOTE: this is the PUV spectrum only -- it asks whether the SHAPE\n');
fprintf('statistic itself depends on the harmonic band, which is the necessary\n');
fprintf('condition. It is not the model-ratio version.\n\n');
fprintf('  %-16s %10s %10s\n','band upper limit','rho(ur,nu)','median nu');
for c = 1:numel(CUTS)
    y = A.(sprintf('nu%d',c));
    g = isfinite(y) & isfinite(A.ur);
    lbl = 'full band'; if isfinite(CUTS(c)), lbl = sprintf('%.2f fp', CUTS(c)); end
    fprintf('  %-16s %+10.3f %10.4f\n', lbl, corr(A.ur(g), y(g), 'type','Spearman'), median(y(g)));
end

% Keep the two spectra in separate files so the S_eta robustness check cannot
% silently overwrite the published Spp numbers.
if strcmp(SPECTRUM,'Spp')
    outName = 'harmonic_closure.mat';
else
    outName = ['harmonic_closure_' SPECTRUM '.mat'];
end
save(fullfile(root,outName),'A','CUTS','SPECTRUM');
fprintf('\nSaved: %s\n', fullfile(root,outName));
