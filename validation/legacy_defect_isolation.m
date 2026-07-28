% LEGACY_DEFECT_ISOLATION  Attribute new-vs-legacy differences to specific defects.
%
% Purpose: lab documentation of why the legacy PUV codes
% (beachpeeps/PUV_Processing) are deprecated. Not paper material.
%
% A whole-pipeline A/B confounds every difference at once and cannot say which
% change caused what. Instead each legacy choice is implemented as an isolated
% switch applied to IDENTICAL input, so every delta is attributable.
%
% DEFECTS TESTED (numbering follows docs/pipeline_comparison_legacy.md)
%
%   D1  Auto- and cross-spectra estimated differently. Legacy auto-spectra
%       (calculate_fft2) use a Hanning window with 50% overlap
%       (num = floor(2n/nfft)-1 ensembles); legacy cross-spectra (cospec) use a
%       Hamming window with ZERO overlap and a hardcoded nfft = 2400. So the
%       two differ in window AND in degrees of freedom, and
%           a1 = Re(Spu) / sqrt(Spp*(Suu+Svv))
%       mixes them. Affects every directional quantity: a1, b1, a2, b2, mean
%       direction, spread, and radiation stress.
%
%   D3  NaN handling. Legacy replaces NaN with zero before the FFT
%       (calculate_fft2.m:11, cospec.m:22). This removes variance in proportion
%       to the gap fraction, so the bias should scale with it -- a testable
%       signature rather than scatter.
%
%   D4  Pressure correction. Legacy caps Kp^2 at 10; the current pipeline zeros
%       frequencies where Kp < 0.1. Expected to matter most in shallow water and
%       at high frequency, where the two rules diverge.
%
%   DESIGN-A  Swell band upper limit, 0.20 Hz (legacy) vs 0.25 Hz.
%   DESIGN-B  Peak period, energy-weighted centroid (legacy) vs argmax.
%
% D2 (frequency-grid mismatch between fm and f_co) and D5 (Suv indexed at line 49
% before being computed at line 107) are structural code faults with no
% meaningful "correct magnitude" to measure; they are noted, not quantified.
%
% The output is organised as defect -> affected quantity -> magnitude ->
% condition under which it becomes material, since the question is not "do the
% pipelines differ" but "when does the difference change a conclusion".
%
% Author: Holden Leslie-Bole, 2026

startup_puv

pipeRoot = fileparts(fileparts(mfilename('fullpath')));
outDir   = fullfile(pipeRoot,'outputs','validation');

% Records spanning the conditions of interest. The first two are the same
% station, depth and era as the published Ruby2D-line analysis (MOP582, 10 m,
% 2019-2021), so the deltas there are directly relevant to it.
cases = { 'TOR19W','MOP582_10m'
          'TOR20W','MOP582_10m'
          'TBR23', 'MOP586_5m'
          'IB18W', 'MOP045_7m'
          'SIO25E','SIO_6m'      };

MAXSEG = 400;   % per record; the deltas are per-segment so this is ample

A = struct('rec',{{}},'h',[],'Hs',[],'Tp',[],'spread',[],'gap',[], ...
           'dDp',[],'dSpread',[],'da1',[],'db2',[], ...
           'dHs_nan',[],'dHs_kp',[],'dHs_band',[],'dTp_def',[]);

fprintf('\n=============== LEGACY DEFECT ISOLATION ===============\n');

