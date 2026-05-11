function [Uprime, Vprime] = apply_shorenormal_rotation(U, V, shorenormal)
% APPLY_SHORENORMAL_ROTATION  Rotate buoy-frame velocity to shore-normal frame.
%
%   [Uprime, Vprime] = apply_shorenormal_rotation(U, V, shorenormal)
%
%   Pure rotation step from rotate_shorenormal, decoupled from the CDIP
%   THREDDS angle lookup. Call this when the shore-normal angle is already
%   in hand (e.g. cached in L2.shorenormal) to avoid redundant network
%   calls during batch L4 runs.
%
%   Buoy frame: +x WEST, +y NORTH.
%   Shore-normal frame: +x onshore (shore-normal), +y alongshore north.
%
%   INPUTS
%     U, V         - buoy-frame velocity components [N x 1]
%     shorenormal  - shore-normal angle (degrees), e.g. L2.shorenormal
%
%   OUTPUTS
%     Uprime       - shore-normal velocity (+x onshore) [N x 1]
%     Vprime       - alongshore velocity (+y north)     [N x 1]
% Author: Holden Leslie-Bole, 2026

rotation  = 270 - shorenormal;
alpha_rad = rotation * pi / 180;

rot_mat = [ cos(alpha_rad)  -sin(alpha_rad);
            sin(alpha_rad)   cos(alpha_rad)];

uv     = rot_mat * [U(:)'; V(:)'];
Uprime = -uv(1,:).';
Vprime =  uv(2,:).';
end
