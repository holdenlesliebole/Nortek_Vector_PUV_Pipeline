% TEST_ENU_DECLINATION_CLOSURE  Synthetic closure test for the ENU branch of
% PUV_raw_process.m (enu_to_buoy_frame.m).
%
% A Nortek Vector in ENU mode reports velocities in MAGNETIC East/North. A
% flow toward TRUE bearing b therefore arrives as magnetic bearing b - D:
%     E_mag = |v| sin(b - D),  N_mag = |v| cos(b - D).
% L1 must return the buoy frame (+x WEST, +y NORTH, true):
%     U_west = -|v| sin(b),    V_north = |v| cos(b).
% Expected values are written analytically from b, never from the code.
%
% Criterion fixed before running: max abs error < 1e-12 m/s on every case.
% Cases: 360 bearings x 5 declinations (including 0 and negative) x 3 speeds.
%
% Also runs two deliberately broken variants and requires BOTH to fail:
%   (a) the pre-2026-10-07 ENU branch (U = -E, V = N, no declination)
%   (b) the declination with the wrong sign
% A check never seen to fail is not evidence.
%
% Run from PUV_Pipeline/:  >> run validation/test_enu_declination_closure

% Only add paths if needed: an unconditional startup_puv would re-shadow any
% deliberately broken copy placed ahead of it, and the break test would pass.
if ~exist('enu_to_buoy_frame', 'file'), startup_puv; end
fprintf('enu_to_buoy_frame under test: %s\n', which('enu_to_buoy_frame'));

tol   = 1e-12;
bTrue = (0:359)';                       % true bearing the flow goes TOWARD, deg
Ds    = [11.5 11.07 -14.2 0 3.3];       % declinations, deg (+ = mag N east of true N)
spd   = [0.05 0.6 2.1];                 % m/s

cases = 0; pass = 0; worst = 0;
brokenOld = 0; brokenSign = 0;
for D = Ds
    for s = spd
        Emag = s * sind(bTrue - D);
        Nmag = s * cosd(bTrue - D);
        Uexp = -s * sind(bTrue);
        Vexp =  s * cosd(bTrue);

        [U, V] = enu_to_buoy_frame(Emag, Nmag, D);
        err = max(abs([U - Uexp; V - Vexp]));
        cases = cases + 1; pass = pass + (err < tol); worst = max(worst, err);

        % (a) old branch: no declination
        errA = max(abs([-Emag - Uexp; Nmag - Vexp]));
        brokenOld = brokenOld + (errA >= tol);
        % (b) wrong sign of D
        [Ub, Vb] = enu_to_buoy_frame(Emag, Nmag, -D);
        errB = max(abs([Ub - Uexp; Vb - Vexp]));
        brokenSign = brokenSign + (errB >= tol);
    end
end
nonzeroD = sum(Ds ~= 0) * numel(spd);   % a zero declination cannot expose either break

fprintf('\n=== ENU declination closure ===\n');
fprintf('  fixed branch      : %d/%d cases within %.0e m/s (worst %.2e)\n', pass, cases, tol, worst);
fprintf('  broken (no decl)  : %d/%d nonzero-D cases FAIL, as required\n', brokenOld, nonzeroD);
fprintf('  broken (sign of D): %d/%d nonzero-D cases FAIL, as required\n', brokenSign, nonzeroD);

% Canonical hand case: magnetic north, D = +11.5 -> true bearing +11.5
[u1, v1] = enu_to_buoy_frame(0, 1, 11.5);
fprintf('  hand case: mag-N, D=+11.5 -> bearing %.6f deg (expect 11.500000)\n', ...
    mod(atan2d(-u1, v1), 360));

ok = pass == cases && brokenOld == nonzeroD && brokenSign == nonzeroD ...
     && abs(mod(atan2d(-u1, v1), 360) - 11.5) < 1e-9;
if ~ok
    error('test_enu_declination_closure:failed', 'ENU declination closure FAILED');
end
fprintf('  PASS\n');
