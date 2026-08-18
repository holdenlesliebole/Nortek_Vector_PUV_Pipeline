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

% --- D50 source: only use site_grain_size's per-site D50 when L2.tau_b
% was computed with the matching per-site methodology (bedstress_method ==
% 'bed_stress_ks'). For legacy L2 (bedstress_method missing or
% 'bed_stress_legacy'), Shields normalization sticks with L2.params.D50 so
% tau_b and shields stay internally consistent within L3.
D50 = L2.params.D50;
D50_source = 'L2.params.D50';
bsLabel = '';
if isfield(L2,'label') && ~isempty(L2.label), bsLabel = char(L2.label); end
useSiteD50 = isfield(L2,'params') && isfield(L2.params,'bedstress_method') ...
             && strcmp(L2.params.bedstress_method, 'bed_stress_ks');
if useSiteD50 && ~isempty(bsLabel) && exist('site_grain_size','file') == 2
    try
        gs = site_grain_size(bsLabel);
        D50 = gs.D50;
        D50_source = sprintf('site_grain_size("%s", %s)', bsLabel, char(gs.status));
    catch
        % fall back silently to L2.params.D50
    end
end

validIdx = L2.segValid;
nSeg = length(L2.time);

%% Pre-allocate
nanVec = NaN(nSeg, 1);

L3.Fb          = nanVec;  % bottom energy flux (W/m)
L3.shields     = nanVec;  % Shields parameter
L3.mobilized   = false(nSeg, 1);  % above critical Shields
% Retired fields. This function APPENDS to the L3 it is handed, so a field that
% is simply no longer written survives from whatever produced the file before.
% Anything retired must be removed explicitly or it silently persists as stale
% derived state. `rouse_legacy` existed only briefly on 2026-08-13 and was
% dropped: a knowingly-wrong Rouse number sitting beside the correct one is a
% trap for anyone reading L3 later.
RETIRED = {'rouse_legacy'};
for r = RETIRED
    if isfield(L3, r{1}), L3 = rmfield(L3, r{1}); end
end

L3.rouse       = nanVec;  % Rouse number (from tau_m; see note below)
L3.tau_c       = nanVec;  % current-related bed shear stress (Pa)
L3.tau_m       = nanVec;  % Soulsby (1997) MEAN combined wave-current stress (Pa)
L3.tau_max     = nanVec;  % Soulsby (1997) MAX combined wave-current stress (Pa)
L3.Fb_cum      = nanVec;  % cumulative bottom flux (J/m)

% -----------------------------------------------------------------------------
% ROUSE SEMANTICS CHANGED 2026-08-13. L3.rouse previously came from L2.tau_b, the
% oscillatory WAVE stress amplitude 0.5*rho*f_w*Ub^2. That is the wrong stress for
% a Rouse number: the profile assumes a steady boundary layer with diffusivity
% kappa*u_star*z over the water column, whereas the wave boundary layer is only
% centimetres thick, and an amplitude is not a mean. Both errors inflate u_star,
% so the old field OVERSTATES suspension.
%
% L3.rouse now uses tau_m from WAVE_CURRENT_STRESS. The superseded value is NOT
% carried alongside it: a field that is known to be wrong is a trap in a shared
% product, and anyone reading L3 later would have to know which of two Rouse
% numbers to trust. Rollback and audit are served instead by the pre-change
% backups in outputs/_pre_rouse_backup_2026-08-13/, by transport_params.code_version,
% and by the entry in docs/audit.md.
%
% SAFE TO CHANGE: an audit on 2026-08-13 found NO consumer of L3.rouse anywhere in
% the research tree. L4 pulls shields and mobilized only; rouse appeared solely in
% two regen comparison lists. No existing scientific result depends on this field.
%
% L3.shields and L3.mobilized are UNCHANGED and were never wrong. The wave stress
% amplitude IS the correct quantity for a wave-mobilization Shields number.
% -----------------------------------------------------------------------------

% Transport-relevant velocity products (from L2, copied for convenience)
L3.Ub          = L2.Ub;
L3.tau_b       = L2.tau_b;
L3.uMean       = L2.uMean;
L3.vMean       = L2.vMean;

%% Compute per segment
f = L2.f;
df = f(2) - f(1);
iSS = f >= 0.04 & f <= 0.25;

