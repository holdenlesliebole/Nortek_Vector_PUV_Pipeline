function stress = compute_reynolds_stress(u, v, w)
% COMPUTE_REYNOLDS_STRESS  Reynolds stress components from velocity time series.
%
%   stress = compute_reynolds_stress(u, v, w)
%
%   INPUTS
%     u, v, w - velocity components (m/s), equal-length vectors
%               Use detrended velocities if long-term drift is present.
%               Assumes all three are from the same time window (e.g. 2048 samples).
%
%   OUTPUT
%     stress  - struct with fields:
%               .uw, .vw, .uv   - off-diagonal Reynolds stress components (m^2/s^2)
%               .uu, .vv, .ww   - normal stress components (m^2/s^2)
%               .u_rms, .v_rms, .w_rms - RMS velocities (m/s)
%               .TKE            - turbulent kinetic energy (m^2/s^2)
% Author: Holden Leslie-Bole, 2026

u = u(:); v = v(:); w = w(:);

u_prime = u - mean(u, 'omitnan');
v_prime = v - mean(v, 'omitnan');
w_prime = w - mean(w, 'omitnan');

stress.uw = mean(u_prime .* w_prime, 'omitnan');
stress.vw = mean(v_prime .* w_prime, 'omitnan');
stress.uv = mean(u_prime .* v_prime, 'omitnan');

stress.uu = mean(u_prime.^2, 'omitnan');
stress.vv = mean(v_prime.^2, 'omitnan');
stress.ww = mean(w_prime.^2, 'omitnan');

stress.u_rms = sqrt(stress.uu);
stress.v_rms = sqrt(stress.vv);
stress.w_rms = sqrt(stress.ww);

stress.TKE = 0.5 * (stress.uu + stress.vv + stress.ww);
end