for c = 1:size(cases,1)
    dep = cases{c,1}; lab = cases{c,2};
    f1 = fullfile(pipeRoot,'outputs','L1',dep,[lab '_processed.mat']);
    f2 = fullfile(pipeRoot,'outputs','L2',dep,[lab '_L2.mat']);
    if ~isfile(f1) || ~isfile(f2), fprintf('  [skip] %s/%s\n',dep,lab); continue; end
    S1 = load(f1,'PUV'); PUV = S1.PUV;
    S2 = load(f2,'L2');  L2  = S2.L2;

    fs   = L2.fs;
    segN = L2.params.segLen;
    doffp = L2.doffp;
    v = find(L2.segValid);
    v = v(round(linspace(1,numel(v),min(MAXSEG,numel(v)))));

    % shore-normal velocities, same rotation the pipeline uses
    sn = L2.shorenormal;
    U = PUV.BuoyCoord.U(:); V = PUV.BuoyCoord.V(:); P = PUV.P(:);
    th = deg2rad(sn);
    usn =  U*cos(th) + V*sin(th);
    vsn = -U*sin(th) + V*cos(th);

    % map L2 segment index -> sample range (harmonise time zones first)
    t0 = PUV.time(1); tL2 = L2.time;
    if isempty(t0.TimeZone) && ~isempty(tL2.TimeZone), t0.TimeZone = tL2.TimeZone;
    elseif ~isempty(t0.TimeZone) && isempty(tL2.TimeZone), tL2.TimeZone = t0.TimeZone; end
    nUsed = 0;
    for i = 1:numel(v)
        ii = v(i);
        i1 = round(seconds(tL2(ii) - t0)*fs) + 1;
        i2 = i1 + segN - 1;
        if i1 < 1 || i2 > numel(P), continue; end

        p = P(i1:i2); u = usn(i1:i2); w = vsn(i1:i2);
        gap = mean(~isfinite(p) | ~isfinite(u) | ~isfinite(w));
        if gap > 0.5, continue; end

        h = L2.depth(ii);
        if ~isfinite(h) || h <= 0, continue; end

        % ---------- D1: estimator mismatch on directional quantities ----------
        [f_n, Spp_n, Suu_n, Svv_n, Spu_n, Spv_n, Suv_n] = est_mtm(p,u,w,fs,segN);
        [f_l, Spp_l, Suu_l, Svv_l, Spu_l, Spv_l, Suv_l] = est_legacy(p,u,w,fs);

        [Dp_n, Sp_n, a1_n, b2_n] = dirstats(f_n,Spp_n,Suu_n,Svv_n,Spu_n,Spv_n,Suv_n);
        [Dp_l, Sp_l, a1_l, b2_l] = dirstats(f_l,Spp_l,Suu_l,Svv_l,Spu_l,Spv_l,Suv_l);

        % ---------- D3: NaN -> zero vs interpolate ----------
        pf = fillmissing(p,'linear','EndValues','nearest');
        Hs_fill = hs_from(pf,fs,segN,h,doffp,[0.04 0.25],'cutoff');
        pz = p; pz(~isfinite(pz)) = 0;
        Hs_zero = hs_from(pz,fs,segN,h,doffp,[0.04 0.25],'cutoff');

        % ---------- D4: Kp cap vs cutoff ----------
        Hs_cut = Hs_fill;
        Hs_cap = hs_from(pf,fs,segN,h,doffp,[0.04 0.25],'cap');

        % ---------- design choices ----------
        Hs_020 = hs_from(pf,fs,segN,h,doffp,[0.04 0.20],'cutoff');
        [Tp_max, Tp_cen] = tp_both(f_n, Spp_n, [0.04 0.25]);

        k = numel(A.h)+1;
        A.rec{k,1}=[dep '/' lab]; A.h(k,1)=h;
        A.Hs(k,1)=Hs_fill; A.Tp(k,1)=Tp_max; A.spread(k,1)=Sp_n; A.gap(k,1)=gap;
        A.dDp(k,1)     = wrapTo180(Dp_l - Dp_n);
        A.dSpread(k,1) = Sp_l - Sp_n;
        A.da1(k,1)     = a1_l - a1_n;
        A.db2(k,1)     = b2_l - b2_n;
        A.dHs_nan(k,1) = (Hs_zero - Hs_fill)/max(Hs_fill,eps);
        A.dHs_kp(k,1)  = (Hs_cap  - Hs_cut )/max(Hs_cut, eps);
        A.dHs_band(k,1)= (Hs_020  - Hs_cut )/max(Hs_cut, eps);
        A.dTp_def(k,1) = Tp_cen - Tp_max;
        nUsed = nUsed + 1;
    end
    fprintf('  %-8s %-12s h=%5.1f  %d segments\n', dep, lab, median(L2.depth(v),'omitnan'), nUsed);
