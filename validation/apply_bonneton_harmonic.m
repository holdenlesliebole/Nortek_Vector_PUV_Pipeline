% APPLY_BONNETON_HARMONIC  Step 6: measure the TFM's harmonic-band error on real
% records using the Bonneton & Lannes nonlinear reconstruction.
%
% THE QUESTION. The paper claims an excess of observed energy near f/f_ref = 2
% relative to a linear model. That observed energy is inferred by the linear
% transfer-function method (TFM), which applies free-wave dispersion frequency by
% frequency. A bound harmonic is phase-locked to its primary and does not obey
% that relation, so the TFM mis-estimates it. How much, and in which direction?
%
% THE METHOD. Bonneton & Lannes (arXiv:1709.06457; Coastal Engineering 138, 2018)
% eq. (19) gives the weakly-nonlinear reconstruction
%     zeta_NL = zeta_L - (1/g) d_t( zeta_L d_t zeta_L )
% implemented in shared/bonneton_nl_correction.m and closure-tested to 3e-16 in
% L2_spectral/test_bonneton_reconstruction.m. Applying it to real pressure
% records and comparing the harmonic-band energy of zeta_NL against zeta_L
% measures the TFM error directly, with the actual spectral content, requiring no
% Stokes theory and no assumption about the bound fraction.
%
% PREDICTED SIGN. For a monochromatic primary the correction adds a second
% harmonic of amplitude +A^2 omega^2/g, so the TFM should UNDER-estimate bound
% harmonic energy and the ratio S_NL/S_L in the harmonic band should exceed 1.
% If it does, the TFM bias makes the paper's measured excess CONSERVATIVE rather
% than inflated -- the opposite of the concern that motivated this work.
%
% CLOSURE CHECK, reported first. The zeta_L spectrum computed here must reproduce
% the pipeline's saved L2.S_eta for the same record. If it does not, this
% reconstruction is not the one the paper uses and nothing below is comparable.
%
% CONTROL. The peak band [0.85, 1.15] f_ref is not expected to be bound, so its
% S_NL/S_L ratio should sit near unity. It absorbs any broadband artifact of the
% correction.
%
% Writes outputs/validation/bonneton_harmonic.mat
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
g = 9.81; KpMin = 0.1;
SS  = [0.04 0.25];
HB  = [1.75 2.50];
PKB = [0.85 1.15];
NPK = 4;

% A depth ladder. Shallow/nonlinear through deep, so the kh dependence shows.
RECS = { 'TBR23','MOP586_5m'; ...
         'TBR23','MOP586_7m'; ...
         'TOR20W','MOP582_10m'; ...
         'TOR25S','MOP586_15m' };

reg = deployment_registry();
OUT = struct([]);

fprintf('\n================================================================\n');
fprintf(' Step 6 — Bonneton nonlinear reconstruction vs linear TFM\n');
fprintf('================================================================\n');

