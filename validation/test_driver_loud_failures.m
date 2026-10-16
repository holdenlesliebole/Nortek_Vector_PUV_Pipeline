% TEST_DRIVER_LOUD_FAILURES  The L1-L4 drivers and *_run_all scripts must end in
% an error when a registry config throws or a record is not written.
%
% WHY. Every driver runs each deployment and record inside try/catch, so one
% failure cannot abort a long batch. Before 2026-10-14 they then printed
% "Done." and returned normally: a config that threw was one line in a summary
% table (TOR18A, 2026-07-27, invisible for a day), and `matlab -batch` exited 0.
%
% Method. A temporary folder holds a stand-in deployment_registry (one config
% that throws, 'BAD', and one whose instrument has no input files, 'TBR23', so
% the single-deployment drivers find it), a no-op startup_puv (so the scripts'
% own startup_puv call does not put the repo's registry back in front), and the
% configs' outputDir. Nothing outside the temporary folder is written.
% Criteria fixed before the first run: each run_all script errors with
% '<script>:failures' and names BAD and TBR23; each single driver errors with
% '<script>:failures' and names the instrument; xspec run_all names BAD.
%
% To watch it fail on old copies: set scriptDir = '<folder with the old files>'.
%
% Run from PUV_Pipeline/:  >> run validation/test_driver_loud_failures

if ~exist('deployment_registry', 'file'), startup_puv; end
repo = fileparts(fileparts(mfilename('fullpath')));
if ~exist('scriptDir', 'var') || isempty(scriptDir), scriptDir = ''; end
T = tempname; mkdir(T);
cleanT = onCleanup(@() rmdir(T, 's'));
oldPath = path; cleanP = onCleanup(@() path(oldPath));
for lv = {'L1','L2','L4'}, mkdir(fullfile(T, 'out', lv{1}, 'TBR23')); end   % inputs present as folders, files absent
fid = fopen(fullfile(T, 'startup_puv.m'), 'w'); fprintf(fid, '%% no-op stand-in\n'); fclose(fid);
fid = fopen(fullfile(T, 'deployment_registry.m'), 'w');
fprintf(fid, ['function r = deployment_registry()\n' ...
    'r = containers.Map();\n' ...
    'r(''BAD'') = @() error(''stand:in'', ''config throws on purpose'');\n' ...
    'r(''TBR23'') = @good_cfg;\nend\n' ...
    'function cfg = good_cfg()\n' ...
    'cfg.name = ''TBR23''; cfg.fs = 2; cfg.outputDir = ''%s'';\n' ...
    'cfg.rawDataRoot = ''%s''; cfg.qcOpts.Tvalid = [9 26];\n' ...
    'cfg.instruments = struct(''label'', ''NOINPUT_7m'', ''rawSubfolder'', ''none'', ''filePrefix'', ''none'');\nend\n'], ...
    fullfile(T, 'out'), fullfile(T, 'raw'));
fclose(fid);
addpath(T);   % in front of the repo for this test only (restored on exit)

cases = {'PUV_L1_run_all', {'BAD','TBR23'}; 'PUV_L2_run_all', {'BAD','TBR23'}; ...
         'PUV_L3_run_all', {'BAD','TBR23'}; 'PUV_L4_run_all', {'BAD','TBR23'}; ...
         'PUV_L4_xspec_run_all', {'BAD'}; ...
         'PUV_L1_driver', {'NOINPUT_7m'}; 'PUV_L2_driver', {'NOINPUT_7m'}; ...
         'PUV_L3_driver', {'NOINPUT_7m'}; 'PUV_L4_driver', {'NOINPUT_7m'}};
pass = 0; total = size(cases, 1);
for c = 1:total
    nm = cases{c,1};
    if isempty(scriptDir), f = which(nm); else, f = fullfile(scriptDir, [nm '.m']); end
    msg = ''; id = '';
    try
        run_isolated(f);
    catch ME
        msg = ME.message; id = ME.identifier;
    end
    ok = strcmp(id, [nm ':failures']) && all(cellfun(@(s) contains(msg, s), cases{c,2}));
    pass = pass + ok;
    fprintf('  %-22s %-28s names %-16s %d\n', nm, ternary_str(isempty(id), 'no error', id), strjoin(cases{c,2}, '+'), ok);
end
fprintf('\n=== driver loud failures: %d/%d scripts as required\n', pass, total);
if pass ~= total, error('test_driver_loud_failures:failed', 'driver loud failures FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');

function s = ternary_str(c, a, b), if c, s = a; else, s = b; end, end

function run_isolated(f)
% run the driver script in this function's own workspace, so its variables
% cannot overwrite the test's, and without its console chatter
    evalc('run(f)');
end
