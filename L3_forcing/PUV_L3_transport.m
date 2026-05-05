function L3 = PUV_L3_transport(L3, L2)
% PUV_L3_TRANSPORT  Level 3c: transport proxy metrics.
%
%   L3 = PUV_L3_transport(L3, L2)
%
%   Computes sediment transport proxies from L2 wave and velocity products.
%   These are universal metrics that characterize transport potential
%   without committing to a specific transport model.
%
%   INPUTS
%     L3 - L3 struct from PUV_L3_bands/storms (gets appended to)
%     L2 - L2 struct from PUV_L2_spectral
%
%   PRODUCTS
%     Bottom energy flux (Fb): spectral integral of cg*S_eta at bed level
%     Shields parameter: dimensionless bed stress / grain weight
%     Mobilization flag: above critical Shields threshold
%     Cumulative bottom flux: running integral of Fb over deployment
%     Rouse number: suspension vs bedload classification
% Author: Holden Leslie-Bole, 2026

g   = 9.81;
rho = 1025;
rho_s = 2650;  % quartz sand density
D50 = L2.params.D50;

validIdx = L2.segValid;
nSeg = length(L2.time);

%% Pre-allocate
nanVec = NaN(nSeg, 1);

L3.Fb          = nanVec;  % bottom energy flux (W/m)
L3.shields     = nanVec;  % Shields parameter
L3.mobilized   = false(nSeg, 1);  % above critical Shields
L3.rouse       = nanVec;  % Rouse number
L3.Fb_cum      = nanVec;  % cumulative bottom flux (J/m)

% Transport-relevant velocity products (from L2, copied for convenience)
L3.Ub          = L2.Ub;
L3.tau_b       = L2.tau_b;
L3.uMean       = L2.uMean;
L3.vMean       = L2.vMean;

%% Compute per segment
f = L2.f;
df = f(2) - f(1);
iSS = f >= 0.04 & f <= 0.25;

% Settling velocity for Rouse number
ws = settling_velocity(D50, rho_s, rho, 1e-6);

% Critical Shields parameter (Soulsby-Whitehouse)
Dstar = D50 * ((rho_s/rho - 1) * g / 1e-12)^(1/3);  % dimensionless grain size
theta_cr = 0.30 / (1 + 1.2*Dstar) + 0.055 * (1 - exp(-0.020*Dstar));

for i = 1:nSeg
    if ~validIdx(i), continue; end

    h = L2.depth(i);
    if isnan(h) || h <= 0, continue; end

    S = L2.S_eta(:, i);

    % --- Bottom energy flux ---
    % Fb = rho*g * integral(cg(f) * S_eta(f) * [1/cosh(k*doffp)]^2 * df)
    % This is the energy flux evaluated at the bed, accounting for
    % depth attenuation of both pressure and velocity.
    omega = 2*pi*f(iSS);
    k = get_wavenumber(omega, h);
    cg = get_cg(k, h);

    % Attenuation to bed: energy scales as cosh^2(kz)/cosh^2(kh)
    % At bed (z=0): attenuation = 1/cosh^2(kh)
    % But for bottom flux we want the energy flux AT the sensor depth
    % shoaled to bed level, which is just rho*g*cg*S_eta integrated.
    % The S_eta is already the surface elevation spectrum, so the
    % energy flux is the same regardless of where we evaluate it
    % (energy conservation in the vertical under linear theory).
    L3.Fb(i) = rho * g * trapz(f(iSS), cg(:) .* S(iSS));

    % --- Shields parameter ---
    tau = L2.tau_b(i);
    if ~isnan(tau)
        L3.shields(i) = tau / ((rho_s - rho) * g * D50);
        L3.mobilized(i) = L3.shields(i) > theta_cr;
    end

    % --- Rouse number ---
    if ~isnan(tau) && tau > 0
        ustar = sqrt(tau / rho);
        kappa = 0.41;  % von Karman constant
        L3.rouse(i) = ws / (kappa * ustar);
    end
end

%% Cumulative bottom flux
% Integrate Fb over time: Fb_cum(t) = integral(Fb * dt) from t0 to t
% Units: W/m * s = J/m (energy per unit coastline length)
dt_sec = median(diff(L2.time(validIdx)));
dt_sec = seconds(dt_sec);

Fb_clean = L3.Fb;
Fb_clean(isnan(Fb_clean)) = 0;  % treat gaps as zero flux (conservative)
L3.Fb_cum = cumsum(Fb_clean) * dt_sec;

%% Store parameters
L3.transport_params.D50 = D50;
L3.transport_params.rho_s = rho_s;
L3.transport_params.theta_cr = theta_cr;
L3.transport_params.ws = ws;

%% Summary
fprintf('  L3c transport proxies:\n');
fprintf('    D50 = %.3f mm, ws = %.4f m/s, theta_cr = %.4f\n', ...
    D50*1000, ws, theta_cr);
fprintf('    Fb:     median = %.0f W/m, max = %.0f W/m\n', ...
    median(L3.Fb(validIdx), 'omitnan'), max(L3.Fb(validIdx), [], 'omitnan'));
fprintf('    Shields: median = %.3f, max = %.3f\n', ...
    median(L3.shields(validIdx), 'omitnan'), max(L3.shields(validIdx), [], 'omitnan'));
fprintf('    Mobilized: %d/%d segments (%.0f%%)\n', ...
    sum(L3.mobilized(validIdx)), sum(validIdx), ...
    100*sum(L3.mobilized(validIdx))/sum(validIdx));

% Rouse classification
rouse_valid = L3.rouse(validIdx & ~isnan(L3.rouse));
if ~isempty(rouse_valid)
    fprintf('    Rouse: median = %.2f  —  ', median(rouse_valid));
    if median(rouse_valid) < 0.8
        fprintf('wash load dominated\n');
    elseif median(rouse_valid) < 1.2
        fprintf('full suspension\n');
    elseif median(rouse_valid) < 2.5
        fprintf('graded suspension\n');
    elseif median(rouse_valid) < 7.5
        fprintf('bedload (saltation)\n');
    else
        fprintf('no significant motion\n');
    end
end

fprintf('    Cumulative Fb: %.2e J/m over deployment\n', ...
    L3.Fb_cum(end));

end
