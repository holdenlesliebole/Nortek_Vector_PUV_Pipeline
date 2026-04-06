function verify_L2_products(L2)
% VERIFY_L2_PRODUCTS  Sanity-check all L2 derived products.
%
%   verify_L2_products(L2)
%
%   Checks:
%     1. Bed velocity: compare Ub against linear theory prediction
%     2. Bed stress: verify tau_b scales with Ub^2, check Shields number
%     3. Reynolds stress: TKE scaling, uw sign (should be negative under waves)
%     4. Velocity moments: skewness/asymmetry ranges and depth dependence
%     5. Mean currents: check magnitudes are physically reasonable
%     6. Internal consistency: Hs vs Ub vs tau_b correlations

g = 9.81;
rho = 1025;

validIdx = L2.segValid;
nValid = sum(validIdx);

fprintf('\n================================================================\n');
fprintf(' L2 Product Verification: %s (%s)\n', L2.label, L2.deploymentName);
fprintf(' Depth: %.1f m | %d valid segments\n', median(L2.depth(validIdx), 'omitnan'), nValid);
fprintf('================================================================\n');

%% ======================== 1. BED VELOCITY ========================
fprintf('\n--- 1. Bed Orbital Velocity ---\n');

Ub = L2.Ub(validIdx);
Hs = L2.Hs(validIdx);
Tp = L2.Tp(validIdx);
depth = L2.depth(validIdx);

fprintf('  Ub:  min=%.3f, max=%.3f, mean=%.3f, median=%.3f m/s\n', ...
    min(Ub), max(Ub), mean(Ub, 'omitnan'), median(Ub, 'omitnan'));
fprintf('  uBed_rms: median=%.3f m/s\n', median(L2.uBed_rms(validIdx), 'omitnan'));
fprintf('  vBed_rms: median=%.3f m/s\n', median(L2.vBed_rms(validIdx), 'omitnan'));

% Spectral bed velocity prediction from S_eta:
%   Ub_rms^2 = integral[ (omega/sinh(kh))^2 * S_eta(f) * df ]
% This is the proper broadband comparison (not monochromatic amplitude).
f_puv = L2.f;
df = f_puv(2) - f_puv(1);
iSS = f_puv >= 0.04 & f_puv <= 0.25;
Ub_spectral = NaN(nValid, 1);

validTimes = find(validIdx);
for i = 1:nValid
    ii = validTimes(i);
    h = depth(i);
    S = L2.S_eta(:, ii);
    if isnan(h) || h <= 0, continue; end

    omega_f = 2*pi*f_puv(iSS);
    k_f = get_wavenumber(omega_f, h);
    transfer = omega_f ./ sinh(k_f * h);

    Ub2 = sum(transfer.^2 .* S(iSS) * df);
    Ub_spectral(i) = sqrt(Ub2);
end

good = ~isnan(Ub) & ~isnan(Ub_spectral) & Ub_spectral > 0;
if sum(good) > 20
    R_tmp = corrcoef(Ub(good), Ub_spectral(good));
    R_Ub_spec = R_tmp(1,2);
    ratio_Ub_spec = median(Ub(good) ./ Ub_spectral(good));
    fprintf('  Ub vs spectral theory: R=%.3f, median ratio=%.3f\n', R_Ub_spec, ratio_Ub_spec);
    if ratio_Ub_spec > 0.7 && ratio_Ub_spec < 1.5 && R_Ub_spec > 0.8
        fprintf('  --> PASS: Ub matches spectral theory well\n');
    else
        fprintf('  --> CHECK: ratio or correlation outside expected range\n');
    end
else
    R_Ub_spec = NaN; ratio_Ub_spec = NaN;
    fprintf('  Insufficient data for Ub spectral comparison\n');
end

%% ======================== 2. BED STRESS ========================
fprintf('\n--- 2. Bed Shear Stress ---\n');

tau_b = L2.tau_b(validIdx);
fric_w = L2.fric_w(validIdx);
Aw = L2.Aw(validIdx);

fprintf('  tau_b:  min=%.3f, max=%.3f, mean=%.3f, median=%.3f Pa\n', ...
    min(tau_b, [], 'omitnan'), max(tau_b, [], 'omitnan'), ...
    mean(tau_b, 'omitnan'), median(tau_b, 'omitnan'));
fprintf('  fric_w: min=%.4f, max=%.4f, median=%.4f\n', ...
    min(fric_w, [], 'omitnan'), max(fric_w, [], 'omitnan'), median(fric_w, 'omitnan'));
