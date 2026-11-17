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
% be tested.
% Inputs and outputs are column vectors in the units of the input (m/s).
%
% SCALAR heading (2026-11-13, beam-step rebuild): computed exactly as
% PUV_raw_process did before 2026-10-16, as the 2x2 matrix product
% rot_mat * [U'; V']. The elementwise form below is the same rotation but
% rounds differently (by up to 4.4e-16 m/s, on about 40% of samples, checked on
% TOR24S/MOP586_7m, TOR17C and TBR23/MOP586_5m), which made a rebuilt L1 differ
% bitwise from the catalog and every derived L2 field differ at rounding level.
% The matrix product reproduces the stored catalog BuoyCoord exactly (max
% difference 0 m/s on those three records). A per-sample heading keeps the
% elementwise form (only SOL25A uses it; its L1 was built with it).

    U_x = U_x(:);
    V_y = V_y(:);
    if isscalar(heading_mag_deg)
        alpha_rad = (270 - (heading_mag_deg + declination_deg)) * pi / 180;
        rot_mat = [ cos(alpha_rad)  sin(alpha_rad);
                   -sin(alpha_rad)  cos(alpha_rad)];
        uv = rot_mat * [U_x'; V_y'];
        U_west  = uv(1,:).';
        V_north = uv(2,:).';
        return
    end
    a = (270 - (heading_mag_deg(:) + declination_deg)) * pi / 180;
    U_west  =  cos(a) .* U_x + sin(a) .* V_y;
    V_north = -sin(a) .* U_x + cos(a) .* V_y;
end