for r = 1:size(RECS,1)
    dep = RECS{r,1}; lab = RECS{r,2};
    if excluded_records(dep, lab)
        fprintf('\n[%s/%s] excluded, skipping\n', dep, lab); continue
    end

    % locate L1 and L2
    l1 = ''; l2 = '';
    try
        fn = reg(dep); cfg = fn();
        l1 = fullfile(cfg.outputDir,'L1',cfg.name,[lab '_processed.mat']);
        l2 = fullfile(cfg.outputDir,'L2',cfg.name,[lab '_L2.mat']);
    catch
    end
    if ~isfile(l1) || ~isfile(l2)
        fprintf('\n[%s/%s] missing L1 or L2, skipping\n', dep, lab); continue
    end

    fprintf('\n[%s/%s]\n', dep, lab);
    w1 = load(l1,'PUV'); PUV = w1.PUV;
    w2 = load(l2,'L2');  L2  = w2.L2;

    fs   = PUV.fs;
    doff = PUV.doffp;
    P    = double(PUV.P(:));
    segLen = round(3600*fs);
    nSeg   = floor(numel(P)/segLen);
    fprintf('  fs=%g  doffp=%.2f  %d hourly segments\n', fs, doff, nSeg);

    % accumulate
    rh = []; rp = []; hs = []; hh = []; ur = []; fr = []; nAcc = 0;
    m0mine = []; tmine = NaT(0,1,'TimeZone','UTC');
    tAll = PUV.time(:);
    if isempty(tAll.TimeZone), tAll.TimeZone = 'UTC'; end

    for s = 1:nSeg
        idx = (s-1)*segLen + (1:segLen);
        p   = P(idx);
        if any(~isfinite(p)), continue; end
        pm  = mean(p);
        if pm <= 0.5, continue; end
        H   = pm + doff;                       % total depth, bed to surface
        zH  = p - pm;                          % hydrostatic reconstruction (m)
        if std(zH) < 1e-3, continue; end

        % --- linear reconstruction in the frequency domain, matching
        % pressure_correction_wu: Kp = cosh(k doffp)/cosh(k H), zero below KpMin.
        N   = numel(zH);
        kix = (0:N-1)';
        ffold = min(kix, N-kix) * fs / N;      % |f| for each fft bin
        kw  = zeros(N,1);
        nz  = ffold > 0;
        kw(nz) = get_wavenumber(2*pi*ffold(nz), H);
        Kp  = ones(N,1);
        Kp(nz) = cosh(kw(nz)*doff) ./ cosh(kw(nz)*H);
        keep = Kp >= KpMin & nz;               % drop DC and over-amplified bins
        Zh  = fft(zH);
        Zl  = zeros(N,1);
        Zl(keep) = Zh(keep) ./ Kp(keep);
        zL  = real(ifft(Zl));

        % --- nonlinear correction
        zNL = bonneton_nl_correction(zL, fs, g);

        % --- spectra, identical treatment of both
        nfft = 2^nextpow2(segLen/8);
        [SL, ff] = pwelch(zL,  hanning(nfft), nfft/2, nfft, fs);
        [SN, ~ ] = pwelch(zNL, hanning(nfft), nfft/2, nfft, fs);

        b0 = ff >= SS(1) & ff <= SS(2);
        if sum(b0) < 10, continue; end
        sN4 = SL(b0).^NPK;
        fref = sum(ff(b0).*sN4)/max(sum(sN4),eps);
        if ~isfinite(fref) || fref <= 0, continue; end

        bH = ff >= HB(1)*fref & ff <= HB(2)*fref & b0;
        bP = ff >= PKB(1)*fref & ff <= PKB(2)*fref & b0;
        if sum(bH) < 3 || sum(bP) < 3, continue; end

        EH_L = trapz(ff(bH), SL(bH));  EH_N = trapz(ff(bH), SN(bH));
        EP_L = trapz(ff(bP), SL(bP));  EP_N = trapz(ff(bP), SN(bP));
        if EH_L <= 0 || EP_L <= 0, continue; end

        m0 = trapz(ff(b0), SL(b0));
        Hsi = 4*sqrt(max(m0,0));
        k0  = get_wavenumber(2*pi*fref, H);

        rh(end+1,1) = EH_N/EH_L;   rp(end+1,1) = EP_N/EP_L; %#ok<SAGROW>
        hs(end+1,1) = Hsi;         hh(end+1,1) = H;         %#ok<SAGROW>
        ur(end+1,1) = Hsi/(H*(k0*H)^2);  fr(end+1,1) = fref; %#ok<SAGROW>

        % band-integrated variance over a fixed window, for the closure check
        bc = ff >= 0.05 & ff <= 0.20;
        m0mine(end+1,1) = trapz(ff(bc), SL(bc)); %#ok<SAGROW>
        tmine(end+1,1)  = tAll(idx(1)); %#ok<SAGROW>
        nAcc = nAcc + 1;
    end

    if nAcc < 20
        fprintf('  only %d usable segments, skipping\n', nAcc); continue
    end

    % --- CLOSURE CHECK, hour by hour against the pipeline's own S_eta ----
    % Compare the SAME hour on both sides. Comparing a mean spectrum against a
    % median one (an earlier version of this check) gives a 1.4-2x ratio purely
    % because hourly wave energy is strongly right-skewed -- not a real
    % discrepancy. And the operator, not the record-average level, is what has to
    % agree: the Bonneton correction is QUADRATIC in zeta_L, so an amplitude
    % error in zeta_L would scale the correction by its square.
    v  = find(L2.segValid);
    fL = L2.f(:);
    tL = L2.time(v); if isempty(tL.TimeZone), tL.TimeZone = 'UTC'; end
    bb = fL >= 0.05 & fL <= 0.20;
    m0pipe = trapz(fL(bb), double(L2.S_eta(bb,v)), 1)';
    cr = [];
    for q = 1:numel(tmine)
        [dt, im] = min(abs(tL - tmine(q)));
        if dt <= minutes(31) && isfinite(m0pipe(im)) && m0pipe(im) > 0
            cr(end+1,1) = m0mine(q)/m0pipe(im); %#ok<SAGROW>
        end
    end
    fprintf('  CLOSURE, time-matched hour by hour, m0 over 0.05-0.20 Hz:\n');
    if numel(cr) < 10
        fprintf('    only %d matched hours -- closure NOT established\n', numel(cr));
        rat = NaN;
    else
        rat = cr;
        fprintf('    n=%d matched   median ratio %.4f   IQR %.4f - %.4f  (1.0 = operator agrees)\n', ...
            numel(cr), median(cr), prctile(cr,25), prctile(cr,75));
    end

    fprintf('  RESULT over %d segments:\n', nAcc);
    fprintf('    f_ref median            %.4f Hz\n', median(fr));
    fprintf('    Hs median               %.3f m,  Hs/h %.4f,  Ursell %.4f\n', ...
        median(hs), median(hs./hh), median(ur));
    fprintf('    S_NL/S_L harmonic band  %.4f   IQR %.4f - %.4f\n', ...
        median(rh), prctile(rh,25), prctile(rh,75));
    fprintf('    S_NL/S_L peak band [C]  %.4f   IQR %.4f - %.4f\n', ...
        median(rp), prctile(rp,25), prctile(rp,75));
    fprintf('    harmonic/peak (net)     %.4f\n', median(rh)/median(rp));
    if numel(ur) > 30
        fprintf('    rho(Ursell, harm ratio) %+.3f\n', corr(ur, rh, 'type','Spearman'));
    end

    o = struct('deployment',dep,'label',lab,'n',nAcc,'doffp',doff, ...
               'h_median',median(hh),'fref_median',median(fr), ...
               'Hs_median',median(hs),'ur_median',median(ur), ...
               'ratio_harm',median(rh),'ratio_peak',median(rp), ...
               'closure_ratio',median(rat,'omitnan'), ...
               'rh',rh,'rp',rp,'ur',ur,'hs',hs,'hh',hh,'fr',fr);
    if isempty(OUT), OUT = o; else, OUT(end+1) = o; end %#ok<SAGROW>
