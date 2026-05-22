% reprocess_all_L2_L3.m
% Author: Holden Leslie-Bole, 2026
% Full reprocessing: delete existing L2/L3 files, rerun L2 and L3 for all deployments.
% Run from the PUV_Pipeline repo root or from scripts/:
%   >> startup_puv
%   >> reprocess_all_L2_L3

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

outRoot = fullfile(pwd, 'outputs');

%% Step 1: Clear existing L2 and L3 files
fprintf('\n=== Clearing existing L2 and L3 files ===\n');
l2files = dir(fullfile(outRoot, 'L2', '**', '*_L2.mat'));
l3files = dir(fullfile(outRoot, 'L3', '**', '*_L3.mat'));
fprintf('  Deleting %d L2 files and %d L3 files...\n', numel(l2files), numel(l3files));
for i = 1:numel(l2files)
    delete(fullfile(l2files(i).folder, l2files(i).name));
end
for i = 1:numel(l3files)
    delete(fullfile(l3files(i).folder, l3files(i).name));
end
fprintf('  Done.\n');

%% Step 2: Run L2 for all deployments
fprintf('\n=== Running L2 spectral processing ===\n');
tL2 = tic;
PUV_L2_run_all;
fprintf('\nL2 complete in %.1f min\n', toc(tL2)/60);

%% Step 3: Run L3 for all deployments
fprintf('\n=== Running L3 forcing characterization ===\n');
tL3 = tic;
PUV_L3_run_all;
fprintf('\nL3 complete in %.1f min\n', toc(tL3)/60);

%% Step 4: Run validation suite
fprintf('\n=== Running validation suite ===\n');
tVal = tic;
run_full_validation_suite;
fprintf('\nValidation complete in %.1f min\n', toc(tVal)/60);

fprintf('\n=== All reprocessing complete ===\n');
