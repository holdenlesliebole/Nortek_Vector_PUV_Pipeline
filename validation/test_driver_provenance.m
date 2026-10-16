% TEST_DRIVER_PROVENANCE  Outputs written by the plain drivers must carry the
% same provenance as the catalog rebuilds and pass check_prov.
%
% WHY. Until 2026-10-15 only scripts/rerun_heading_ws_2026_10_07.m stamped its
% outputs (embedded .prov + <file>.prov.json). PUV_L*_driver, PUV_L*_run_all
% and the xspec scripts saved bare .mat files, so anything a labmate built with
% them was refused by copy_to_server's provenance gate ("HARD: no provenance").
%
% Method. The first 72 hourly raw files of COR16B (raw_cache/COR16B, read only)
% are copied to a temporary folder. A stand-in registry holds one deployment
% 'TBR23' (the name the single-deployment drivers hardcode) built from
% Coronado_config('COR16B'), with two instruments A_9m and B_9m on those same
% files (B offset 0.001 deg north, so xspec has a pair), a manual shore-normal
% instead of the CDIP fetch, and outputDir in the temporary folder. Nothing is
% written outside the temporary folder.
%   Phase 1  PUV_L1_run_all, L2, L3, L4 run_all, PUV_L4_xspec_run_all
%   Phase 2  PUV_L1_driver, L2, L3, L4 driver, PUV_L4_xspec_driver (rewrites
%            every file, so lineage is re-made from a new L1)
% After each phase, check_prov on all 9 files (L1-L4 x 2 + xspec) with the
% stand-in config and the current parents.
% Criterion fixed before the first run: every file passes, except that a build
% from a dirty working tree may carry exactly one SOFT refusal, "built from
% uncommitted code", and only when its stamp says dirty = true. 18/18 required.
%
% Needs (so it is a run_all_tests 'includeData' test): raw_cache/COR16B, t_tide
% v1.3 and network access to NOAA tide predictions (L3). Takes ~10-15 min, most
% of it L4 bispectra in PUV_L4_driver.
%
% To watch it fail on old copies: set scriptDir = '<folder with the old driver
% files>' before running.
%
% Run from PUV_Pipeline/:  >> run validation/test_driver_provenance

if ~exist('deployment_registry', 'file'), startup_puv; end
repo = fileparts(fileparts(mfilename('fullpath')));
if ~exist('scriptDir', 'var') || isempty(scriptDir), scriptDir = ''; end
rawSrc = fullfile(repo, 'raw_cache', 'COR16B', 'CoronadoJan_2017', 'Coronado1181');
vec = dir(fullfile(rawSrc, '*.VEC'));
if numel(vec) < 72, error('test_driver_provenance:noRaw', 'needs raw_cache/COR16B (%d .VEC files found at %s)', numel(vec), rawSrc); end
[~, o] = sort({vec.name}); vec = vec(o(1:72));

T = tempname; mkdir(T);
cleanT = onCleanup(@() rmdir(T, 's'));
oldPath = path; cleanP = onCleanup(@() path(oldPath));
rawDst = fullfile(T, 'raw', 'sub'); mkdir(rawDst);
for k = 1:numel(vec), copyfile(fullfile(rawSrc, vec(k).name), rawDst); end
if isfile(fullfile(rawSrc, 'SETUP.DAT')), copyfile(fullfile(rawSrc, 'SETUP.DAT'), rawDst); end
fprintf('copied %d raw files (%s .. %s) to %s\n', numel(vec), vec(1).name, vec(end).name, rawDst);

fid = fopen(fullfile(T, 'startup_puv.m'), 'w'); fprintf(fid, '%% no-op stand-in\n'); fclose(fid);
fid = fopen(fullfile(T, 'deployment_registry.m'), 'w');
fprintf(fid, ['function r = deployment_registry()\n' ...
    'r = containers.Map();\nr(''TBR23'') = @() stand_in_cfg(''%s'', ''%s'');\nend\n'], fullfile(T, 'out'), fullfile(T, 'raw'));
