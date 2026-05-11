function [Uprime, Vprime, shorenormal] = rotate_shorenormal(U, V, mopStation)
% ROTATE_SHORENORMAL  Rotate buoy-frame velocities to shore-normal coordinates.
%
%   [Uprime, Vprime, shorenormal] = rotate_shorenormal(U, V, mopStation)
%
%   Rotates velocities from buoy frame (+x WEST, +y NORTH) to MOP
%   shore-normal frame (+x onshore/shore-normal, +y alongshore north).
%   Shore-normal angle is fetched live from the CDIP THREDDS server.
%
%   INPUTS
%     U, V        - velocity components in buoy coords [N x 1]
%                   (+x WEST, +y NORTH)
%     mopStation  - CDIP MOP station string, e.g. 'D0580', 'D0586'
%
%   OUTPUTS
%     Uprime      - shore-normal velocity (+x onshore) [N x 1]
%     Vprime      - alongshore velocity (+y north) [N x 1]
%     shorenormal - shore-normal angle (degrees) fetched from CDIP
%
%   REQUIRES
%     Internet access for CDIP THREDDS call.
%
%   Original: Athina Lange, SIO July 2021
%   Canonical copy: PUV_Pipeline/shared/
% Author: Holden Leslie-Bole, 2026

ncfile = strcat('http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/', ...
    'MOP_alongshore/', string(mopStation), '_nowcast.nc');

shorenormal = ncread(ncfile, 'metaShoreNormal');

[Uprime, Vprime] = apply_shorenormal_rotation(U, V, shorenormal);

end
