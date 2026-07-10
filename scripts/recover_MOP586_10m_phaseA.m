function R = recover_MOP586_10m_phaseA()
%RECOVER_MOP586_10M_PHASEA  Step S3: prove the channel-decoupling recovery on the
% hardest case in the archive before touching 26 deployments.
%
% CONTEXT. TOR23W/MOP586_10m goes invalid 2023-12-25 -> 2024-01-19 in a single
% unbroken run of 597 L2 segments. Diagnosis (docs/L1_sensor_block_failure_2026-07-09.md):
% the AUXILIARY SENSOR BLOCK failed (pressure Dec 25, thermistor Dec 26, taking sound
% speed and the compass with it) while the Doppler channels stayed healthy through
% 29 Dec (beam correlations 92.6-97.0%, amplitude elevated, <=0.4% of samples below
% Nortek's 70% threshold). From 30 Dec the instrument genuinely dies (correlation 5-8%,
% amplitude 36 counts). L1 discarded all of it because PUV_raw_process.m:554-564 nulls
% the entire DAT row when pressure leaves [pMed/2, 2*pMed].
%
% WHAT THIS SCRIPT TESTS. Three claims, each with a falsifier:
%
%   C1  The .hdr says "Sound speed MEASURED", so recorded velocity scales linearly with
%       the (corrupt) measured sound speed:  u_rec = u_true * c_rec/c_true.
%       FALSIFIER: rescaling by c_true/c_rec should be a NO-OP on healthy days. If the
%       factor departs from 1.000 before 25 Dec, the model is wrong.
%
%   C2  The mean depth lost with the pressure sensor can be transferred from the healthy
%       7 m frame, because h(10m) - h(7m) is a constant (bed elevation difference).
%       FALSIFIER: that difference must be constant across the tide on healthy days.
%
%   C3  (HLB's idea.) The pressure spectrum can be reconstructed from the velocity
%       spectrum by inverting the z-test operator already in PUV_L2_spectral.m:426,
%           Spp_from_vel = (Suu + Svv) .* (omega ./ (g*k)).^2
%       FALSIFIER: on healthy days, Hs reconstructed this way must match the MEASURED Hs.
%       The residual IS the z-test, and it is used here as the calibration.
%
% Claims C1 and C3 are coupled and that gives a free independent check:
% Spp_from_vel ~ (Suu+Svv) ~ c^2, so reconstructing Hs from UNCORRECTED velocities over
% 26-29 Dec must come out ~5% low against D0586 and the 7 m frame, and from CORRECTED
% velocities must match. Both are reported.
%
% PROVENANCE. Every returned burst carries flags, per HLB 2026-07-09: reconstructed
% quantities are never presented as clean measurements.
%   segValid_vel      Doppler channels usable (beam correlation gate only)
%   segValid_p        pressure channel usable
%   vel_c_corrected   sound-speed rescale materially applied (|factor-1| > 0.002)
%   vel_c_factor      the factor applied (1.000 on healthy data, by construction not by gate)
%   Hs_source         'measured' | 'reconstructed' | 'none'
%   qc_flag           1 good | 2 not evaluated | 3 suspect (any reconstruction) | 4 fail
%
% READ-ONLY. Writes nothing into outputs/. Returns a struct; caller decides.
%
% Holden Leslie-Bole / audit, 2026-07-09.

startup_puv;
SP  = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/rec/';
RAW = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/raw/';

g = 9.81; rho = 1025; fs = 2; segLen = 7200;      % 1 hr @ 2 Hz, matching L2 defaults
nfft = 256; doffp10 = 1.00; doffp7 = 0.67;
fIG = [0.004 0.04]; fSS = [0.04 0.25]; KpMin = 0.1;
t0 = datetime(2023,11,14,12,0,2);                  % .dat row 1; CONTINUOUS 2 Hz

%% ---------- load ----------
D = readmatrix([SP 'dat10_win.csv'], 'NumHeaderLines', 1);       % NR,u,v,w,cmin,amin,p
t   = t0 + seconds((D(:,1)-1)/2);
u   = D(:,2); v = D(:,3); cmin = D(:,5); pdb = D(:,7);
fprintf('raw window: %s -> %s, %d samples\n', datestr(t(1)), datestr(t(end)), numel(t));

S10 = readtable([SP 'sen10_full.csv']);  S7 = readtable([SP 'sen7_full.csv']);
s10t = S10.time; s7t = S7.time;
if ~isdatetime(s10t), s10t = datetime(s10t); end
if ~isdatetime(s7t),  s7t  = datetime(s7t);  end
c10 = S10.c; c7 = S7.c;

L7 = readtable([RAW 'L1_MOP586_7m.csv']);          % 20-min bins, healthy frame
L7t = L7.time; if ~isdatetime(L7t), L7t = datetime(L7t); end
h7 = L7.P*1e4/(rho*g) + doffp7;                    % total depth at the 7 m frame

%% ---------- C2: depth transfer ----------
h10meas_raw = pdb*1e4/(rho*g) + doffp10;
healthy = t < datetime(2023,12,25);
h10h = accum_hourly(t(healthy), h10meas_raw(healthy));
h7i  = interp1(datenum(L7t), h7, datenum(h10h.t), 'linear', NaN);
dOK  = isfinite(h7i) & isfinite(h10h.v);
Delta = median(h10h.v(dOK) - h7i(dOK));
fprintf('\nC2  h(10m)-h(7m) over %d healthy hours: %.4f m, sd %.4f m, range [%.3f %.3f]\n', ...
    sum(dOK), Delta, std(h10h.v(dOK)-h7i(dOK)), min(h10h.v(dOK)-h7i(dOK)), max(h10h.v(dOK)-h7i(dOK)));

%% ---------- segment ----------
tSeg0 = dateshift(t(1),'start','hour');
if tSeg0 < t(1), tSeg0 = tSeg0 + hours(1); end
nSeg  = floor(seconds(t(end)-tSeg0)/ (segLen/fs));
f = (0:nfft/2)' * fs/nfft;
iTot = f >= fIG(1) & f <= fSS(2);

% NB: build field-by-field. struct('Hs_source',{cell}) would silently create a
% 1-by-nSeg STRUCT ARRAY rather than a struct holding a cell array.
R = struct();
R.t = NaT(nSeg,1);            R.Hs_meas = nan(nSeg,1);
R.Hs_rec = nan(nSeg,1);       R.Hs_rec_nocorr = nan(nSeg,1);
R.ztest = nan(nSeg,1);        R.H = nan(nSeg,1);
R.c_factor = nan(nSeg,1);     R.fbad = nan(nSeg,1);
R.segValid_vel = false(nSeg,1); R.segValid_p = false(nSeg,1);
R.vel_c_corrected = false(nSeg,1);
R.urms = nan(nSeg,1);         R.skew = nan(nSeg,1);  R.umean = nan(nSeg,1);
R.qc_flag = 4*ones(nSeg,1);   R.Hs_source = repmat({'none'}, nSeg, 1);

for i = 1:nSeg
    ta = tSeg0 + hours(i-1); tb = ta + hours(1);
    m  = t >= ta & t < tb;
    if sum(m) < segLen*0.99, continue; end
    idx = find(m, segLen, 'first');
    R.t(i) = ta + minutes(30);

    % ---- velocity QC: beam correlation only. Pressure does NOT gate velocity.
    fbad = mean(cmin(idx) < 70);
    R.fbad(i) = fbad;
    R.segValid_vel(i) = fbad <= 0.10;

    % ---- pressure QC, independent
    pm = mean(pdb(idx));
    R.segValid_p(i) = pm > 4.7 && pm < 18.8 && std(pdb(idx)) < 2;

    if ~R.segValid_vel(i), continue; end

    % ---- C1: sound-speed rescale, applied UNCONDITIONALLY.
    % On healthy data c_rec == c_true (7 m frame) so the factor is 1.000 by measurement,
    % not by a gate. That is the test.
    crec  = mean(c10(s10t >= ta & s10t < tb), 'omitnan');
    ctrue = mean(c7 (s7t  >= ta & s7t  < tb), 'omitnan');
    if ~isfinite(crec) || ~isfinite(ctrue), continue; end
    fac = ctrue/crec;
    R.c_factor(i) = fac;
    R.vel_c_corrected(i) = abs(fac-1) > 0.002;

    uu = detrend(u(idx)); vv = detrend(v(idx));
    uc = uu*fac; vc = vv*fac;

    % ---- depth
    if R.segValid_p(i)
        H = pm*1e4/(rho*g) + doffp10;
    else
        H = interp1(datenum(L7t), h7, datenum(R.t(i)), 'linear', NaN) + Delta;   % transferred
    end
    if ~isfinite(H), continue; end
    R.H(i) = H;

    % ---- spectra
    [Suu,~] = pwelch(uc, hann(nfft), nfft/2, nfft, fs);
    [Svv,~] = pwelch(vc, hann(nfft), nfft/2, nfft, fs);
    [Su0,~] = pwelch(uu, hann(nfft), nfft/2, nfft, fs);   % uncorrected, for the free check
    [Sv0,~] = pwelch(vv, hann(nfft), nfft/2, nfft, fs);

    omega = 2*pi*f;
    k = zeros(size(f)); k(2:end) = get_wavenumber(omega(2:end), H);
    u2p = zeros(size(f)); u2p(2:end) = omega(2:end)./(g*k(2:end));

    % ---- C3: reconstruct Spp from velocity, then S_eta, then Hs
    R.Hs_rec(i)        = hs_from_Spp((Suu+Svv).*u2p.^2, f, H, doffp10, KpMin, iTot);
    R.Hs_rec_nocorr(i) = hs_from_Spp((Su0+Sv0).*u2p.^2, f, H, doffp10, KpMin, iTot);

    % ---- measured Hs where pressure is alive, and the z-test residual
    if R.segValid_p(i)
        pm_m = detrend(pdb(idx)*1e4/(rho*g));
        [Spp,~] = pwelch(pm_m, hann(nfft), nfft/2, nfft, fs);
        R.Hs_meas(i) = hs_from_Spp(Spp, f, H, doffp10, KpMin, iTot);
        Sfv = (Suu+Svv).*u2p.^2;
        iSS = f>=fSS(1) & f<=fSS(2);
        Set = pressure_correction_wu(Spp, f, H, doffp10, KpMin);
        R.ztest(i) = sum(Spp(iSS).*Set(iSS)) / sum(Sfv(iSS).*Set(iSS) + eps);
    end

    % ---- velocity-only products: these never needed pressure
    R.urms(i)  = sqrt(var(uc)+var(vc));
    R.umean(i) = mean(u(idx))*fac;
    vm = compute_velocity_moments(uc, fs);
    R.skew(i)  = vm.skewness;

    % ---- provenance
    if R.segValid_p(i)
        R.Hs_source{i} = 'measured'; R.qc_flag(i) = 1;
    else
        R.Hs_source{i} = 'reconstructed'; R.qc_flag(i) = 3;   % never 1
    end
end

save([SP 'recover_10m_phaseA.mat'],'R','Delta','-v7.3');
fprintf('\nsaved %s\n', [SP 'recover_10m_phaseA.mat']);
report(R, Delta);
end

% ---------------- helpers ----------------
function Hs = hs_from_Spp(Spp, f, H, z, KpMin, iTot)
S_eta = pressure_correction_wu(Spp, f, H, z, KpMin);
Hs = 4*sqrt(max(trapz(f(iTot), S_eta(iTot)), 0));
end

function o = accum_hourly(t, x)
e = (dateshift(t(1),'start','hour')):hours(1):(dateshift(t(end),'start','hour'));
g = discretize(t, e);
o.t = e(1:end-1)' + minutes(30); o.v = nan(numel(e)-1,1);
for k = 1:numel(e)-1
    s = g==k; if sum(s) > 3600, o.v(k) = mean(x(s),'omitnan'); end
end
end

function report(R, Delta)
H = R.t < datetime(2023,12,25) & R.segValid_vel & R.segValid_p;
P = R.t >= datetime(2023,12,25) & R.t < datetime(2023,12,30) & R.segValid_vel;
fprintf('\n================= S3 RESULTS =================\n');
fprintf('healthy hours (Dec 22-24) with both channels valid : %d\n', sum(H));
fprintf('Phase-A hours (Dec 25-29) with velocity valid       : %d  (of which pressure valid: %d)\n', ...
    sum(P), sum(P & R.segValid_p));

fprintf('\nC1  sound-speed factor c_true/c_rec\n');
fprintf('    healthy  : median %.5f   range [%.5f %.5f]   <- must be ~1.000\n', ...
    median(R.c_factor(H),'omitnan'), min(R.c_factor(H)), max(R.c_factor(H)));
fprintf('    Phase A  : median %.5f   range [%.5f %.5f]\n', ...
    median(R.c_factor(P),'omitnan'), min(R.c_factor(P)), max(R.c_factor(P)));

fprintf('\nC2  depth transfer constant Delta = %.4f m\n', Delta);

fprintf('\nC3  reconstruction vs measurement on HEALTHY hours (this is the z-test)\n');
r = R.Hs_rec(H)./R.Hs_meas(H);
fprintf('    Hs_rec / Hs_meas : median %.4f  IQR [%.4f %.4f]  n=%d\n', ...
    median(r,'omitnan'), prctile(r,25), prctile(r,75), sum(isfinite(r)));
fprintf('    median ztest_SS  : %.4f  (1/sqrt(z) = %.4f)\n', median(R.ztest(H),'omitnan'), ...
    1/sqrt(median(R.ztest(H),'omitnan')));
cal = 1/median(r,'omitnan');
fprintf('    => calibration to apply to reconstructed Hs: x %.4f\n', cal);

fprintf('\n    Free check: reconstruction WITHOUT the sound-speed correction\n');
r0 = R.Hs_rec_nocorr(H)./R.Hs_meas(H);
fprintf('    healthy Hs_rec_nocorr/Hs_meas = %.4f  (should equal the corrected %.4f)\n', ...
    median(r0,'omitnan'), median(r,'omitnan'));
fprintf('    Phase A  Hs_rec_nocorr / Hs_rec = %.4f  (should be ~0.95: c_rec/c_true)\n', ...
    median(R.Hs_rec_nocorr(P)./R.Hs_rec(P),'omitnan'));

fprintf('\nRecovered Phase-A hours by day (calibrated Hs_rec):\n');
d = datetime(2023,12,25);
while d < datetime(2023,12,30)
    s = P & R.t>=d & R.t<d+days(1);
    if any(s)
        fprintf('  %s  n=%2d  Hs_rec %.2f-%.2f m (med %.2f)  fbad %.1f%%  c_fac %.4f\n', ...
            datestr(d,'yyyy-mm-dd'), sum(s), min(cal*R.Hs_rec(s)), max(cal*R.Hs_rec(s)), ...
            median(cal*R.Hs_rec(s)), 100*mean(R.fbad(s)), median(R.c_factor(s)));
    end
    d = d + days(1);
end
fprintf('\nqc_flag: %d good, %d suspect(reconstructed), %d fail\n', ...
    sum(R.qc_flag==1), sum(R.qc_flag==3), sum(R.qc_flag==4));
end
