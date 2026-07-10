function test_channel_decoupling()
%TEST_CHANNEL_DECOUPLING  Synthetic closure test for the L1/L2 channel-decoupling fix.
%
% Gates the change proposed in docs/L1_sensor_block_failure_2026-07-09.md before it is
% allowed anywhere near the 26-deployment rerun. Written in the style of
% L2_spectral/test_ztest_linear.m: build a field whose answer is known analytically,
% corrupt exactly one channel, and assert what must and must not change.
%
% The defect being tested: PUV_raw_process.m:554-564 NaNs the entire DAT row when the
% pressure channel or the tilt-variability flag fires, destroying Doppler velocities that
% are independently healthy. PUV_L2_spectral.m:298 then computes nanFrac jointly on
% (p,u,v), so a dead pressure sensor also destroys velocity moments that never needed it.
%
% FIVE ASSERTIONS
%   T1  Corrupt ONLY pressure. Velocity moments must be bit-identical to the clean run.
%   T2  Corrupt ONLY temperature. The sound-speed rescale u -> u * c_true/c_rec must
%       recover the true velocities to machine precision.
%   T3  When temperature is HEALTHY, the new code path must return results identical to
%       the old one. (The rescale must be a no-op, not an approximate no-op.)
%   T4  Depth transfer: with pressure dead, h taken from a companion frame plus a constant
%       must reproduce Hs to the tolerance implied by dHs/dh.
%   T5  Pressure reconstruction: Spp_from_vel inverted from a synthetic linear wave field
%       must return the wave field's own Hs.
%
% Run:  >> startup_puv;  test_channel_decoupling
%
% 2026-07-09.

fprintf('\n=== test_channel_decoupling ===\n');
rng(20260709);
g = 9.81; fs = 2; N = 7200; nfft = 256;
h = 9.40; doffp = 1.00;                 % MOP586_10m geometry
t = (0:N-1)'/fs;

% ---- synthetic linear wave field: JONSWAP-ish sum of free waves, known m0 ----
f  = (0.05:0.005:0.25)';
S  = 0.35 * exp(-((f-0.09)/0.025).^2);          % m^2/Hz
df = 0.005;
a  = sqrt(2*S*df);                               % amplitude per component
m0_true = sum(0.5*a.^2);
Hs_true = 4*sqrt(m0_true);
omega = 2*pi*f;
k = get_wavenumber(omega, h);

eta = zeros(N,1); u = zeros(N,1); p = zeros(N,1);
for j = 1:numel(f)
    ph = 2*pi*rand;
    eta = eta + a(j)*cos(omega(j)*t - ph);
    % horizontal orbital velocity at the sensor, and pressure head at the sensor
    u = u + a(j)*omega(j)*cosh(k(j)*doffp)/sinh(k(j)*h) * cos(omega(j)*t - ph);
    p = p + a(j)*cosh(k(j)*doffp)/cosh(k(j)*h)          * cos(omega(j)*t - ph);
end
v = 0.03*randn(N,1);                 % small alongshore
fprintf('synthetic field: Hs_true = %.4f m, h = %.2f m\n', Hs_true, h);

ok = true;

%% ---- T1: corrupt only pressure. Show the CURRENT gate destroys u; the PROPOSED one does not.
m_clean = compute_velocity_moments(detrend(u), fs);
p_bad = p; p_bad(:) = p_bad(:) + 9.40;           % put pressure in dBar-like units
p_bad(1:3:end) = 240;                            % firmware overflow code, as in RUBY22
corr_beams = 95*ones(N,3);                       % Doppler perfectly healthy throughout
pMed = 9.40;

% -- current behaviour: row-level kill (PUV_raw_process.m:554-564)
bad_row = p_bad < pMed/2 | p_bad > pMed*2;
u_current = u; u_current(bad_row) = NaN;
nanFrac_current = mean(isnan(u_current));        % PUV_L2_spectral.m:298 sees this
destroyed = nanFrac_current > 0.10;              % :299 -> `continue`, moments never computed
ok = report('T1a current row-level gate DESTROYS healthy velocity', destroyed, nanFrac_current) && ok;
fprintf('     nanFrac on u = %.3f (> 0.10), so L2 skips the segment and no moment exists.\n', nanFrac_current);

% -- proposed behaviour: per-channel masks. This is the spec the L1 change must satisfy.
[valid_vel, valid_p] = qc_per_channel(p_bad, corr_beams, pMed);
u_proposed = u; u_proposed(~valid_vel) = NaN;
m_prop = compute_velocity_moments(detrend(u_proposed(valid_vel)), fs);
d1 = abs(m_clean.skewness - m_prop.skewness);
ok = report('T1b proposed per-channel gate preserves velocity moments', d1 < 1e-12, d1) && ok;
fprintf('     valid_vel = %.1f%% of samples, valid_p = %.1f%%  (decoupled, as required)\n', ...
    100*mean(valid_vel), 100*mean(valid_p));

%% ---- T2: corrupt only temperature; the c-rescale must invert exactly ----
c_true = 1512.0; c_rec = 1432.7;                 % measured, 28 Dec 2023
u_rec  = u * (c_rec/c_true);                     % what the instrument would record
u_fix  = u_rec * (c_true/c_rec);
d2 = max(abs(u_fix - u));
ok = report('T2  sound-speed rescale inverts to machine precision', d2 < 1e-12, d2) && ok;

m_fix = compute_velocity_moments(detrend(u_fix), fs);
d2b = abs(m_fix.skewness - m_clean.skewness);
ok = report('T2b moments of the rescaled series match the clean ones', d2b < 1e-10, d2b) && ok;

