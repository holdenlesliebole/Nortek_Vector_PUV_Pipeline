function [U_west, V_north] = xyz_to_buoy_frame(U_x, V_y, heading_mag_deg, declination_deg)
% XYZ_TO_BUOY_FRAME  Rotate Nortek Vector XYZ velocities to the L1 buoy frame
% (+x WEST, +y NORTH, true north).
%
%   [U_west, V_north] = xyz_to_buoy_frame(U_x, V_y, H, D)
%
% H is the magnetic compass bearing of the instrument's +x axis (deg), either
% a scalar or one value per sample (time-varying heading, see
% xyz_heading_series.m). D is the magnetic declination (deg, positive east).
% The true bearing of +x is H + D. The buoy +x axis points to 270 deg true, so
% the clockwise rotation from instrument +x to buoy +x is a = 270 - (H + D),
% and with the left-handed rotation [cos a, sin a; -sin a, cos a]:
%
%     U_west  =  U_x cos a + V_y sin a
%     V_north = -U_x sin a + V_y cos a
%
% Check: H + D = 270 (instrument +x already points west) gives a = 0, so
% U_west = U_x. H + D = 0 (+x points north): a = 270, U_west = -V_y,
% V_north = U_x. A unit flow along +x then reads V_north = 1.
% Moved out of PUV_raw_process on 2026-10-16 so the time-varying heading could
% be tested; the scalar path is the same arithmetic as before.
% Inputs and outputs are column vectors in the units of the input (m/s).

    a = (270 - (heading_mag_deg(:) + declination_deg)) * pi / 180;
    U_x = U_x(:);
    V_y = V_y(:);
    U_west  =  cos(a) .* U_x + sin(a) .* V_y;
    V_north = -sin(a) .* U_x + cos(a) .* V_y;
end