fclose(fid);
fid = fopen(fullfile(T, 'stand_in_cfg.m'), 'w');
fprintf(fid, ['function cfg = stand_in_cfg(outDir, rawRoot)\n' ...
    '%% COR16B config, renamed TBR23, two instruments on the same 72 raw files\n' ...
    'cfg = Coronado_config(''COR16B'');\n' ...
    'cfg.name = ''TBR23''; cfg.outputDir = outDir; cfg.rawDataRoot = rawRoot;\n' ...
    'a = rmfield(cfg.instruments(1), {''mopStation'', ''mopLine''});\n' ...
    'a.rawSubfolder = ''sub''; a.shorenormal = 250;\n' ...
    'b = a; a.label = ''A_9m''; b.label = ''B_9m''; b.latlon = a.latlon + [0.001 0];\n' ...
    'cfg.instruments = [a b];\nend\n']);
fclose(fid);
addpath(T);   % in front of the repo for this test only (restored on exit)
reg = deployment_registry(); fn = reg('TBR23'); cfg = fn();

phases = {{'PUV_L1_run_all','PUV_L2_run_all','PUV_L3_run_all','PUV_L4_run_all','PUV_L4_xspec_run_all'}, ...
          {'PUV_L1_driver','PUV_L2_driver','PUV_L3_driver','PUV_L4_driver','PUV_L4_xspec_driver'}};
out = fullfile(T, 'out');
pass = 0; total = 0;
for ph = 1:2
    for c = 1:numel(phases{ph})
        nm = phases{ph}{c};
        if isempty(scriptDir), f = which(nm); else, f = fullfile(scriptDir, [nm '.m']); end
        t0 = tic; [id, msg] = run_isolated(f);
        fprintf('  phase %d %-22s %6.1f s  %s\n', ph, nm, toc(t0), tern(isempty(id), 'ok', [id ': ' strtok(msg, newline)]));
    end
    % check every output
    for k = 1:numel(cfg.instruments)
        I = cfg.instruments(k); lab = I.label;
        f1 = fullfile(out, 'L1', 'TBR23', [lab '_processed.mat']); f2 = fullfile(out, 'L2', 'TBR23', [lab '_L2.mat']);
        f3 = fullfile(out, 'L3', 'TBR23', [lab '_L3.mat']);        f4 = fullfile(out, 'L4', 'TBR23', [lab '_L4.mat']);
        chk = {'L1', f1, struct('level', {}, 'path', {});
               'L2', f2, struct('level', 'L1', 'path', f1);
               'L3', f3, struct('level', 'L2', 'path', f2);
               'L4', f4, struct('level', 'L2', 'path', f2)};
        for j = 1:size(chk, 1)
            [ok, why] = check_one(chk{j,2}, chk{j,1}, I, cfg, chk{j,3});
            total = total + 1; pass = pass + ok;
            fprintf('    phase %d %-5s %-8s %d  %s\n', ph, lab, chk{j,1}, ok, why);
        end
    end
    xf = fullfile(out, 'L4_xspec', 'TBR23', 'xspec.mat');
    m = dir(fullfile(out, 'L4', 'TBR23', '*_L4.mat'));
    par = struct('level', repmat({'L4'}, 1, numel(m)), 'path', arrayfun(@(z) fullfile(z.folder, z.name), m, 'UniformOutput', false)');
    [ok, why] = check_one(xf, 'L4_xspec', [], [], par);
    total = total + 1; pass = pass + ok;
    fprintf('    phase %d xspec          %d  %s\n', ph, ok, why);
end

fprintf('\n=== driver provenance: %d/%d files pass check_prov\n', pass, total);
if pass ~= total, error('test_driver_provenance:failed', 'driver provenance FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');

function [ok, why] = check_one(p, level, instr, cfg, parents)
    ok = false;
    if ~isfile(p), why = 'file not written'; return, end
    r = check_prov(struct('matPath', p, 'level', level, 'instr', instr, 'cfg', cfg, 'parents', parents, ...
                          'ackCodeLevels', {{}}, 'ackFallback', false));
    soft = r.refusals;
    dirtyOnly = ~isempty(r.prov) && isfield(r.prov, 'code') && isequal(r.prov.code.dirty, true) && ...
                numel(soft) == 1 && startsWith(soft{1}, 'SOFT: built from uncommitted code');
    ok = r.ok || dirtyOnly;
    why = strjoin(r.refusals, ' | ');
    if dirtyOnly, why = '(dirty working tree only)'; end
end

function [id, msg] = run_isolated(f)
% run the driver script in its own workspace, without its console chatter
    id = ''; msg = ''; err__ = [];
    evalc('try, run(f); catch err__, end');
    if ~isempty(err__), id = err__.identifier; msg = err__.message; end
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