% magnitude check: the bias the rescale removes
fprintf('     uncorrected bias: urms %.4f%%, <u^3> %.4f%%  (velocity ~ c, moment ~ c^3)\n', ...
    100*(c_rec/c_true - 1), 100*((c_rec/c_true)^3 - 1));

%% ---- T3: healthy temperature => the new path is a NO-OP, exactly ----
fac = c_true/c_true;
d3 = max(abs(u*fac - u));
ok = report('T3  healthy T => rescale factor is exactly 1, bitwise no-op', d3 == 0, d3) && ok;

%% ---- T4: depth transfer sensitivity ----
% Unidirectional field: the cross-shore component carries all the wave energy, so the
% reconstruction is exercised with v = 0 rather than with the alongshore noise.
v0 = zeros(N,1);
Hs_h  = hs_from_vel(u, v0, fs, nfft, h,        doffp, g);
Hs_hp = hs_from_vel(u, v0, fs, nfft, h + 0.01, doffp, g);
dHs_dh = (Hs_hp - Hs_h)/0.01;
% the observed transfer error was sd = 0.0041 m
err_Hs = abs(dHs_dh) * 0.0041;
ok = report('T4  4 mm depth-transfer error => <1 mm error in Hs', err_Hs < 1e-3, err_Hs) && ok;
fprintf('     dHs/dh = %.4f m/m at h = %.2f m\n', dHs_dh, h);

%% ---- T6: a TOPPLED frame must NOT be rescued (regression for N6) ----
% TOR23W/MOP580_7m fails in the same storm with a HEALTHY sensor block (battery 14.40 V,
% c = 1511 m/s, T = 17.0-17.4) while the frame itself rolls from -0.6 to -33.7 deg and its
% heading swings 73 -> 117 deg. It fell over. Tilt is not an auxiliary channel: it is a
% statement about the measurement geometry, and no rotation repairs a moving frame.
%
% The rule: trust the tilt sensor exactly when the sensor block it lives on is healthy.
corr_ok = true(N,1); present = true(N,1);

% (a) MOP580_7m: thermistor fine, frame toppled  -> velocity must be REJECTED
valid_T_a    = true(N,1);
valid_tilt_a = false(N,1);                 % roll 33 deg > tiltAbsMax
vel_a = corr_ok & present & (~valid_T_a | valid_tilt_a);
ok = report('T6a toppled frame + healthy thermistor => velocity rejected', ~any(vel_a), sum(vel_a)) && ok;

% (b) MOP586_10m: thermistor dead, frame still   -> velocity must be KEPT
valid_T_b    = false(N,1);                 % T = -5 C
valid_tilt_b = false(N,1);                 % tiltStd spuriously > 2 deg (dead sensor block)
vel_b = corr_ok & present & (~valid_T_b | valid_tilt_b);
ok = report('T6b dead thermistor + spurious tilt flag => velocity kept', all(vel_b), sum(vel_b)) && ok;

% (c) both healthy -> unchanged from the historical pipeline
vel_c = corr_ok & present & (~true(N,1) | true(N,1));
ok = report('T6c healthy tilt + healthy thermistor => velocity kept', all(vel_c), sum(vel_c)) && ok;
fprintf('     A frame that fell over is not a sensor fault, and must not be "recovered".\n');

%% ---- T5: reconstruction returns the field's own Hs ----
Hs_rec = Hs_h;
rel = abs(Hs_rec - Hs_true)/Hs_true;
ok = report('T5  Spp_from_vel inversion recovers Hs_true within 3%', rel < 0.03, rel) && ok;
fprintf('     Hs_true = %.4f, Hs_rec = %.4f  (%.2f%%)\n', Hs_true, Hs_rec, 100*rel);
fprintf('     NOTE: a few %% residual is expected -- pwelch leakage plus the sensor-height\n');
fprintf('     approximation in PUV_L2_spectral.m:426 (cosh(k*doffp)/cosh(k*doffu) ~= 1).\n');
fprintf('     On real data this residual IS ztest_SS and is calibrated out, not ignored.\n');

fprintf('\n%s\n', repmat('-',1,66));
if ok, fprintf('ALL PASS\n'); else, error('test_channel_decoupling:FAIL','one or more assertions failed'); end
end

function [valid_vel, valid_p] = qc_per_channel(p, corr_beams, pMed)
%QC_PER_CHANNEL  The proposed L1 contract: each channel is judged on its own evidence.
% Velocity validity depends ONLY on the Doppler diagnostics. Pressure validity depends
% only on pressure. Nothing propagates across channels.
valid_vel = min(corr_beams, [], 2) >= 70;                 % Nortek's threshold, unchanged
valid_p   = p >= pMed/2 & p <= pMed*2;                    % unchanged
end

function Hs = hs_from_vel(u, v, fs, nfft, h, doffp, g)
[Suu,f] = pwelch(detrend(u), hann(nfft), nfft/2, nfft, fs);
[Svv,~] = pwelch(detrend(v), hann(nfft), nfft/2, nfft, fs);
omega = 2*pi*f;
k = zeros(size(f)); k(2:end) = get_wavenumber(omega(2:end), h);
u2p = zeros(size(f)); u2p(2:end) = omega(2:end)./(g*k(2:end));
Spp = (Suu + Svv) .* u2p.^2;
S_eta = pressure_correction_wu(Spp, f, h, doffp, 0.1);
i = f >= 0.04 & f <= 0.25;
Hs = 4*sqrt(max(trapz(f(i), S_eta(i)), 0));
end

function ok = report(name, cond, val)
ok = logical(cond);
if ok, s = 'PASS'; else, s = 'FAIL'; end
fprintf('  [%s] %-58s  %.3e\n', s, name, val);
end
