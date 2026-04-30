% process_ruby2d_one.m
% Author: Holden Leslie-Bole, 2026
% Adapt one Ruby2D L1 file from the legacy pipeline format to ours, then
% run our L2 spectral processor (with multi-taper). Save result for
% comparison against the legacy archived L2.

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

%% Pick instrument and load the legacy L1
instrTag = '582_6m';
l1file = sprintf('raw_cache/Ruby2D/Torrey_Ruby2D_%s_processed.mat', instrTag);
fprintf('Loading %s...\n', l1file);
S = load(l1file);
PUV_in = S.PUV;

fprintf('  fs = %.2f Hz, %d samples (%.1f hours)\n', ...
    PUV_in.fs, length(PUV_in.P), length(PUV_in.P) / PUV_in.fs / 3600);

%% Adapt to our PUV struct format
% The legacy L1 has the right shape but is missing some fields our L2 needs.
PUV = struct();
PUV.time = PUV_in.time;
PUV.P = PUV_in.P;
PUV.BuoyCoord = PUV_in.BuoyCoord;
PUV.T = PUV_in.T;
PUV.fs = PUV_in.fs;
PUV.LATLON = PUV_in.LATLON;
PUV.label = ['Ruby2D_' instrTag];
PUV.deploymentName = 'Ruby2D';

% Pull doffp from Ruby2D notes (TODO: confirm against DeploymentNotes2021Torrey.xls)
% Default placeholder: typical 6m PUV doffp ~0.6m
PUV.doffp = 0.60;
fprintf('  WARNING: doffp = %.2f m (placeholder, verify from notes)\n', PUV.doffp);

%% Build minimal instrument config
instr = struct();
instr.label = PUV.label;
% Ruby2D was at Torrey Pines on MOP 582
instr.mopStation = 'D0582';
instr.mopLine = 582;

%% Run our L2 with multi-taper (default)
opts = struct();
% spectralMethod default is mtm_full
fprintf('\nRunning L2 with multi-taper...\n');
L2 = PUV_L2_spectral(PUV, instr, opts);

%% Save
outDir = 'outputs/L2/Ruby2D';
if ~exist(outDir, 'dir'), mkdir(outDir); end
outFile = fullfile(outDir, [PUV.label '_L2.mat']);
save(outFile, 'L2', '-v7.3');
fprintf('\nSaved: %s\n', outFile);

% Quick summary
v = L2.segValid;
fprintf('\nValid segments: %d / %d (%.0f%%)\n', sum(v), length(v), 100*sum(v)/length(v));
fprintf('Hs range: %.2f - %.2f m (median %.2f)\n', ...
    min(L2.Hs(v)), max(L2.Hs(v)), median(L2.Hs(v), 'omitnan'));
fprintf('Tp range: %.1f - %.1f s (median %.1f)\n', ...
    min(L2.Tp(v)), max(L2.Tp(v)), median(L2.Tp(v), 'omitnan'));
