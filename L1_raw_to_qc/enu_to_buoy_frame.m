function [U_west, V_north] = enu_to_buoy_frame(E_mag, N_mag, declination_deg)
% ENU_TO_BUOY_FRAME  Convert Nortek Vector ENU velocities to the L1 buoy frame
% (+x WEST, +y NORTH, true north), applying magnetic declination.
%
%   [U_west, V_north] = enu_to_buoy_frame(E_mag, N_mag, D)
%
% The Vector forms ENU on board from its own compass, which is MAGNETIC. Its
% User Configuration has no declination field (checked against the raw .hdr
% "User setup" of SOL24, LPL24 and LPL25A, and dolfyn's full parse of the
% 512-byte record), so the instrument's "North" is magnetic north. dolfyn's
% set_declination and OOI's nortek_mag_corr_* treat it the same way.
% Before 2026-10-07 the ENU branch skipped this and those records sat D
% counterclockwise of every XYZ record (validation/test_enu_declination_closure.m).
%
% D is the magnetic declination in degrees, positive when magnetic north lies
% clockwise (east) of true north; about +11 deg at San Diego in 2023-2026,
% the same IGRF value the XYZ branch adds to the compass heading. A vector at
% magnetic bearing b has true bearing b + D, so with E = |v| sin b and
% N = |v| cos b:
%
%     E_true = E_mag cos D + N_mag sin D
%     N_true = N_mag cos D - E_mag sin D
%
% and the buoy frame is U_west = -E_true, V_north = N_true.
% Check: magnetic north (E = 0, N = 1) with D = +11.5 has true bearing +11.5,
% i.e. E_true = sin(11.5 deg) > 0 and U_west < 0. Units follow the input (m/s).

    c = cosd(declination_deg);
    s = sind(declination_deg);
    E_true  = E_mag .* c + N_mag .* s;
    N_true  = N_mag .* c - E_mag .* s;
    U_west  = -E_true;
    V_north =  N_true;
end