end

%% ---- pooled summary ---------------------------------------------------
fprintf('\n================================================================\n');
fprintf(' SUMMARY — is the harmonic band under- or over-estimated by the TFM?\n');
fprintf('================================================================\n');
if isempty(OUT)
    fprintf(' no records processed\n');
else
    fprintf(' %-9s %-13s %6s %7s %9s %9s %9s %8s\n', ...
        'deploy','label','h(m)','Ursell','harm','peak[C]','net','closure');
    for i = 1:numel(OUT)
        o = OUT(i);
        fprintf(' %-9s %-13s %6.1f %7.4f %9.4f %9.4f %9.4f %8.4f\n', ...
            o.deployment, o.label, o.h_median, o.ur_median, ...
            o.ratio_harm, o.ratio_peak, o.ratio_harm/o.ratio_peak, o.closure_ratio);
    end
    allh = vertcat(OUT.rh); allp = vertcat(OUT.rp);
    fprintf('\n pooled harmonic  %.4f   pooled peak %.4f   net %.4f  (n=%d)\n', ...
        median(allh), median(allp), median(allh)/median(allp), numel(allh));
    fprintf('\n Reading: net > 1 means the linear TFM UNDER-estimates the harmonic\n');
    fprintf(' band, so the paper''s measured excess is CONSERVATIVE. net < 1 means\n');
    fprintf(' it over-estimates and the excess is inflated.\n');
end

save(fullfile(root,'bonneton_harmonic.mat'),'OUT','HB','PKB','NPK','SS','KpMin');
fprintf('\nSaved bonneton_harmonic.mat\n');
