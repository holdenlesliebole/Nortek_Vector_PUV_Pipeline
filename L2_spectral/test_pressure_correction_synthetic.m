function test_pressure_correction_synthetic()
% TEST_PRESSURE_CORRECTION_SYNTHETIC  Rule-4 closure for the Hs/pressure path.
%
% Paper 1's wave-climate numbers (Hs, energy flux, Ursell) flow through
% shared/pressure_correction_linear.m (Spp -> S_eta -> Hs). The 2026-06 bug was in a
% DIFFERENT routine (the Spp_from_vel z-test, now fixed + regression-tested), but
% this path was never independently certified. This generates a monochromatic
% wave of KNOWN surface amplitude, builds the pressure PSD it would produce at a
% sensor via FIRST PRINCIPLES (independent dispersion), runs the actual routine,
% and asserts it recovers the known Hs. Validates the Kp transfer AND the
% pipeline's get_wavenumber together.
%
% Author: Holden Leslie-Bole, 2026-06-06

addpath('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/shared');
g = 9.81;

a = 0.50; f0 = 0.08; H = 8.0; z_s = 0.50;          % wave amp, freq, depth, sensor height
% independent dispersion (not get_wavenumber)
k0 = f0; w0 = 2*pi*f0; k0 = w0^2/g;
for i=1:200, k0 = w0^2/(g*tanh(k0*H)); end
Kp0 = cosh(k0*z_s)/cosh(k0*H);                     % surface->sensor pressure transfer

% pressure PSD (m^2/Hz) a single spike at f0 carrying variance (a*Kp0)^2/2
f = (0:0.005:0.5)'; df = mean(diff(f));
[~, i0] = min(abs(f - f0));
Spp_m = zeros(numel(f),1);
Spp_m(i0) = ((a*Kp0)^2/2) / df;                    % m0_p = (a*Kp0)^2/2

[S_eta, Kp, ~] = pressure_correction_linear(Spp_m, f, H, z_s);

m0_rec  = sum(S_eta*df);
Hs_rec  = 4*sqrt(m0_rec);
Hs_true = 4*sqrt(a^2/2);                            % = 2*sqrt(2)*a

fprintf('\n=== Rule-4 synthetic closure: pressure_correction_linear (Hs path) ===\n');
fprintf('a=%.2f m, f0=%.3f Hz, H=%.1f m, z_sensor=%.2f m\n', a, f0, H, z_s);
fprintf('%-18s %10s %10s %7s\n','quantity','routine','analytic','err');
fprintf('%-18s %10.4f %10.4f %6.2f%%\n','Kp @ f0', Kp(i0), Kp0, 100*abs(Kp(i0)-Kp0)/Kp0);
fprintf('%-18s %10.4f %10.4f %6.2f%%\n','Hs (m)', Hs_rec, Hs_true, 100*abs(Hs_rec-Hs_true)/Hs_true);

assert(abs(Kp(i0)-Kp0)/Kp0 < 0.01, 'FAIL: Kp transfer off >1%% (dispersion or formula)');
assert(abs(Hs_rec-Hs_true)/Hs_true < 0.01, 'FAIL: recovered Hs off >1%% from known wave');
fprintf('\nPASS: pressure->Hs path recovers a known wave to <1%%. Hs/energy path exonerated.\n');
end