% Settling velocity for Rouse number.
% NOTE the C2 default is Ferguson & Church's smooth-sphere value (0.4); natural
% sand is 1.0. The default is deliberately frozen because it feeds Paper 1's
% Bailard suspended load. See shared/settling_velocity.m.
nu = 1e-6;
ws = settling_velocity(D50, rho_s, rho, nu);

% Critical Shields parameter (Soulsby & Whitehouse 1997) via the shared helper.
% Was inlined here until 2026-08-13; the inline expression was numerically
% identical (0 relative difference over D50 = 100-500 um), so this is a
% de-duplication, not a correction.
[theta_cr, Dstar] = soulsby_whitehouse_theta_cr(D50, rho_s, rho, nu, g);

% Drag coefficient converting the burst-mean flow to a current-related stress.
% Applied to the mean velocity at sensor height. ASSUMPTION, not measured.
Cd_current = 2.5e-3;

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

    % --- Combined wave-current bed shear stress (Soulsby 1997) ---
    % tau_max governs entrainment; tau_m governs the time-averaged diffusivity
    % and is therefore what belongs in a Rouse exponent.
    uM = L2.uMean(i); vM = L2.vMean(i);
    if ~isnan(uM) && ~isnan(vM)
        tau_cur = rho * Cd_current * (uM^2 + vM^2);
        L3.tau_c(i) = tau_cur;
        if ~isnan(tau)
            [L3.tau_m(i), L3.tau_max(i)] = wave_current_stress(tau_cur, tau);
        end
    end

    % --- Rouse number ---
    if ~isnan(L3.tau_m(i)) && L3.tau_m(i) > 0
        L3.rouse(i) = rouse_number(ws, L3.tau_m(i), rho);
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
L3.transport_params.D50        = D50;
L3.transport_params.D50_source = D50_source;
L3.transport_params.rho_s      = rho_s;
L3.transport_params.theta_cr   = theta_cr;
L3.transport_params.ws         = ws;
L3.transport_params.tau_cr     = theta_cr * (rho_s - rho) * g * D50;
L3.transport_params.Dstar      = Dstar;
L3.transport_params.Cd_current = Cd_current;
L3.transport_params.rouse_stress = 'tau_m (Soulsby 1997 wave-current mean)';
L3.transport_params.code_version = 'PUV_L3_transport/2026-08-13';

%% Summary
fprintf('  L3c transport proxies:\n');
fprintf('    D50 = %.3f mm (source: %s), ws = %.4f m/s, theta_cr = %.4f, tau_cr = %.3f Pa\n', ...
    D50*1000, D50_source, ws, theta_cr, L3.transport_params.tau_cr);
fprintf('    Fb:     median = %.0f W/m, max = %.0f W/m\n', ...
    median(L3.Fb(validIdx), 'omitnan'), max(L3.Fb(validIdx), [], 'omitnan'));
fprintf('    Shields: median = %.3f, max = %.3f\n', ...
    median(L3.shields(validIdx), 'omitnan'), max(L3.shields(validIdx), [], 'omitnan'));
fprintf('    Mobilized: %d/%d segments (%.0f%%)\n', ...
    sum(L3.mobilized(validIdx)), sum(validIdx), ...
    100*sum(L3.mobilized(validIdx))/sum(validIdx));

% Rouse classification (from tau_m -- see the note at the top of this file)
rouse_valid = L3.rouse(validIdx & ~isnan(L3.rouse));
if ~isempty(rouse_valid)
    % Label via the shared classifier so the bands cannot drift apart.
    % NOTE the top band is "no suspension", NOT "no motion": the Rouse number
    % says nothing about whether the bed moves, only whether it goes into
    % suspension. Mobilization is the Shields test reported above, and at this
    % site the bed is typically mobilized while not suspended, which is exactly
    % the wide bedload window expected in shallow water.
    [~, reg] = rouse_number(median(rouse_valid) * 0.41 * sqrt(1/rho), 1, rho);
    fprintf('    Rouse: median = %.2f  —  %s\n', median(rouse_valid), reg{1});
end

fprintf('    Cumulative Fb: %.2e J/m over deployment\n', ...
    L3.Fb_cum(end));

end
