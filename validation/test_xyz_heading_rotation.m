% TEST_XYZ_HEADING_ROTATION  Synthetic closure test for the XYZ branch of
% PUV_raw_process.m: xyz_to_buoy_frame.m (scalar and per-sample heading) and
% xyz_heading_series.m (instr.headingSmoothHours).
%
% Frame convention taken as given (it is the one every XYZ record in the
% catalog was built with): instrument +x points to TRUE bearing H + D, and +y
% is 90 deg clockwise of +x. A flow of speed s toward true bearing b then reads
%     U_x = s cos(b - H - D),   V_y = s sin(b - H - D)
% and L1 must return the buoy frame (+x WEST, +y NORTH, true):
%     U_west = -s sin(b),       V_north = s cos(b).
% Expected values are written from b, never from the code.
%
% Criteria fixed before running:
%   A  scalar heading, 360 bearings x 4 headings x 3 declinations:
%      max abs error < 1e-12 m/s; the wrong sign of D must fail every case.
%   B  mount turning 17.4 -> 13.9 deg over 4.5 h inside a 48 h record at 2 Hz
%      (the SOL25A geometry), compass noise sd 0.3 deg, 1 h window:
%      max direction error of the rotated flow < 0.3 deg over the whole record.
%      The record-median heading on the same input must exceed 1.5 deg
%      somewhere (otherwise B cannot tell the two paths apart).
%   C  compass wandering across 0/360 (358-2 deg): smoothed heading within
%      0.5 deg of the truth everywhere (a non-circular mean would give ~180).
%
% Run from PUV_Pipeline/:  >> run validation/test_xyz_heading_rotation

if ~exist('xyz_to_buoy_frame', 'file'), startup_puv; end
fprintf('xyz_to_buoy_frame under test : %s\n', which('xyz_to_buoy_frame'));
fprintf('xyz_heading_series under test: %s\n', which('xyz_heading_series'));

% ---- A: scalar heading
tol = 1e-12;
b = (0:359)';
nA = 0; passA = 0; brokeA = 0; worstA = 0;
for H = [0 17.4 96.7 262]
    for D = [11.07 -14.2 0.5]
        for s = [0.05 0.6 2.1]
            Ux = s * cosd(b - H - D);  Vy = s * sind(b - H - D);
            Uexp = -s * sind(b);       Vexp = s * cosd(b);
            [U, V] = xyz_to_buoy_frame(Ux, Vy, H, D);
            e = max(abs([U - Uexp; V - Vexp]));
            nA = nA + 1; passA = passA + (e < tol); worstA = max(worstA, e);
            [Ub, Vb] = xyz_to_buoy_frame(Ux, Vy, H, -D);
            brokeA = brokeA + (max(abs([Ub - Uexp; Vb - Vexp])) >= tol);
        end
    end
end

% ---- B: mount turns during the record
fs = 2; D = 11.07; bFlow = 300; s = 0.4;
t  = (0 : 1/fs : 48*3600 - 1/fs)' / 3600;            % hours
Htrue = 17.4 + (13.9 - 17.4) * min(max((t - 20) / 4.5, 0), 1);
rng(0, 'twister');
compass = Htrue + 0.3 * randn(size(t));
Ux = s * cosd(bFlow - Htrue - D);  Vy = s * sind(bFlow - Htrue - D);
dirErr = @(U, V) abs(mod(atan2d(-U, V) - bFlow + 180, 360) - 180);

Hs = xyz_heading_series(compass, fs, 1);
[U, V] = xyz_to_buoy_frame(Ux, Vy, Hs, D);
errB = max(dirErr(U, V));
[Um, Vm] = xyz_to_buoy_frame(Ux, Vy, median(compass), D);
errMed = max(dirErr(Um, Vm));
[Ux_, Vx_] = xyz_to_buoy_frame(Ux, Vy, Hs, -D);     % break: wrong sign of D
errBroke = max(dirErr(Ux_, Vx_));

% ---- C: heading across 0/360
Hc = mod(358 + 4 * (t / 48), 360);                    % 358 -> 2 deg
compC = mod(Hc + 0.3 * randn(size(t)), 360);
HsC = xyz_heading_series(compC, fs, 1);
errC = max(abs(mod(HsC - Hc + 180, 360) - 180));

fprintf('\n=== XYZ heading rotation closure ===\n');
fprintf('  A scalar heading          : %d/%d cases within %.0e m/s (worst %.2e)\n', passA, nA, tol, worstA);
fprintf('  A broken (sign of D)      : %d/%d cases FAIL, as required\n', brokeA, nA);
fprintf('  B time-varying, 1 h window: max direction error %.3f deg (limit 0.3)\n', errB);
fprintf('  B record-median heading   : max direction error %.3f deg (must exceed 1.5)\n', errMed);
fprintf('  B broken (sign of D)      : max direction error %.3f deg (must exceed 0.3)\n', errBroke);
fprintf('  C across 0/360            : max heading error %.3f deg (limit 0.5)\n', errC);

ok = passA == nA && brokeA == nA && errB < 0.3 && errMed > 1.5 && errBroke > 0.3 && errC < 0.5;
if ~ok
    error('test_xyz_heading_rotation:failed', 'XYZ heading rotation closure FAILED');
end
fprintf('  PASS\n');
