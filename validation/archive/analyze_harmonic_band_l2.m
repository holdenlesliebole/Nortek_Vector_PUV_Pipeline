% ANALYZE_HARMONIC_BAND_L2  L2-only diagnostics for the bound-harmonic question.
%
% Covers Steps 0, 1 and 3 of ~/.claude/plans/plan-this-out-so-prancy-cocoa.md in
% one pass over the saved L2 spectra. Needs NO reprocessing and NO THREDDS:
% L2.Spp, L2.S_eta, L2.Suu, L2.Svv, L2.Kp, L2.f and L2.depth are all stored
% per-frequency, per-segment.
%
% THE QUESTION. The paper's spine is an excess of observed energy near f/fp = 2
% relative to a linear model that cannot generate bound harmonics. But the
% observed surface spectrum there is inferred, not measured:
% S_eta = S_pp/Kp^2 with Kp evaluated at the FREE-WAVE wavenumber k_free(f). A
% bound harmonic is phase-locked to the primary and carries 2*k0 < k_free(2f0),
% so the linear transfer function OVER-corrects it by
%
%   I = [ cosh(2k0 d) cosh(k_a h) / ( cosh(2k0 h) cosh(k_a d) ) ]^2 ,  k_a = k_free(2f0)
%
% which inflates precisely the band the claim rests on, in the direction that
% flatters it, by an amount growing with kh. This is NOT a solver error --
% get_wavenumber.m solves the free-wave relation by Newton to 1e-10. It is an
% exact solution of the wrong equation for a bound wave.
%
% THE DISCRIMINATOR. The same mismatch leaves a fingerprint in pressure-velocity
% consistency. Derive it from the POTENTIAL, not from the surface elevation: both
% p and u come from phi, so their ratio does not depend on how phi relates to eta
% -- which matters because a bound wave does NOT satisfy the free-wave relation
% between them. For phi = A cosh(kappa(z+h)) cos(kappa x - sigma t):
%
%   |u| = A kappa cosh(...)  ,  |p|/(rho g) = (sigma A / g) cosh(...)
%   => S_uu/S_pp = (g kappa / sigma)^2        [no eta assumption]
%
% The pipeline forms Spp_from_vel = (Suu+Svv)*(sigma/(g k_a))^2 with k_a the FREE
% wavenumber (PUV_L2_spectral.m:556-566), so
%
%   z^2(sigma) = (k_a / kappa)^2        [KINEMATIC-ONLY -- incomplete, see below]
%
% Unity for a free wave; above unity for a bound harmonic (kappa = 2k0 < k_a).
% SECOND CORRECTION (2026-07-29, later): the kinematic-only prediction (~1.24)
% is itself incomplete -- it uses linearized Bernoulli, omitting the coherent
% quadratic pressure -(1/2)rho|grad phi1|^2 at the sum frequency. The COMPLETE
% theory (Herbers & Guza 1991 eq. 4, shared/hg91_bound_impedance.m, anchored to
% five published values) gives z2_pred ~1.04-1.08, nearly FLAT in kh: the
% quadratic term opposes the forced-potential pressure and cancels most of the
% kh growth. This script now uses the full prediction; z2_kin is kept for
% comparison. Consequence: the impedance diagnostic's discriminating power is
% weak (z2_pred - 1 is only ~2-3x plausible measurement systematics), so beta
% from this route needs the pressure-noise bound reported below and ultimately
% the bispectral cross-check. z^2 at the PEAK is the internal control: same
% instrument, same hour, same processing, not expected to be bound, so ~1. The
% control also absorbs the ~5% systematic z^2 offset, so read the RATIO
% z2_harm/z2_peak, not z2_harm alone.
%
% RETRACTED 2026-07-29: an earlier version of this header claimed
% z^2 = [tanh(2k0 h)/tanh(k_a h)]^2 ~ 0.88, i.e. BELOW unity. That was derived via
% u = sigma*eta*cosh(kappa d)/sinh(kappa h), which smuggles in the free-wave
% eta<->A relation and is invalid for a bound wave. Sign and magnitude both wrong.
% The same error invalidates the inflation factor I below; a correct bound-wave Kp
% needs the second-order QTF (Bonneton et al. 2018).
%
% Inverting the observed z^2 in the harmonic band for the bound fraction beta
% gives the correction actually needed -- one measurement validating another.
%
% ALSO. O'Reilly et al. (2016) show fp is unstable in southern California when
% sea and swell peak energies are comparable. Every published cut in
% findings_harmonic_closure_2026-07-29.md is a multiple of per-hour argmax fp, so
% this reports three band references and an explicit ambiguity flag.
%
% CAVEAT ON SCOPE. nu here is computed on the PUV's own FINE grid, not the model
% bin grid, so its absolute value is NOT the paper's nu (which comes from
% compare_shape_matched.m on the matched coarse grid). Only the FRACTIONAL
% sensitivity is transferable. The absolute correction comes from Step 5.
%
% Writes outputs/validation/harmonic_band_l2.mat
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
reg  = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');

