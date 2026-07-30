% COMPARE_WAVENUMBER_METHODS  Compare Newton, Wu (1986), and Bill's kh approximation.
%
%   Plots kh and Kp (pressure correction) from three methods:
%     1. Newton's method (get_wavenumber.m) — exact to 1e-10
%     2. Wu & Thornton (1986) Eqs. 6/8/9 — published approximation
%     3. Bill O'Reilly's modified Wu — coefficients from PUV_all_in_one.m
%
%   Also shows the resulting Hs correction factor (1/Kp^2 integrated)
%   to quantify the practical impact on wave height estimates.
% Author: Holden Leslie-Bole, 2026

startup_puv

g = 9.81;

% Frequency range matching PUV analysis
f = 0.005:0.005:0.5;  % Hz
nf = length(f);

% Test at two representative depths
depths = [6.2, 8.3];  % MOP580_5m and MOP580_7m total depths
z_sensor = 0.77;       % doffp

for iDepth = 1:2
    H = depths(iDepth);

    kh_newton = zeros(nf, 1);
    kh_wu86   = zeros(nf, 1);
    kh_bill   = zeros(nf, 1);

    for n = 1:nf
        omega = 2*pi*f(n);

        % --- Method 1: Newton's method (exact) ---
        k_exact = get_wavenumber(omega, H);
        kh_newton(n) = k_exact * H;

        % --- Method 2: Wu & Thornton (1986) paper ---
        % x = sigma^2 * h / g  (dimensionless depth parameter)
        x = omega^2 * H / g;
        Lo = g / (2*pi * f(n)^2);  % deep water wavelength

        if H/Lo < 0.2
            % Shallow water: Eq. 6
            kh_wu86(n) = sqrt(x) * (1 + x/6 * (1 + x/5));
        else
            % Deep water: Eq. 8 then Eq. 9
            y_prime = x * (1 + 1.26 * exp(-1.84 * x));
            t = exp(-2 * y_prime);
            kh_wu86(n) = x * (1 + 2*t*(1 + t));  % Eq. 9
        end

        % --- Method 3: Bill O'Reilly's version ---
        uo = 2*pi*H / Lo;
        kh_bill(n) = uo * (1 + (uo^1.09) * exp(-(1.55 + 1.3*uo + 0.216*uo^2))) / sqrt(tanh(uo));
    end

    % Compute Kp for each method
    Kp_newton = cosh(kh_newton * z_sensor / H) ./ cosh(kh_newton);
    Kp_wu86   = cosh(kh_wu86   * z_sensor / H) ./ cosh(kh_wu86);
    Kp_bill   = cosh(kh_bill   * z_sensor / H) ./ cosh(kh_bill);

    % Note: kh = k*H, so k*z_sensor = kh * (z_sensor/H)
    % and k*H = kh, so cosh(k*z)/cosh(k*H) = cosh(kh*z/H)/cosh(kh)

    % Correction factor on spectral density: 1/Kp^2
    corr_newton = 1 ./ Kp_newton.^2;
    corr_wu86   = 1 ./ Kp_wu86.^2;
    corr_bill   = 1 ./ Kp_bill.^2;

    % --- Plots ---
    figure('Position', [100 100 1400 800], 'Name', sprintf('H = %.1f m', H));

    % Panel 1: kh comparison
    subplot(2,2,1)
    plot(f, kh_newton, 'k-', 'LineWidth', 2); hold on
    plot(f, kh_wu86, 'b--', 'LineWidth', 1.5);
    plot(f, kh_bill, 'r-.', 'LineWidth', 1.5);
    xlabel('Frequency (Hz)'); ylabel('kh');
    title(sprintf('Wavenumber kh — H = %.1f m', H));
    legend('Newton (exact)', 'Wu 1986 (paper)', 'Bill O''Reilly', 'Location', 'northwest');
    grid on; xlim([0 0.35]);

    % Panel 2: kh relative error
    subplot(2,2,2)
    err_wu86 = 100 * (kh_wu86 - kh_newton) ./ kh_newton;
    err_bill = 100 * (kh_bill - kh_newton) ./ kh_newton;
    plot(f, err_wu86, 'b--', 'LineWidth', 1.5); hold on
    plot(f, err_bill, 'r-.', 'LineWidth', 1.5);
    yline(0, 'k-');
    xlabel('Frequency (Hz)'); ylabel('Relative error (%)');
    title(sprintf('kh error vs Newton — H = %.1f m', H));
    legend('Wu 1986 (paper)', 'Bill O''Reilly', 'Location', 'northwest');
    grid on; xlim([0 0.35]);

    % Panel 3: Kp comparison
    subplot(2,2,3)
    plot(f, Kp_newton, 'k-', 'LineWidth', 2); hold on
    plot(f, Kp_wu86, 'b--', 'LineWidth', 1.5);
    plot(f, Kp_bill, 'r-.', 'LineWidth', 1.5);
    yline(0.1, 'k:', 'KpMin = 0.1');
    xlabel('Frequency (Hz)'); ylabel('Kp');
    title(sprintf('Pressure transfer function — H = %.1f m, z = %.2f m', H, z_sensor));
    legend('Newton (exact)', 'Wu 1986 (paper)', 'Bill O''Reilly', 'Location', 'northeast');
    grid on; xlim([0 0.35]);

    % Panel 4: Correction factor 1/Kp^2
    subplot(2,2,4)
    semilogy(f, corr_newton, 'k-', 'LineWidth', 2); hold on
    semilogy(f, corr_wu86, 'b--', 'LineWidth', 1.5);
    semilogy(f, corr_bill, 'r-.', 'LineWidth', 1.5);
    yline(100, 'k:', 'KpMin=0.1 → 100x');
    xlabel('Frequency (Hz)'); ylabel('1/Kp^2 (log scale)');
    title(sprintf('Spectral correction factor — H = %.1f m', H));
    legend('Newton (exact)', 'Wu 1986 (paper)', 'Bill O''Reilly', 'Location', 'northwest');
    grid on; xlim([0 0.35]);

    sgtitle(sprintf('Wavenumber method comparison: H = %.1f m, z_{sensor} = %.2f m', H, z_sensor), ...
        'FontWeight', 'bold');

    % Save
    diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
    if ~exist(diagDir, 'dir'), mkdir(diagDir); end
    exportgraphics(gcf, fullfile(diagDir, sprintf('wavenumber_comparison_H%.0fm.png', H)), ...
        'Resolution', 200);
