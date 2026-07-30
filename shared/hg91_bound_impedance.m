function [z2full, z2kin, C1, C2, k3] = hg91_bound_impedance(f1, f2, dth, h, d)
% HG91_BOUND_IMPEDANCE  Full second-order pressure-velocity impedance of a
% forced (bound) sum-interaction wave at a near-bed sensor, from the complete
% Hasselmann interaction coefficient as given by Herbers & Guza (1991).
%
%   [z2full, z2kin, C1, C2, k3] = hg91_bound_impedance(f1, f2, dth, h, d)
%
% WHY THIS EXISTS. The pipeline's ztest assumes the free-wave impedance
% S_uu/S_pp = (g k_free/sigma)^2 at every frequency. For a bound wave the
% earlier "kinematic-only" prediction z2 = (k_free/k3)^2 used only the forced
% POTENTIAL's pressure, i.e. linearized Bernoulli. The foundations audit
% (PUV_paper/docs/audit_foundations_2026-07-29.md) found that omission: at
% second order the pressure also carries the coherent quadratic term
% -(1/2)rho|grad phi1|^2 at the sum frequency, at the SAME order. This function
% supplies the complete answer from published, field-validated theory.
%
% SOURCE. Herbers & Guza (1991), "Wind-wave nonlinearity observed at the sea
% floor. Part I: Forced-wave energy," JPO 21, 1740-1761, eq. (4) — the
% second-order bottom-pressure interaction coefficient C(s1 f1, s2 f2, dtheta)
% from Hasselmann (1962)/Hasselmann et al. (1963), sum branch s1 = s2 = +1.
% Its two terms are exactly the needed split:
%
%   C1 (their 1st term) = the quadratic Bernoulli pressure. At the bed it
%        equals -(s1 s2 cos dth)/(2 g sinh(k1 h) sinh(k2 h)) — verified
%        algebraically identical to -(u1.u2)/(2g) there.
%   C2 (their 2nd term) = the forced-potential pressure -(1/g) d(phi2)/dt,
%        carrying the resonance denominator [g k3 tanh(k3 h) - (s1+s2)^2].
%
% Since velocity is exactly grad(phi), the sum-frequency VELOCITY comes from
% phi2 alone: with phi2 = B cosh(k3(z+h)) sin(th1+th2) and the bed pressure
% giving B = C2*g/sigma3,
%
%   u2(d) = C2 * (g k3/sigma3) * cosh(k3 d)          [per unit a1 a2]
%   p2(d) = C1(d) + C2*cosh(k3 d)                    [head, per unit a1 a2]
%
% and against the pipeline's free-wave conversion (PUV_L2_spectral.m:556-566):
%
%   z2full = (k_a/k3)^2 * [ 1 + C1(d)/(C2 cosh(k3 d)) ]^2 ,  k_a = k_free(f1+f2)
%
% Elevation dependence: C2 scales as cosh(k3 d); C1(d) follows from the u- and
% w-products at elevation d,
%   C1(d) = -(s1 s2/(2g sinh(k1h) sinh(k2h)))
%           * [cos(dth) cosh(k1 d) cosh(k2 d) - sinh(k1 d) sinh(k2 d)]
% (the w-product enters without cos(dth): vertical velocities are scalars).
% At our sensor heights k*d ~ 0.03-0.1, so these factors are ~1.
%
% VALIDATED against five published anchors (see test_kp_bound_harmonic.m):
%   - Miche/Longuet-Higgins special case: C(dth=pi, f1=f2) = -2 pi^2 f^2/g,
%     reproduced to 6 digits (f = f1+f2 = 0.4 Hz, h = 13 m: -0.321944).
%   - All four HG91 Fig. 7 caption values: f=0.4 Hz dth=0: -3.7e-3; dth=180:
%     -0.32; f=0.5 Hz dth=0: -7.0e-4; dth=180: -0.50 m^-1.
%
% THE PHYSICS RESULT (why this matters): C1/C2 < 0 for collinear sum
% interactions in our regime — the quadratic term OPPOSES the forced-potential
% pressure — and z2full is nearly FLAT at ~1.04-1.08 over 5-16 m, versus the
% kinematic-only 1.14-1.71. The kh-dependence largely cancels. Consequences:
% the impedance diagnostic has much weaker discriminating power than the
% kinematic formula implied (z2_pred - 1 is only ~2-3x the known measurement
% systematics), and any bound-fraction inversion through it carries that
% sensitivity. State this wherever z2-based beta is quoted.
%
% SCOPE. Sum interactions (super-harmonics) only. Collinear geometry is the
% caller's choice via dth; directional spread reduces |C1| through cos(dth) and
% reduces k3, both of which the caller can represent by passing dth > 0.
% Near-resonance amplification as kh -> 0 is physical (HG91 note resonance
% requires kh << 1, "a case not considered here"); no singularity in our range.
%
% INPUTS
%   f1, f2 - primary frequencies (Hz), scalars or equal-size arrays
%   dth    - angle between the primaries (rad)
%   h      - water depth (m)
%   d      - sensor elevation above the bed (m)
% OUTPUTS
%   z2full - complete second-order z^2 prediction for a fully bound component
%   z2kin  - the kinematic-only (k_a/k3)^2, retained for comparison
%   C1, C2 - the two coefficient terms, at elevation d (C2 includes cosh(k3 d))
%   k3     - bound wavenumber |k1 + k2| (rad/m)
%
% REQUIRES get_wavenumber.m
% Author: Holden Leslie-Bole, 2026

g  = 9.81;
s1 = 2*pi*f1;  s2 = 2*pi*f2;  s3 = s1 + s2;

k1 = get_wavenumber(s1, h);
k2 = get_wavenumber(s2, h);
k3 = sqrt(k1.^2 + k2.^2 + 2.*k1.*k2.*cos(dth));    % |k1 + k2|
ka = get_wavenumber(s3, h);

% --- quadratic Bernoulli term at elevation d ---------------------------
C1 = -(s1.*s2 ./ (2*g*sinh(k1.*h).*sinh(k2.*h))) .* ...
     (cos(dth).*cosh(k1.*d).*cosh(k2.*d) - sinh(k1.*d).*sinh(k2.*d));

% --- forced-potential term, HG91 eq. (4) second term, times cosh(k3 d) --
denom = (g.*k3.*tanh(k3.*h) - s3.^2) .* s1.*s2.*cosh(k3.*h);
brace = s3.*((s1.*s2).^2./g^2 - k1.*k2.*cos(dth)) ...
        - 0.5*(s1.*k2.^2./cosh(k2.*h).^2 + s2.*k1.^2./cosh(k1.*h).^2);
C2 = (g.*s3./denom) .* brace .* cosh(k3.*d);

z2kin  = (ka./k3).^2;
z2full = z2kin .* (1 + C1./C2).^2;
end