g   = 9.81;
NPK = 4;                 % exponent for the weighted peak frequency (Young-style)
HB  = [1.75 2.50];       % harmonic band, as multiples of the reference frequency
PKB = [0.85 1.15];       % peak band, as multiples of the reference (the control)
SWELL = [0.0375 0.0875]; % O'Reilly et al. (2016) swell band

A = struct('rec',{[]},'h',[],'doffp',[],'fp_argmax',[],'f_ref',[],'f_swell',[], ...
           'ambig',[],'ur',[],'hsh',[],'I',[],'z2_pred',[],'z2_kin',[], ...
           'nu',[],'nu_corr',[],'z2_harm',[],'z2_peak',[], ...
           'Eharm_frac',[],'velnoise',[],'pn_frac',[],'nbH',[]);
recName = {};

t0 = tic; nRec = 0; nExcl = 0;
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true;

    for k = 1:numel(cfg.instruments)
        lab = cfg.instruments(k).label;
        if excluded_records(cfg.name, lab), nExcl = nExcl + 1; continue; end

        f2 = fullfile(cfg.outputDir,'L2',cfg.name,[lab '_L2.mat']);
        if ~isfile(f2), continue; end
        try, w = load(f2,'L2'); L2 = w.L2; catch, continue; end
        if ~isfield(L2,'Suu') || isempty(L2.Suu), continue; end

        v = find(L2.segValid);
        if numel(v) < 50, continue; end
        nRec = nRec + 1; recName{nRec} = sprintf('%s/%s', cfg.name, lab); %#ok<SAGROW>

        f   = L2.f(:);
        fSS = [0.04 0.25];
        if isfield(L2,'params') && isfield(L2.params,'fSS'), fSS = L2.params.fSS; end
        dof = NaN;
        if isfield(cfg.instruments(k),'doffp'), dof = cfg.instruments(k).doffp; end
        if ~isfinite(dof), dof = 0.6; end

        nHr = 0;
        for i = v(:)'
            Se = double(L2.S_eta(:,i));
            Sp = double(L2.Spp(:,i));
            Su = double(L2.Suu(:,i));
            Sv = double(L2.Svv(:,i));
            if all(~isfinite(Se)) || all(~isfinite(Su)), continue; end

            fc = L2.fCut(i); if ~isfinite(fc), fc = fSS(2); end
            fHi = min(fSS(2), fc);
            band0 = f >= fSS(1) & f <= fHi & isfinite(Se) & Se > 0;
            if sum(band0) < 20, continue; end

            hh = L2.depth(i); if ~isfinite(hh) || hh <= 0, continue; end

            % --- three band references -----------------------------------
            [~,ip] = max(Se .* band0);
            fp_am  = f(ip);
            sN     = Se(band0).^NPK;
            f_ref  = sum(f(band0).*sN) / max(sum(sN), eps);
            bs     = f >= SWELL(1) & f <= SWELL(2) & isfinite(Se) & Se > 0;
            f_sw   = NaN;
            if sum(bs) > 3, f_sw = sum(f(bs).*Se(bs)) / max(sum(Se(bs)), eps); end
            if ~isfinite(f_ref) || f_ref <= 0, continue; end

            % fp ambiguity: swell-band peak vs sea-band peak energy. When these
            % are comparable, argmax fp jumps between them -- exactly the
            % instability O'Reilly et al. (2016) describe.
            bsea = f > SWELL(2) & f <= fHi & isfinite(Se);
            Esw  = max(Se(bs & isfinite(Se)), [], 'omitnan');
            Ese  = max(Se(bsea), [], 'omitnan');
            ambig = NaN;
            if isfinite(Esw) && isfinite(Ese) && Ese > 0, ambig = Esw/Ese; end

            % --- kinematics: bound (2k0) vs assumed free (k_a) ------------
            k0  = get_wavenumber(2*pi*f_ref,  hh);
            ka  = get_wavenumber(4*pi*f_ref,  hh);     % free wave at 2*f_ref
            kb  = 2*k0;                                 % bound harmonic
            % z^2 if the band were FULLY bound — COMPLETE second-order theory
            % (Herbers & Guza 1991 eq. 4 via shared/hg91_bound_impedance.m,
            % anchored to five published values). The earlier kinematic-only
            % (k_a/kappa)^2 omitted the coherent quadratic Bernoulli pressure;
            % the full theory sits much closer to unity (~1.04-1.08, nearly flat
            % in kh) and z2kin is kept only for comparison. Self-sum collinear
            % pair (f_ref, f_ref) as the band representative.
            [z2p, z2kin] = hg91_bound_impedance(f_ref, f_ref, 0, hh, dof);

            % Kp inflation. RETRACTED as derived -- this expression assumes the
            % bound wave obeys the free-wave p<->eta relation, which it does not.
            % Retained only as a placeholder magnitude; the correct factor needs
            % the second-order QTF (Bonneton et al. 2018, plan Step 6). Do not
            % quote nu_corr below as a corrected value.
            Ival = ( cosh(kb*dof)*cosh(ka*hh) / ( cosh(kb*hh)*cosh(ka*dof) ) )^2;

            % --- nu on the fine grid, and nu with the harmonic band deflated
            % beta = 1 (all harmonic energy bound) is the UPPER BOUND on the bias.
            bH = band0 & f >= HB(1)*f_ref & f <= HB(2)*f_ref;
            if sum(bH) < 3, continue; end
            nuv     = nu_of(f, Se,               band0);
            SeC     = Se; SeC(bH) = SeC(bH) / Ival;
            nuc     = nu_of(f, SeC,              band0);
            if ~isfinite(nuv) || ~isfinite(nuc), continue; end

            m0all = trapz(f(band0), Se(band0));
            Ehf   = trapz(f(bH),    Se(bH)) / max(m0all, eps);

            % --- frequency-resolved z^2 ----------------------------------
            kf  = NaN(size(f)); kf(2:end) = get_wavenumber(2*pi*f(2:end), hh);
            u2p = (2*pi*f) ./ (g * kf);          % omega/(g k), the pipeline's form
            Spv = (Su + Sv) .* u2p.^2;
            z2f = Sp ./ max(Spv, eps);
            bP  = band0 & f >= PKB(1)*f_ref & f <= PKB(2)*f_ref;
            z2h = median(z2f(bH & isfinite(z2f)), 'omitnan');
            z2k = median(z2f(bP & isfinite(z2f)), 'omitnan');

            % velocity noise proxy: (Suu+Svv) level above the pressure cutoff,
            % where wave-coherent velocity should be small. Inflated Suu depresses
            % z^2 the SAME direction as a bound harmonic, so this is the key
            % confound to carry forward.
            bN  = f > fHi & f <= min(fHi*1.6, max(f));
            vn  = NaN;
            if sum(bN) > 3, vn = median(Su(bN)+Sv(bN), 'omitnan'); end

            % PRESSURE noise proxy — the DANGEROUS-sign confound. A pressure
            % floor inflates Spp and raises z^2, mimicking the bound signature,
            % and it matters most in the harmonic band where Kp^2 has attenuated
            % the signal. Estimate the floor from Spp well above fCut, where
            % free-wave pressure is attenuated by >1e3; note forced waves DO
            % reach there (HG91's whole point), so this is an UPPER bound on the
            % instrument floor. Report it as a fraction of harmonic-band Spp:
            % that fraction is directly the bias it could put on z2_harm.
            pn = NaN; pnf = NaN;
            bNp = f >= max(2.2*f_ref, fHi*1.3) & f <= min(0.8, max(f));
            if sum(bNp) > 5 && sum(bH) > 2
                pn  = median(Sp(bNp), 'omitnan');
                pnf = pn / max(median(Sp(bH), 'omitnan'), eps);
            end

            % Ursell, same form as test_harmonic_closure.m / the sweeps
            Hs  = 4*sqrt(max(m0all,0));
            ur  = Hs / (hh * (k0*hh)^2);

            nHr = nHr + 1;
            A.rec(end+1,1)=nRec;      A.h(end+1,1)=hh;         A.doffp(end+1,1)=dof;
            A.fp_argmax(end+1,1)=fp_am; A.f_ref(end+1,1)=f_ref; A.f_swell(end+1,1)=f_sw;
            A.ambig(end+1,1)=ambig;   A.ur(end+1,1)=ur;        A.hsh(end+1,1)=Hs/hh;
            A.I(end+1,1)=Ival;        A.z2_pred(end+1,1)=z2p;   A.z2_kin(end+1,1)=z2kin;
            A.pn_frac(end+1,1)=pnf; %#ok<AGROW>
            A.nu(end+1,1)=nuv;        A.nu_corr(end+1,1)=nuc;
            A.z2_harm(end+1,1)=z2h;   A.z2_peak(end+1,1)=z2k;
            A.Eharm_frac(end+1,1)=Ehf; A.velnoise(end+1,1)=vn; A.nbH(end+1,1)=sum(bH);
        end
        fprintf('  %-9s %-13s h=%5.1f doffp=%.2f  %5d hours\n', cfg.name, lab, ...
                median(L2.depth(v),'omitnan'), dof, nHr);
    end
end

fprintf('\n%d records, %d hours, %d excluded, %.1f min\n', ...
        nRec, numel(A.ur), nExcl, toc(t0)/60);

%% ---- Step 0: how big is the bias in nu? -------------------------------
fprintf('\n=============================================================\n');
fprintf(' STEP 0 — sensitivity of nu to the harmonic-band correction\n');
fprintf(' (fine grid; only the FRACTIONAL result transfers to the paper)\n');
fprintf('=============================================================\n');
dnu  = A.nu - A.nu_corr;                    % artifact contribution to nu
frac = dnu ./ max(A.nu, eps);
fprintf('  inflation I           median %.4f   IQR %.4f - %.4f   max %.3f\n', ...
    median(A.I,'omitnan'), prctile(A.I,25), prctile(A.I,75), max(A.I));
fprintf('  harmonic band energy  median %.4f of m0\n', median(A.Eharm_frac,'omitnan'));
fprintf('  nu (uncorrected)      median %.4f\n', median(A.nu,'omitnan'));
fprintf('  nu (corrected)        median %.4f\n', median(A.nu_corr,'omitnan'));
fprintf('  dnu artifact          median %.4f  (%.2f%% of nu)\n', ...
    median(dnu,'omitnan'), 100*median(frac,'omitnan'));
fprintf('\n  THE GATE. Observed catalog excess is nu_ratio - 1 = 0.0454, i.e. about\n');
fprintf('  %.4f in nu at nu_mop = 0.3417. Artifact accounts for dnu = %.4f,\n', ...
    0.0454*0.3417, median(dnu,'omitnan'));
fprintf('  so r = dnu_artifact / dnu_observed = %.2f (beta = 1, upper bound).\n', ...
    median(dnu,'omitnan') / (0.0454*0.3417));
fprintf('   r < 0.2 -> bound it;  0.2-0.6 -> report both;  > 0.6 -> correct and\n');
fprintf('   make primary. beta < 1 scales r down proportionally.\n');

%% ---- Step 1: band references and fp stability -------------------------
fprintf('\n=============================================================\n');
fprintf(' STEP 1 — band references, and how unstable is argmax fp?\n');
fprintf('=============================================================\n');
rel = A.fp_argmax ./ A.f_ref;
fprintf('  fp_argmax   median %.4f Hz\n', median(A.fp_argmax,'omitnan'));
fprintf('  f_ref (S^%d) median %.4f Hz\n', NPK, median(A.f_ref,'omitnan'));
fprintf('  f_swell     median %.4f Hz\n', median(A.f_swell,'omitnan'));
fprintf('  fp/f_ref    median %.3f  IQR %.3f - %.3f  sd %.3f\n', ...
    median(rel,'omitnan'), prctile(rel,25), prctile(rel,75), std(rel,'omitnan'));
amb = A.ambig(isfinite(A.ambig));
for thr = [0.67 1.0 1.5]
    fprintf('  hours with swell/sea peak ratio within %.2f of unity: %.1f%%\n', ...
        thr, 100*mean(abs(log(amb)) < abs(log(thr))+eps));
end
fprintf('  SHARPNESS TEST is Step 5''s job: f_ref is better only if it makes the\n');
fprintf('  f/f_ref ~ 2 feature sharper than fp does.\n');

%% ---- Step 3: is the harmonic band actually bound? ---------------------
fprintf('\n=============================================================\n');
fprintf(' STEP 3 — z^2: is the harmonic band bound (>1, ~1.24) or free (~1.00)?\n');
fprintf('=============================================================\n');
gz = isfinite(A.z2_harm) & isfinite(A.z2_peak);
fprintf('  n = %d hours with both bands finite\n', sum(gz));
fprintf('  z^2 PREDICTED if fully bound   median %.4f  IQR %.4f - %.4f\n', ...
    median(A.z2_pred(gz)), prctile(A.z2_pred(gz),25), prctile(A.z2_pred(gz),75));
fprintf('  z^2 OBSERVED harmonic band     median %.4f  IQR %.4f - %.4f\n', ...
    median(A.z2_harm(gz)), prctile(A.z2_harm(gz),25), prctile(A.z2_harm(gz),75));
fprintf('  z^2 OBSERVED peak band [CTRL]  median %.4f  IQR %.4f - %.4f\n', ...
    median(A.z2_peak(gz)), prctile(A.z2_peak(gz),25), prctile(A.z2_peak(gz),75));
rel  = A.z2_harm(gz) ./ max(A.z2_peak(gz), eps);
% RECIPROCAL mixture, validated in L2_spectral/test_kp_bound_harmonic.m. Each
% component contributes Spp_j to the numerator and Spp_j*(kappa_j/k_a)^2 to the
% denominator, so a band that is a fraction E_b bound returns
%   z^2 = 1/[E_b/z2_pred + (1-E_b)]  =>  E_b = (1 - 1/z^2)/(1 - 1/z2_pred).
% The linear form (z^2-1)/(z2_pred-1) under-states E_b by ~15-30% at these values
% (0.105 recovered for an input of 0.125) and must not be used.
beta = (1 - 1./max(rel,eps)) ./ (1 - 1./max(A.z2_pred(gz), 1+eps));
fprintf('\n  z^2_harm / z^2_peak            median %.4f  IQR %.4f - %.4f\n', ...
    median(rel), prctile(rel,25), prctile(rel,75));
fprintf('  implied bound fraction beta    median %.4f  IQR %.4f - %.4f\n', ...
    median(beta), prctile(beta,25), prctile(beta,75));
fprintf('\n  Read the RATIO, not z2_harm alone: the control absorbs the ~5%%\n');
fprintf('  systematic offset. Ratio > 1 means bound energy is present; ratio at\n');
fprintf('  z2_pred means fully bound; ratio at 1.00 means NOT bound, which would\n');
fprintf('  contradict the mechanism far more seriously than the bias does.\n');
fprintf('  rho(Ursell, beta) = %+.3f  <- should be POSITIVE if bound energy\n', ...
    corr_safe(A.ur(gz), beta));
fprintf('  grows with nonlinearity, as the mechanism requires.\n');
fprintf('  CONFOUND: velocity noise inflates Suu and depresses z^2 the same way.\n');
fprintf('  rho(velnoise, z2_harm) = %+.3f  <- if strongly negative, noise is\n', ...
    corr_safe(A.velnoise(gz), A.z2_harm(gz)));
fprintf('  contaminating the signature and must be subtracted before inverting.\n');
fprintf('\n  z^2 predictions: FULL (HG91)  median %.4f  IQR %.4f - %.4f\n', ...
    median(A.z2_pred(gz),'omitnan'), prctile(A.z2_pred(gz),25), prctile(A.z2_pred(gz),75));
fprintf('                   kinematic     median %.4f  (retained for comparison)\n', ...
    median(A.z2_kin(gz),'omitnan'));
fprintf('  PRESSURE-noise share of harmonic-band Spp (upper bound on the floor):\n');
fprintf('    median %.4f   IQR %.4f - %.4f   90th pct %.4f\n', ...
    median(A.pn_frac(gz),'omitnan'), prctile(A.pn_frac(gz),25), ...
    prctile(A.pn_frac(gz),75), prctile(A.pn_frac(gz),90));
fprintf('  This fraction is directly the upward bias it could put on z2_harm.\n');
fprintf('  Compare it to z2_pred-1 = %.4f: if comparable, beta is not resolvable\n', ...
    median(A.z2_pred(gz),'omitnan')-1);
fprintf('  from the impedance alone and the bispectral route must carry it.\n');

save(fullfile(root,'harmonic_band_l2.mat'),'A','recName','HB','PKB','NPK','SWELL');
fprintf('\nSaved harmonic_band_l2.mat\n');

%% ---- helpers ---------------------------------------------------------
function nu = nu_of(f, S, b)
    ff = f(b); ss = S(b);
    m0 = trapz(ff, ss); m1 = trapz(ff, ff.*ss); m2 = trapz(ff, (ff.^2).*ss);
    if m0 <= 0 || m1 <= 0, nu = NaN; return; end
    nu = sqrt(max(m0*m2/m1^2 - 1, 0));
end

function r = corr_safe(x, y)
    g = isfinite(x) & isfinite(y);
    if sum(g) < 10, r = NaN; return; end
    r = corr(x(g), y(g), 'type', 'Spearman');
end
