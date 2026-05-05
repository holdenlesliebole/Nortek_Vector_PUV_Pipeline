% Falk Feddersen (c) 2001
%
% Computes wave group velocity from wavenumber and depth.
%
% function cg = get_cg(k, h)
%
% INPUTS
%   k   - wavenumber (rad/m)
%   h   - water depth (m), same size as k OR scalar
%
% OUTPUT
%   cg  - group velocity (m/s)
% Author: Holden Leslie-Bole, 2026

function cg = get_cg(k, h)

g = 9.81;

[nk, mk] = size(k);
[nh, mh] = size(h);

% Scalar depth: broadcast over all k
if nh == 1 && mh == 1
    cg = 0.5 * (g * tanh(k * h) + g * (k .* h) .* (sech(k .* h).^2)) ...
         ./ sqrt(g * k .* tanh(k .* h));
    return
end

if nk ~= nh || mk ~= mh
    error('get_cg:sizeMismatch', 'k and h must be the same size (or h scalar).');
end

cg = 0.5 * (g * tanh(k .* h) + g * (k .* h) .* (sech(k .* h).^2)) ...
     ./ sqrt(g * k .* tanh(k .* h));