end

n = numel(A.h);
fprintf('\n%d segments across %d records\n', n, numel(unique(A.rec)));

%% ================== REPORT ==================
fprintf('\n--- D1  estimator mismatch (auto Hanning/50%% overlap vs cross Hamming/0%%) ---\n');
pr = @(nm,x,u) fprintf('  %-28s median %+8.3f %s | IQR %+.3f to %+.3f | p95|.| %.3f\n', ...
    nm, median(x,'omitnan'), u, prctile(x,25), prctile(x,75), prctile(abs(x),95));
pr('mean direction Dp', A.dDp, 'deg');
pr('directional spread', A.dSpread, 'deg');
pr('a1 at peak', A.da1, '');
pr('b2 at peak (-> Sxy)', A.db2, '');

fprintf('\n  where does it get worse? (median |dDp|, deg)\n');
binreport(A.spread, A.dDp, [0 15 20 25 90], 'spread (deg)');
binreport(A.Hs,     A.dDp, [0 0.5 1 1.5 2 10], 'Hs (m)');

fprintf('\n--- D3  NaN -> zero before FFT ---\n');
pr('fractional Hs change', A.dHs_nan, '');
g = A.gap > 0.001;
if any(g)
    [r,p] = corr(A.gap(g), A.dHs_nan(g), 'type','Spearman');
    fprintf('  rho(gap fraction, dHs) = %+.3f (p = %.2g, n = %d)\n', r, p, sum(g));
    fprintf('  predicted: dHs/Hs ~ -gap/2 (variance removed in proportion to gap)\n');
    binreport(A.gap(g), A.dHs_nan(g), [0 0.01 0.02 0.05 0.10 1], 'gap fraction');
else
    fprintf('  no segments with gaps in this subset -- inconclusive here\n');
end

fprintf('\n--- D4  Kp^2 capped at 10 vs Kp < 0.1 zeroed ---\n');
pr('fractional Hs change', A.dHs_kp, '');
binreport(A.h, A.dHs_kp, [0 6 8 10 40], 'depth (m)');

fprintf('\n--- DESIGN-A  swell band 0.20 vs 0.25 Hz ---\n');
pr('fractional Hs change', A.dHs_band, '');
binreport(A.Tp, A.dHs_band, [0 8 12 16 30], 'Tp (s)');

fprintf('\n--- DESIGN-B  Tp centroid vs argmax ---\n');
pr('Tp difference', A.dTp_def, 's');

save(fullfile(outDir,'legacy_defect_isolation.mat'),'A');
fprintf('\nSaved: %s\n\n', fullfile(outDir,'legacy_defect_isolation.mat'));

%% ================== helpers ==================
function binreport(x, y, edges, name)
    fprintf('    %-16s %7s %12s\n', name, 'n', 'median |d|');
    for b = 1:numel(edges)-1
        m = x>=edges(b) & x<edges(b+1) & isfinite(y);
        if sum(m) < 10, continue; end
        fprintf('    %6.2f - %6.2f %7d %12.3f\n', edges(b), edges(b+1), sum(m), median(abs(y(m))));
    end
end