fprintf('  Aw:     min=%.3f, max=%.3f, median=%.3f m\n', ...
    min(Aw, [], 'omitnan'), max(Aw, [], 'omitnan'), median(Aw, 'omitnan'));

% tau_b should scale as 0.5*rho*fw*Ub^2
tau_check = 0.5 * rho * median(fric_w, 'omitnan') * median(Ub, 'omitnan')^2;
fprintf('  Consistency: 0.5*rho*fw*Ub^2 = %.3f Pa (vs median tau_b = %.3f Pa)\n', ...
    tau_check, median(tau_b, 'omitnan'));

% Shields number
D50 = L2.params.D50;
rho_s = 2650;
theta_shields = tau_b ./ ((rho_s - rho) * g * D50);
fprintf('  Shields number: median=%.3f, max=%.3f\n', ...
    median(theta_shields, 'omitnan'), max(theta_shields, [], 'omitnan'));
fprintf('  Critical Shields (sand): ~0.05\n');
fprintf('  Segments exceeding critical: %d/%d (%.0f%%)\n', ...
    sum(theta_shields > 0.05), nValid, 100*sum(theta_shields > 0.05)/nValid);

%% ======================== 3. REYNOLDS STRESS ========================
fprintf('\n--- 3. Reynolds Stress ---\n');

uw = L2.reynolds.uw(validIdx);
vw = L2.reynolds.vw(validIdx);
uv = L2.reynolds.uv(validIdx);
TKE = L2.reynolds.TKE(validIdx);
u_rms = L2.reynolds.u_rms(validIdx);
v_rms = L2.reynolds.v_rms(validIdx);
w_rms = L2.reynolds.w_rms(validIdx);

fprintf('  uw:   min=%+.5f, max=%+.5f, mean=%+.5f m^2/s^2\n', ...
    min(uw, [], 'omitnan'), max(uw, [], 'omitnan'), mean(uw, 'omitnan'));
fprintf('  vw:   min=%+.5f, max=%+.5f, mean=%+.5f m^2/s^2\n', ...
    min(vw, [], 'omitnan'), max(vw, [], 'omitnan'), mean(vw, 'omitnan'));
fprintf('  TKE:  min=%.5f, max=%.5f, median=%.5f m^2/s^2\n', ...
    min(TKE, [], 'omitnan'), max(TKE, [], 'omitnan'), median(TKE, 'omitnan'));
fprintf('  u_rms: median=%.3f m/s\n', median(u_rms, 'omitnan'));
fprintf('  v_rms: median=%.3f m/s\n', median(v_rms, 'omitnan'));
fprintf('  w_rms: median=%.3f m/s\n', median(w_rms, 'omitnan'));

% TKE should correlate with Hs
good = ~isnan(TKE) & ~isnan(Hs);
if sum(good) > 20
    R = corrcoef(Hs(good), TKE(good));
    fprintf('  TKE vs Hs: R=%.3f\n', R(1,2));
    if R(1,2) > 0.5
        fprintf('  --> PASS: TKE scales with wave height\n');
    else
        fprintf('  --> CHECK: weak TKE-Hs correlation\n');
    end
end

% w_rms should be smaller than u_rms and v_rms (horizontal dominates)
ratio_wu = median(w_rms, 'omitnan') / median(u_rms, 'omitnan');
fprintf('  w_rms/u_rms ratio: %.3f (expect < 1)\n', ratio_wu);

%% ======================== 4. VELOCITY MOMENTS ========================
fprintf('\n--- 4. Velocity Moments ---\n');

sk = L2.vmom.skewness(validIdx);
as = L2.vmom.asymmetry(validIdx);
u_abs3 = L2.vmom.u_abs3(validIdx);
u_uabs2 = L2.vmom.u_uabs2(validIdx);

fprintf('  Skewness:  min=%+.3f, max=%+.3f, mean=%+.3f, median=%+.3f\n', ...
    min(sk, [], 'omitnan'), max(sk, [], 'omitnan'), ...
    mean(sk, 'omitnan'), median(sk, 'omitnan'));
fprintf('  Asymmetry: min=%+.3f, max=%+.3f, mean=%+.3f, median=%+.3f\n', ...
    min(as, [], 'omitnan'), max(as, [], 'omitnan'), ...
    mean(as, 'omitnan'), median(as, 'omitnan'));
fprintf('  |u|^3:     median=%.5f m^3/s^3\n', median(u_abs3, 'omitnan'));
fprintf('  u|u|^2:    median=%+.5f m^3/s^3\n', median(u_uabs2, 'omitnan'));