end

% --- Print numerical comparison at key frequencies ---
fprintf('\n=== Numerical comparison at H = 6.2 m, z = 0.77 m ===\n');
fprintf('%-8s  %-10s  %-10s  %-10s  %-10s  %-10s  %-10s\n', ...
    'f (Hz)', 'kh_Newton', 'kh_Wu86', 'kh_Bill', 'Kp_Newton', 'Kp_Wu86', 'Kp_Bill');
fprintf('%s\n', repmat('-', 1, 72));
test_f = [0.05, 0.08, 0.10, 0.15, 0.20, 0.25];
H = 6.2;
for fi = test_f
    omega = 2*pi*fi;
    k_n = get_wavenumber(omega, H);
    kh_n = k_n * H;

    Lo = g / (2*pi*fi^2);
    x = omega^2 * H / g;

    if H/Lo < 0.2
        kh_w = sqrt(x) * (1 + x/6 * (1 + x/5));
    else
        yp = x * (1 + 1.26*exp(-1.84*x));
        t = exp(-2*yp);
        kh_w = x * (1 + 2*t*(1+t));
    end

    uo = 2*pi*H/Lo;
    kh_b = uo*(1 + (uo^1.09)*exp(-(1.55+1.3*uo+0.216*uo^2)))/sqrt(tanh(uo));

    Kp_n = cosh(kh_n*z_sensor/H)/cosh(kh_n);
    Kp_w = cosh(kh_w*z_sensor/H)/cosh(kh_w);
    Kp_b = cosh(kh_b*z_sensor/H)/cosh(kh_b);

    fprintf('%-8.3f  %-10.5f  %-10.5f  %-10.5f  %-10.5f  %-10.5f  %-10.5f\n', ...
        fi, kh_n, kh_w, kh_b, Kp_n, Kp_w, Kp_b);
end
fprintf('\n');
