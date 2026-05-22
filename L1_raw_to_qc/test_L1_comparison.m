% test_L1_comparison.m
%
% Tests the refactored PUV_raw_process against the original processed output
% for TBR23 MOP580_5m (the first and simplest instrument — no cutoff, full bursts).
%
% Run from the PUV_Pipeline repo root:
%   >> startup_puv
%   >> test_L1_comparison
%
% Requires the legacy Beach_Change_Observation processed .mat to be
% reachable. Set the environment variable PUV_LEGACY_BCO to the root of
% your local BCO checkout, or edit ORIG_FILE below. The legacy archive
% is not currently mirrored on /Volumes/group/.
% Author: Holden Leslie-Bole, 2026

%% ======================== SETUP ========================
startup_puv

cfg   = TBR23_config();
instr = cfg.instruments(1);   % MOP580_5m

% Use local cache if available, otherwise copy from server first.
% To copy: cfg = copy_raw_to_local(cfg); then re-run this script.
localCache = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'raw_cache', cfg.name);
if isfolder(localCache)
    cfg.localDataRoot = localCache;
    fprintf('Using local cache: %s\n', localCache);
else
    fprintf('No local cache found. Run: cfg = copy_raw_to_local(TBR23_config())\n');
    fprintf('Then re-run this test. Proceeding from network (will be slow).\n');
end

fprintf('Testing: %s — %s\n', cfg.name, instr.label);

%% ======================== RUN NEW PIPELINE ========================
fprintf('\nRunning new PUV_raw_process...\n');
PUV_new = PUV_raw_process(instr, cfg);

%% ======================== LOAD ORIGINAL ========================
% Resolve the legacy BCO archive root: env var first, else local default.
bcoRoot = getenv('PUV_LEGACY_BCO');
if isempty(bcoRoot)
    bcoRoot = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                       'Beach_Change_Observation');
end
origFile = fullfile(bcoRoot, ...
    'Vector/PUVs/TorreyMay-July2023/DATA/PUV/Level1_QC/5m_16739_MOP580_processed.mat');
if ~isfile(origFile)
    error('test_L1_comparison:legacyMissing', ...
        ['Legacy BCO file not found: %s\n' ...
         'Set environment variable PUV_LEGACY_BCO to your BCO checkout root, ' ...
         'or edit origFile in this script. The BCO archive is not on ' ...
         '/Volumes/group/.'], origFile);
end
fprintf('Loading original: %s\n', origFile);
orig = load(origFile);
PUV_orig = orig.PUV;

%% ======================== COMPARE ========================
fprintf('\n--- Comparison Results ---\n');

% Length
fprintf('\nTimeseries length:\n');
fprintf('  Original : %d samples\n', length(PUV_orig.time));
fprintf('  New      : %d samples\n', length(PUV_new.time));
lenDiff = length(PUV_new.time) - length(PUV_orig.time);
fprintf('  Difference: %+d samples (%.1f s)\n', lenDiff, lenDiff/PUV_new.fs);

% Time span
fprintf('\nTime span:\n');
fprintf('  Original : %s  to  %s\n', PUV_orig.time(1), PUV_orig.time(end));
fprintf('  New      : %s  to  %s\n', PUV_new.time(1),  PUV_new.time(end));

% Note: new pipeline starts at first valid sample rather than trimming to
% the next hour boundary (hour-alignment was part of the abandoned 3-hour
% segment approach). Start time difference is expected and correct.
if abs(lenDiff) < 10000  % sanity check — shouldn't differ by more than ~83 min
    fprintf('  Note: start-time difference is expected (hour-alignment trim removed).\n');
    fprintf('        Comparing overlapping window only.\n');
end

% Sampling rate
fprintf('\nSampling rate:\n');
fprintf('  Original : %d Hz\n', PUV_orig.fs);
fprintf('  New      : %d Hz\n', PUV_new.fs);

%% Compare over the common (overlapping) time window
tStart = max(PUV_orig.time(1),  PUV_new.time(1));
tEnd   = min(PUV_orig.time(end), PUV_new.time(end));

idx_o = PUV_orig.time >= tStart & PUV_orig.time <= tEnd;
idx_n = PUV_new.time  >= tStart & PUV_new.time  <= tEnd;

fprintf('\nOverlapping window: %s  to  %s\n', tStart, tEnd);
fprintf('  Original samples in window: %d\n', sum(idx_o));
fprintf('  New      samples in window: %d\n', sum(idx_n));

if sum(idx_o) == sum(idx_n)
    fields    = {'P', 'BuoyCoord_U', 'BuoyCoord_V', 'BuoyCoord_W', 'T'};
    orig_vals = {PUV_orig.P(idx_o), PUV_orig.BuoyCoord.U(idx_o), ...
                 PUV_orig.BuoyCoord.V(idx_o), PUV_orig.BuoyCoord.W(idx_o), ...
                 PUV_orig.T(idx_o)};
    new_vals  = {PUV_new.P(idx_n),  PUV_new.BuoyCoord.U(idx_n),  ...
                 PUV_new.BuoyCoord.V(idx_n),  PUV_new.BuoyCoord.W(idx_n),  ...
                 PUV_new.T(idx_n)};

    fprintf('\nField-by-field comparison (overlapping window, valid samples only):\n');
    fprintf('  %-15s  %8s  %8s  %8s  %10s\n', 'Field', 'MaxDiff', 'MeanDiff', 'RMSD', 'Match?');
    fprintf('  %s\n', repmat('-',1,58));

    for ii = 1:numel(fields)
        o = orig_vals{ii};
        n = new_vals{ii};
        valid     = ~isnan(o) & ~isnan(n);
        diff_vals = o(valid) - n(valid);
        maxD  = max(abs(diff_vals));
        meanD = mean(abs(diff_vals));
        rmsd  = sqrt(mean(diff_vals.^2));
        match = maxD < 1e-6;
        fprintf('  %-15s  %8.2e  %8.2e  %8.2e  %s\n', ...
            fields{ii}, maxD, meanD, rmsd, string(match));
    end

    % NaN pattern
    fprintf('\nNaN pattern comparison (overlapping window):\n');
    for ii = 1:numel(fields)
        o = orig_vals{ii};  n = new_vals{ii};
        fprintf('  %-15s  NaNs orig=%d  new=%d  %s\n', fields{ii}, ...
            sum(isnan(o)), sum(isnan(n)), string(sum(isnan(o))==sum(isnan(n))));
    end
else
    fprintf('\n*** Sample count mismatch in overlapping window — check time alignment.\n');
end

% Rotation metadata
fprintf('\nRotation metadata:\n');
fprintf('  sensor heading — orig: %.4f  new: %.4f\n', ...
    PUV_orig.rotation.sensor, PUV_new.rotation.sensor);
fprintf('  mag declination — orig: %.4f  new: %.4f\n', ...
    PUV_orig.rotation.mag, PUV_new.rotation.mag);

fprintf('\n--- Test complete ---\n');