% Physical expectations:
% - Skewness should be positive (peaked crests, flat troughs) in shoaling waves
% - Asymmetry should be negative (pitched-forward, sawtooth shape)
% - Both should increase in magnitude with decreasing depth (more nonlinear)
if median(sk, 'omitnan') > 0
    fprintf('  --> Skewness positive: consistent with shoaling waves\n');
else
    fprintf('  --> CHECK: median skewness is negative (unexpected for shoaling waves)\n');
end
if median(as, 'omitnan') < 0
    fprintf('  --> Asymmetry negative: consistent with pitched-forward waves\n');
elseif abs(median(as, 'omitnan')) < 0.05
    fprintf('  --> Asymmetry near zero: waves are symmetric (expected in deeper water)\n');
else
    fprintf('  --> CHECK: median asymmetry is positive (unusual)\n');
end

% Ursell number vs skewness correlation (should be positive)
Ur = NaN(nValid, 1);
for i = 1:nValid
    if ~isnan(Hs(i)) && ~isnan(Tp(i)) && ~isnan(depth(i)) && Tp(i) > 0
        omega = 2*pi/Tp(i);
        k = get_wavenumber(omega, depth(i));
        Lp = 2*pi/k;
        Ur(i) = Hs(i) * Lp^2 / depth(i)^3;
    end
end
good = ~isnan(sk) & ~isnan(Ur) & Ur < 200;
if sum(good) > 20
    R = corrcoef(Ur(good), sk(good));
    fprintf('  Skewness vs Ursell: R=%.3f (expect positive)\n', R(1,2));
end

%% ======================== 5. MEAN CURRENTS ========================
fprintf('\n--- 5. Mean Currents ---\n');

uMean = L2.uMean(validIdx);
vMean = L2.vMean(validIdx);
wMean = L2.wMean(validIdx);

fprintf('  uMean (cross-shore): min=%+.3f, max=%+.3f, mean=%+.3f m/s\n', ...
    min(uMean, [], 'omitnan'), max(uMean, [], 'omitnan'), mean(uMean, 'omitnan'));
fprintf('  vMean (alongshore):  min=%+.3f, max=%+.3f, mean=%+.3f m/s\n', ...
    min(vMean, [], 'omitnan'), max(vMean, [], 'omitnan'), mean(vMean, 'omitnan'));
fprintf('  wMean (vertical):    min=%+.3f, max=%+.3f, mean=%+.3f m/s\n', ...
    min(wMean, [], 'omitnan'), max(wMean, [], 'omitnan'), mean(wMean, 'omitnan'));

% Physical checks
if abs(mean(uMean, 'omitnan')) < 0.5
    fprintf('  --> Mean cross-shore current magnitude reasonable\n');
else
    fprintf('  --> CHECK: mean cross-shore current seems large\n');
end
if abs(mean(wMean, 'omitnan')) < 0.05
    fprintf('  --> Mean vertical velocity near zero: expected\n');
else
    fprintf('  --> CHECK: mean vertical velocity non-zero (tilt issue?)\n');
end

%% ======================== 6. INTERNAL CONSISTENCY ========================
fprintf('\n--- 6. Internal Consistency ---\n');

% Hs vs Ub correlation
good = ~isnan(Hs) & ~isnan(Ub);
R_Hs_Ub = corrcoef(Hs(good), Ub(good));
fprintf('  Hs vs Ub: R=%.3f (expect > 0.9)\n', R_Hs_Ub(1,2));

% Ub vs tau_b correlation
good = ~isnan(Ub) & ~isnan(tau_b);
R_Ub_tau = corrcoef(Ub(good), tau_b(good));
fprintf('  Ub vs tau_b: R=%.3f (expect > 0.9)\n', R_Ub_tau(1,2));

% Hs vs TKE correlation
good = ~isnan(Hs) & ~isnan(TKE);
R_Hs_TKE = corrcoef(Hs(good), TKE(good));
fprintf('  Hs vs TKE: R=%.3f (expect > 0.5)\n', R_Hs_TKE(1,2));

% Ef vs Hs^2 correlation (energy flux should scale as Hs^2)
Ef = L2.Ef(validIdx);
good = ~isnan(Ef) & ~isnan(Hs);
R_Ef_Hs2 = corrcoef(Hs(good).^2, Ef(good));
fprintf('  Ef vs Hs^2: R=%.3f (expect > 0.9)\n', R_Ef_Hs2(1,2));

%% ======================== 7. TEMPERATURE ========================
fprintf('\n--- 7. Temperature ---\n');
Tmean = L2.Tmean(validIdx);
fprintf('  Tmean: min=%.1f, max=%.1f, mean=%.1f C\n', ...
    min(Tmean, [], 'omitnan'), max(Tmean, [], 'omitnan'), mean(Tmean, 'omitnan'));
