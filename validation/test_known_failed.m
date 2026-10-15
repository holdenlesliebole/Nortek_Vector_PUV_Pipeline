% TEST_KNOWN_FAILED  Instruments flagged knownFailed in a config are skipped by
% the drivers and reported as known by audit_registry_loads; a batch ends in
% error only on a NEW failure, and the error names only that one.
%
% WHY. Seven configured instruments never produced an L1 (field failures:
% SIO24B, SIO24C, SIO25A, SOL23/MOP651_5m, TOR24S/MOP586_15m, TOR24W/MOP586_5m,
% TOR25S/MOP586_5m). After the drivers were made to fail loudly (2026-10-14),
% every PUV_L*_run_all ended in error on them on every run, so a real new
% failure would read as the usual seven.
%
% Method. A temporary folder holds a stand-in deployment_registry with one
% deployment 'TBR23' (so the single-deployment drivers find it) and a no-op
% startup_puv. Phase A: two instruments, DEAD_5m (knownFailed) and NOINPUT_7m
% (no flag, no input files: a genuine new failure). Phase B: DEAD_5m only.
% Nothing outside the temporary folder is written.
% Criteria fixed before the first run:
%   A  each of the 8 drivers (L1-L4 driver and run_all) errors with
%      '<script>:failures', the message names NOINPUT_7m and not DEAD_5m, and
%      the output prints a KNOWN FAILED line for DEAD_5m
%   B  each of the 8 drivers returns without error
%   C  audit_registry_loads (phase A, outRoot = the temporary tree) prints
%      "KNOWN FAILED  TBR23/DEAD_5m" and "MISSING       TBR23/NOINPUT_7m"
%
% To watch it fail on old copies: set scriptDir = '<folder with the old driver
% files and audit_registry_loads.m>' before running.
%
% Run from PUV_Pipeline/:  >> run validation/test_known_failed

if ~exist('deployment_registry', 'file'), startup_puv; end
if ~exist('scriptDir', 'var') || isempty(scriptDir), scriptDir = ''; end
T = tempname; mkdir(T);
cleanT = onCleanup(@() rmdir(T, 's'));
oldPath = path; cleanP = onCleanup(@() path(oldPath));
for lv = {'L1','L2','L4'}, mkdir(fullfile(T, 'out', lv{1}, 'TBR23')); end   % input folders present, files absent
fid = fopen(fullfile(T, 'startup_puv.m'), 'w'); fprintf(fid, '%% no-op stand-in\n'); fclose(fid);
addpath(T);   % in front of the repo for this test only (restored on exit)

drivers = {'PUV_L1_run_all','PUV_L2_run_all','PUV_L3_run_all','PUV_L4_run_all', ...
           'PUV_L1_driver','PUV_L2_driver','PUV_L3_driver','PUV_L4_driver'};
pass = 0; total = 0;
regDir = struct('A', fullfile(T, 'regA'), 'B', fullfile(T, 'regB'));
write_registry(regDir.A, T, true); write_registry(regDir.B, T, false);
for phase = {'A','B'}
    use_registry(regDir, phase{1});
    for c = 1:numel(drivers)
        nm = drivers{c};
        if isempty(scriptDir), f = which(nm); else, f = fullfile(scriptDir, [nm '.m']); end
        [id, msg, out] = run_isolated(f);
        if strcmp(phase{1}, 'A')
            ok = strcmp(id, [nm ':failures']) && contains(msg, 'NOINPUT_7m') && ~contains(msg, 'DEAD_5m') ...
                 && contains(out, 'KNOWN FAILED');
        else
            ok = isempty(id);
        end
        total = total + 1; pass = pass + ok;
        fprintf('  %s %-16s error %-28s names NOINPUT %d, DEAD %d, KNOWN line %d   %d\n', phase{1}, nm, ...
            tern(isempty(id), 'none', id), contains(msg, 'NOINPUT_7m'), contains(msg, 'DEAD_5m'), contains(out, 'KNOWN FAILED'), ok);
    end
end

% C: the registry audit, on the phase-A registry and the temporary output tree
use_registry(regDir, 'A');
if isempty(scriptDir), f = fullfile(fileparts(mfilename('fullpath')), 'audit_registry_loads.m');
else, f = fullfile(scriptDir, 'audit_registry_loads.m'); end
[id, msg, out] = run_isolated(f, fullfile(T, 'out'));
okK = ~isempty(regexp(out, 'KNOWN FAILED\s+TBR23/DEAD_5m', 'once'));
okM = ~isempty(regexp(out, 'MISSING\s+TBR23/NOINPUT_7m', 'once')) && isempty(regexp(out, 'MISSING\s+TBR23/DEAD_5m', 'once'));
total = total + 2; pass = pass + okK + okM;
fprintf('  C audit_registry_loads: known DEAD_5m %d, missing NOINPUT_7m only %d %s\n', okK, okM, tern(isempty(id), '', ['(error: ' msg ')']));

fprintf('\n=== known-failed instruments: %d/%d checks as required\n', pass, total);
if pass ~= total, error('test_known_failed:failed', 'known-failed handling FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');

function write_registry(R, T, withNew)
% stand-in registry in folder R: deployment TBR23 with DEAD_5m (knownFailed),
% plus NOINPUT_7m (no flag, no input) when withNew
    mkdir(R);
    instrs = ['struct(''label'', {''DEAD_5m''%s}, ''rawSubfolder'', ''none'', ''filePrefix'', ''none'', ' ...
              '''knownFailed'', {''synthetic field failure; test_known_failed''%s})'];
    if withNew, s = sprintf(instrs, ', ''NOINPUT_7m''', ', '''''); else, s = sprintf(instrs, '', ''); end
    fid = fopen(fullfile(R, 'deployment_registry.m'), 'w');
    fprintf(fid, ['function r = deployment_registry()\n' ...
        'r = containers.Map();\n' ...
        'r(''TBR23'') = @good_cfg;\nend\n' ...
        'function cfg = good_cfg()\n' ...
        'cfg.name = ''TBR23''; cfg.fs = 2; cfg.outputDir = ''%s'';\n' ...
        'cfg.rawDataRoot = ''%s''; cfg.qcOpts.Tvalid = [9 26]; cfg.tideStation = ''9410230'';\n' ...
        'cfg.instruments = %s;\nend\n'], fullfile(T, 'out'), fullfile(T, 'raw'), s);
    fclose(fid);
end

function use_registry(regDir, ph)
% put one phase's stand-in registry in front of the path, the other off it
    other = setdiff({'A','B'}, ph);
    if contains(path, regDir.(other{1})), rmpath(regDir.(other{1})); end
    addpath(regDir.(ph));
end

function [id, msg, out] = run_isolated(f, outRoot) %#ok<INUSD>
% run the script in this function's own workspace (outRoot, when given, is
% visible to it), keeping its printed output even when it ends in an error
    id = ''; msg = ''; err__ = [];
    out = evalc('try, run(f); catch err__, end');
    if ~isempty(err__), id = err__.identifier; msg = err__.message; end
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
