% startup_puv.m
% Run this at the start of any PUV pipeline session.
% Adds all subdirectories of PUV_Pipeline to the MATLAB path.
% Author: Holden Leslie-Bole, 2026

root = fileparts(mfilename('fullpath'));
addpath(genpath(root));
fprintf('PUV Pipeline paths added. Root: %s\n', root);
