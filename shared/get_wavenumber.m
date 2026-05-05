% Falk Feddersen (c) 2001
%
% Solves the linear wave dispersion relation omega^2 = g*k*tanh(k*h)
% for wavenumber k using Newton's method.
%
% function k = get_wavenumber(omega, h)
%
% INPUTS
%   omega  - radian wave frequency (rad/s), scalar or array
%   h      - water depth (m), scalar or array (same size as omega)
%
% OUTPUT
%   k      - wavenumber (rad/m)
% Author: Holden Leslie-Bole, 2026

function k = get_wavenumber(omega, h)

g = 9.81;

% Initial guess: shallow-water wavenumber
k = omega ./ sqrt(g * h);

f = g * k .* tanh(k .* h) - omega.^2;

while max(abs(f)) > 1e-10
    dfdk = g * k .* h .* (sech(k .* h)).^2 + g * tanh(k .* h);
    k = k - f ./ dfdk;
    f = g * k .* tanh(k .* h) - omega.^2;
end