function [f,Spp,Suu,Svv,Spu,Spv,Suv] = est_mtm(p,u,w,fs,nfft)
    % Same DPSS tapers for auto and cross -- the property the legacy path lacks.
    p = fillmissing(detrend_nan(p),'linear','EndValues','nearest');
    u = fillmissing(detrend_nan(u),'linear','EndValues','nearest');
    w = fillmissing(detrend_nan(w),'linear','EndValues','nearest');
    [Spp, Spu, f] = psd_multitaper(p, u, nfft, fs, 4);
    [~,   Spv, ~] = psd_multitaper(p, w, nfft, fs, 4);
    [Suu, Suv, ~] = psd_multitaper(u, w, nfft, fs, 4);
    [Svv, ~,   ~] = psd_multitaper(w, [], nfft, fs, 4);
end

function [f,Spp,Suu,Svv,Spu,Spv,Suv] = est_legacy(p,u,w,fs)
    % auto: Hanning, nfft = 2400, 50% overlap, NaN -> 0  (calculate_fft2)
    % cross: Hamming, nfft = 2400, ZERO overlap, NaN -> 0 (cospec)
    nf = 2400;
    z = @(x) local_zero(x);
    [Spp,f] = pwelch(z(p), hann(nf), floor(nf/2), nf, fs);
    Suu     = pwelch(z(u), hann(nf), floor(nf/2), nf, fs);
    Svv     = pwelch(z(w), hann(nf), floor(nf/2), nf, fs);
    Spu     = cpsd(z(p), z(u), hamming(nf), 0, nf, fs);
    Spv     = cpsd(z(p), z(w), hamming(nf), 0, nf, fs);
    Suv     = cpsd(z(u), z(w), hamming(nf), 0, nf, fs);
end

function x = local_zero(x), x = detrend_nan(x); x(~isfinite(x)) = 0; end
function x = detrend_nan(x)
    g = isfinite(x);
    if sum(g) < 8, return; end
    t = (1:numel(x))';
    pfit = polyfit(t(g), x(g), 1);
    x = x - polyval(pfit, t);
end

function [Dp,spread,a1pk,b2pk] = dirstats(f,Spp,Suu,Svv,Spu,Spv,Suv)
    i = f>=0.04 & f<=0.25;
    f=f(i); Spp=Spp(i); Suu=Suu(i); Svv=Svv(i);
    Spu=Spu(i); Spv=Spv(i); Suv=Suv(i);
    den = sqrt(Spp.*(Suu+Svv)) + eps;
    a1 = real(Spu)./den;  b1 = real(Spv)./den;
    a2 = (Suu-Svv)./(Suu+Svv+eps);  b2 = 2*real(Suv)./(Suu+Svv+eps);
    [~,ip] = max(Spp);
    Dp = atan2d(b1(ip), a1(ip));
    r1 = min(sqrt(a1(ip)^2 + b1(ip)^2),1);
    spread = rad2deg(sqrt(2*(1-r1)));
    a1pk = a1(ip); b2pk = b2(ip);
end

function Hs = hs_from(p,fs,nfft,h,doffp,band,kpMode)
    p = detrend_nan(p); p(~isfinite(p)) = 0;
    [S, ~, f] = psd_multitaper(p, [], nfft, fs, 4);
    om = 2*pi*f; k = get_wavenumber(om,h);
    Kp = cosh(k(:)*doffp)./cosh(k(:)*h);
    switch kpMode
        case 'cutoff', Kp(Kp < 0.1) = Inf;      % zero those frequencies
        case 'cap',    Kp = max(Kp, 1/sqrt(10)); % legacy: cap Kp^2 amplification at 10
    end
    Se = S ./ (Kp.^2);
    i = f>=band(1) & f<=band(2);
    Hs = 4*sqrt(max(trapz(f(i), Se(i)),0));
end

function [Tp_max, Tp_cen] = tp_both(f,S,band)
    i = f>=band(1) & f<=band(2); f=f(i); S=S(i);
    [~,ip] = max(S); Tp_max = 1/f(ip);
    Tp_cen = trapz(f,S) / max(trapz(f, f.*S), eps);   % energy-weighted centroid
end