if min(Tmean, [], 'omitnan') > 5 && max(Tmean, [], 'omitnan') < 30
    fprintf('  --> Temperature range reasonable for SoCal\n');
end

%% ======================== SUMMARY ========================
fprintf('\n--- VERIFICATION SUMMARY ---\n');
checks = {
    'Ub vs spectral theory', R_Ub_spec > 0.8 && ratio_Ub_spec > 0.7 && ratio_Ub_spec < 1.5;
    'TKE vs Hs', R_Hs_TKE(1,2) > 0.5;
    'Hs vs Ub', R_Hs_Ub(1,2) > 0.9;
    'Ub vs tau_b', R_Ub_tau(1,2) > 0.9;
    'Ef vs Hs^2', R_Ef_Hs2(1,2) > 0.9;
    'Skewness positive', median(sk, 'omitnan') > 0;
    'w_rms < u_rms', ratio_wu < 1;
    'Temperature range', min(Tmean,[],'omitnan') > 5 && max(Tmean,[],'omitnan') < 30;
};

nPass = 0;
for c = 1:size(checks, 1)
    if checks{c, 2}
        status = 'PASS';
        nPass = nPass + 1;
    else
        status = 'CHECK';
    end
    fprintf('  [%s] %s\n', status, checks{c, 1});
end
fprintf('\n  %d/%d checks passed\n', nPass, size(checks, 1));

%% ======================== DIAGNOSTIC FIGURE ========================
fig = figure('Position', [50 50 1400 900], 'Color', 'w');

subplot(3,3,1)
scatter(Ub_spectral(good), Ub(good), 4, 'filled', 'MarkerFaceAlpha', 0.2);
hold on; plot([0 0.5], [0 0.5], 'k--');
xlabel('Ub spectral theory (m/s)'); ylabel('Ub IFFT (m/s)');
title('Bed velocity: IFFT vs spectral'); grid on; axis equal;

subplot(3,3,2)
scatter(Ub(~isnan(tau_b)), tau_b(~isnan(tau_b)), 4, 'filled', 'MarkerFaceAlpha', 0.2);
xlabel('Ub (m/s)'); ylabel('\tau_b (Pa)');
title('Bed stress vs orbital velocity'); grid on;

subplot(3,3,3)
scatter(Hs(~isnan(TKE)), TKE(~isnan(TKE)), 4, 'filled', 'MarkerFaceAlpha', 0.2);
xlabel('Hs (m)'); ylabel('TKE (m^2/s^2)');
title('TKE vs wave height'); grid on;

subplot(3,3,4)
histogram(sk(~isnan(sk)), 50, 'Normalization', 'pdf');
xlabel('Skewness'); ylabel('PDF');
title(sprintf('Velocity skewness (median=%.3f)', median(sk,'omitnan')));
xline(0, 'k--'); grid on;

subplot(3,3,5)
histogram(as(~isnan(as)), 50, 'Normalization', 'pdf');
xlabel('Asymmetry'); ylabel('PDF');
title(sprintf('Acceleration asymmetry (median=%.3f)', median(as,'omitnan')));
xline(0, 'k--'); grid on;

subplot(3,3,6)
scatter(Ur(good), sk(good), 4, 'filled', 'MarkerFaceAlpha', 0.2);
xlabel('Ursell number'); ylabel('Skewness');
title('Nonlinearity vs skewness'); grid on; xlim([0 150]);

subplot(3,3,7)
plot(L2.time(validIdx), uMean, '.', 'MarkerSize', 2);
xlabel('Time'); ylabel('m/s');
title('Cross-shore mean current'); grid on;

subplot(3,3,8)
plot(L2.time(validIdx), vMean, '.', 'MarkerSize', 2);
xlabel('Time'); ylabel('m/s');
title('Alongshore mean current'); grid on;

subplot(3,3,9)
scatter(Hs(~isnan(Ef)), Ef(~isnan(Ef)), 4, 'filled', 'MarkerFaceAlpha', 0.2);
xlabel('Hs (m)'); ylabel('Ef (W/m)');
title('Energy flux vs Hs'); grid on;

sgtitle(sprintf('%s — %s: L2 Product Verification (h=%.1fm)', ...
    L2.deploymentName, L2.label, median(depth, 'omitnan')), 'FontWeight', 'bold');

diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end
exportgraphics(fig, fullfile(diagDir, sprintf('%s_%s_L2_verification.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
fprintf('\n  Figure saved.\n');

end
