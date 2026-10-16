% TEST_PROVENANCE  Closure test for the provenance stamps and the push-time
% refusals (shared/build_provenance, write_prov_sidecar, read_prov, check_prov).
%
% Synthetic L1 -> L2 -> L4 and L2 -> L3 files in a temporary folder. Criteria
% fixed before running; each case states what must happen:
%   1 consistent files pass                                     ok
%   2 .mat changed after stamping                               HARD modified outside
%   3 parent L1 rebuilt (new build_id) after the L2             HARD superseded parent
%   4 config doffp changed since the build                      HARD config mismatch
%   5a stamp from an old commit, L2 code changed since, no ack  SOFT code changed
%   5b same, acknowledged by a change entry                     ok
%   6a CDIP shore-normal fallback recorded, no ack              SOFT fell back
%   6b same, acknowledged                                       ok
%   7 L3 carrying the smooth-sphere ws for its D50              HARD ws mismatch
%   8 sidecar describes the file (file_sha256 present, equal)   ok via read_prov
%   9 a file with no provenance                                 HARD no provenance
%   10 L3 records its 11 external deps; a changed one SOFT-refuses unless acknowledged
%   11a a checkout with no .git (zip download) stamps 'unknown (no git)'    stamped, no error
%   11b check_prov on it, no ack                               SOFT no git (no HARD)
%   11c same, acknowledged                                     ok
%   12a L3 tide station differs from cfg.tideStation           HARD config mismatch
%   12b L3 tide station equals cfg.tideStation                 no tide refusal
% Prints n/N; errors unless all pass.
%
% Run from PUV_Pipeline/:  >> run validation/test_provenance

if ~exist('check_prov', 'file'), startup_puv; end
fprintf('check_prov under test: %s\n', which('check_prov'));
repoRoot = fileparts(fileparts(which('build_provenance')));
T = tempname; mkdir(T); cleanupT = onCleanup(@() rmdir(T, 's'));
kf = struct('keyFunctions', {{}});                  % synthetic: no key-function check
pass = 0; total = 0;
function_ok = @(r) r.ok;
has = @(r, s) any(contains(r.refusals, s));

% ---------- synthetic records ----------
instr = struct('label','TEST_7m', 'doffp', 0.70, 'latlon', [32.9 -117.26], 'heading', NaN, ...
               'mopStation', 'D0580', 'shorenormal', [], 'rawFormat', '', 'clockSource', '', 'clockOffsetHours', []);
cfg = struct('name', 'TESTDEP', 'qcOpts', struct('Tvalid', [9 26]));
mk = @(lv, nm) fullfile(T, lv, 'TESTDEP', nm);
for lv = {'L1','L2','L3','L4'}, mkdir(fullfile(T, lv{1}, 'TESTDEP')); end

PUV = struct('time', datetime(2024,1,1) + seconds(0:0.5:100)', 'fs', 2, 'doffp', 0.70, 'LATLON', [32.9 -117.26], ...
             'rotation', struct('sensor', 80.0, 'mag', 11.5, 'coordSystem', 'XYZ', 'declinationApplied', true), ...
             'qc', struct('opts', l1_qc_opts(cfg)));
f1 = mk('L1', 'TEST_7m_processed.mat'); save(f1, 'PUV', '-v7.3');
write_prov_sidecar(f1, build_provenance('L1', PUV, [], instr, kf));

L2 = struct('time', datetime(2024,1,1,0,30,0) + hours(0:2)', 'segValid', true(3,1), 'shorenormal', 262.0, ...
            'mopStation', 'D0580', 'doffp', 0.70, 'LATLON', [32.9 -117.26], ...
            'params', struct('segLen', 7200, 'nfft', 256, 'fSS', [0.04 0.25]));
f2 = mk('L2', 'TEST_7m_L2.mat'); save(f2, 'L2', '-v7.3');
write_prov_sidecar(f2, build_provenance('L2', L2, struct('level','L1','path',f1), instr, kf));

L4 = struct('doffp', 0.70, 'LATLON', [32.9 -117.26], 'shorenormal', 262.0, 'eta', struct('time', L2.time));
f4 = mk('L4', 'TEST_7m_L4.mat'); save(f4, 'L4', '-v7.3');
write_prov_sidecar(f4, build_provenance('L4', L4, struct('level','L2','path',f2), instr, kf));

base = struct('instr', instr, 'cfg', cfg, 'repoRoot', repoRoot, 'ackCodeLevels', {{'L1','L2','L3','L4'}});
req2 = base; req2.matPath = f2; req2.level = 'L2'; req2.parents = struct('level','L1','path',f1);
req4 = base; req4.matPath = f4; req4.level = 'L4'; req4.parents = struct('level','L2','path',f2);

% 1 consistent
r2 = check_prov(req2); r4 = check_prov(req4);
total = total + 1; ok = r2.ok && r4.ok; pass = pass + ok;
fprintf('  1 consistent L2 and L4 pass                   %d  %s\n', ok, strjoin([r2.refusals r4.refusals], ' | '));

% 8 sidecar describes the file
p = read_prov(f2, struct()); total = total + 1;
ok = isfield(p, 'file_sha256') && strcmp(p.file_sha256, file_sha256(f2)); pass = pass + ok;
fprintf('  8 sidecar file_sha256 equals the file         %d\n', ok);

% 2 modified outside the pipeline (bytes changed, sidecar not rewritten)
L4b = L4; L4b.doffp = 0.70; L4b.extra = 1; L4 = L4b; save(f4, 'L4', '-v7.3');   %#ok<NASGU>
r = check_prov(req4); total = total + 1; ok = ~r.ok && has(r, 'HARD: modified outside the pipeline'); pass = pass + ok;
fprintf('  2 modified outside the pipeline refused       %d\n', ok);
write_prov_sidecar(f4, build_provenance('L4', L4b, struct('level','L2','path',f2), instr, kf));   % restamp for later cases

% 3 parent rebuilt after the child
write_prov_sidecar(f1, build_provenance('L1', PUV, [], instr, kf));         % L1 gets a new build_id
r = check_prov(req2); total = total + 1; ok = ~r.ok && has(r, 'HARD: built from a superseded L1'); pass = pass + ok;
fprintf('  3 superseded parent refused                   %d\n', ok);
write_prov_sidecar(f2, build_provenance('L2', L2, struct('level','L1','path',f1), instr, kf));   % L2 rebuilt on new L1
write_prov_sidecar(f4, build_provenance('L4', L4b, struct('level','L2','path',f2), instr, kf));  % and L4 on new L2

% 4 config changed since the build
rq = req2; rq.instr.doffp = 0.75;
r = check_prov(rq); total = total + 1; ok = ~r.ok && has(r, 'HARD: config/applied mismatch on doffp'); pass = pass + ok;
fprintf('  4 config mismatch refused                     %d\n', ok);

% 5 code changed since the build commit (stamp moved to an old commit)
old = 'c519aec';   % 2026-07-29; L2_spectral and shared/ changed after it
[st, full] = system(sprintf('git -C "%s" rev-parse %s 2>/dev/null', repoRoot, old)); full = strtrim(full);
sc = sidecar_path(f2); J = jsondecode(fileread(sc)); J.code.git_hash = full; J.code.dirty = false;
fid = fopen(sc, 'w'); fwrite(fid, jsonencode(J, 'ConvertInfAndNaN', false), 'char'); fclose(fid);
rq = req2; rq.ackCodeLevels = {};
r = check_prov(rq); total = total + 1; ok = st == 0 && ~r.ok && has(r, 'SOFT: L2 code changed since build commit'); pass = pass + ok;
fprintf('  5a code change without ack refused            %d\n', ok);
rq.ackCodeLevels = {'L2'};
r = check_prov(rq); total = total + 1; ok = r.ok; pass = pass + ok;
fprintf('  5b code change acknowledged passes            %d  %s\n', ok, strjoin(r.refusals, ' | '));
write_prov_sidecar(f2, build_provenance('L2', L2, struct('level','L1','path',f1), instr, kf));
write_prov_sidecar(f4, build_provenance('L4', L4b, struct('level','L2','path',f2), instr, kf));

% 6 silent CDIP fallback recorded at build
L2f = L2; L2f.shorenormal = NaN; L2 = L2f; save(f2, 'L2', '-v7.3');
write_prov_sidecar(f2, build_provenance('L2', L2f, struct('level','L1','path',f1), instr, kf));
r = check_prov(req2); total = total + 1; ok = ~r.ok && has(r, 'SOFT: build fell back'); pass = pass + ok;
fprintf('  6a recorded fallback refused                  %d\n', ok);
rq = req2; rq.ackFallback = true; r = check_prov(rq); total = total + 1; ok = r.ok; pass = pass + ok;
fprintf('  6b acknowledged fallback passes               %d  %s\n', ok, strjoin(r.refusals, ' | '));

% 7 L3 with the smooth-sphere ws
D50 = 250e-6;
L3 = struct('time', L2.time, 'mop', struct('Hs', 1), 'transport_params', struct('D50', D50, 'D50_source', 'L2.params.D50', ...
            'rho_s', 2650, 'ws', settling_velocity(D50, 2650, 1025, 1e-6, 'shape', 'sphere'), 'ws_C2', 0.4));
f3 = mk('L3', 'TEST_7m_L3.mat'); save(f3, 'L3', '-v7.3');
write_prov_sidecar(f3, build_provenance('L3', L3, struct('level','L2','path',f2), instr, kf));
req3 = base; req3.matPath = f3; req3.level = 'L3'; req3.parents = struct('level','L2','path',f2);
r = check_prov(req3); total = total + 1; ok = ~r.ok && has(r, 'HARD: config/applied mismatch on ws'); pass = pass + ok;
fprintf('  7 stale settling velocity refused             %d\n', ok);

% 10 external (out-of-repo) dependency recorded, then changed
J = jsondecode(fileread(sidecar_path(f3)));
nExt = numel(J.external);
total = total + 1; ok = nExt == 11 && all(cellfun(@(h) numel(h) == 64, {J.external.sha256})); pass = pass + ok;
fprintf('  10a L3 stamp records 11 external deps with hashes %d\n', ok);
L3ok = L3; L3ok.transport_params.ws_C1 = 20; L3ok.transport_params.ws_C2 = 1.1; L3 = L3ok; save(f3, 'L3', '-v7.3');
write_prov_sidecar(f3, build_provenance('L3', L3ok, struct('level','L2','path',f2), instr, kf));
J = jsondecode(fileread(sidecar_path(f3)));
J.external(1).sha256 = repmat('0', 1, 64);                    % as if t_tide.m had been edited since
fid = fopen(sidecar_path(f3), 'w'); fwrite(fid, jsonencode(J, 'ConvertInfAndNaN', false), 'char'); fclose(fid);
rq = req3; rq.ackCodeLevels = {};
J.code.git_hash = strtrim(evalc('system(''git rev-parse HEAD'');'));
r = check_prov(rq); total = total + 1; ok = ~r.ok && has(r, ['SOFT: external dependency ' J.external(1).name ' changed']); pass = pass + ok;
fprintf('  10b changed external dependency refused      %d\n', ok);
rq.ackCodeLevels = {'L3'}; r = check_prov(rq); total = total + 1;
ok = ~has(r, 'SOFT: external dependency'); pass = pass + ok;
fprintf('  10c acknowledged external change passes     %d\n', ok);

% 11 a checkout with no .git (zip download): stamped, then a SOFT refusal
G = fullfile(T, 'nogit_checkout'); mkdir(G);
L2g = L2; f11 = mk('L2', 'NOGIT_7m_L2.mat'); save(f11, 'L2g', '-v7.3');
okStamp = false; Pg = struct();
try
    Pg = build_provenance('L2', L2g, struct('level','L1','path',f1), instr, struct('keyFunctions', {{}}, 'repoRoot', G));
    write_prov_sidecar(f11, Pg);
    okStamp = strcmp(Pg.code.git_hash, 'unknown (no git)') && isequal(Pg.code.dirty, true);
catch ME
    fprintf('    build_provenance on a no-git checkout threw: %s\n', ME.message);
end
total = total + 1; pass = pass + okStamp;
fprintf('  11a no-git checkout stamped "unknown (no git)" %d\n', okStamp);
rq = req2; rq.matPath = f11; rq.ackCodeLevels = {}; rq.ackFallback = true;
r = struct('ok', false, 'refusals', {{'not run'}});
if okStamp, try, r = check_prov(rq); catch ME, r.refusals = {['threw: ' ME.message]}; end, end
total = total + 1;
ok = okStamp && ~r.ok && has(r, 'SOFT: built from a checkout with no git') && ~has(r, 'HARD'); pass = pass + ok;
fprintf('  11b no-git build SOFT-refused, no HARD       %d  %s\n', ok, strjoin(r.refusals, ' | '));
rq.ackCodeLevels = {'L2'};
if okStamp, try, r = check_prov(rq); catch ME, r = struct('ok', false, 'refusals', {{['threw: ' ME.message]}}); end, end
total = total + 1; ok = okStamp && r.ok; pass = pass + ok;
fprintf('  11c no-git build acknowledged passes         %d  %s\n', ok, strjoin(r.refusals, ' | '));

% 12 tide station recorded in L3 against the config's
L3t = L3ok; L3t.tidal = struct('depth_source', 'NOAA', 'station', '9410230', 'station_source', 'config');
f12 = mk('L3', 'TIDE_7m_L3.mat'); L3 = L3t; save(f12, 'L3', '-v7.3');
write_prov_sidecar(f12, build_provenance('L3', L3t, struct('level','L2','path',f2), instr, kf));
rq = req3; rq.matPath = f12; rq.cfg.tideStation = '9410079';
r = check_prov(rq); total = total + 1; ok = ~r.ok && has(r, 'HARD: config/applied mismatch on tide_station'); pass = pass + ok;
fprintf('  12a tide station changed in config refused    %d\n', ok);
rq.cfg.tideStation = '9410230'; r = check_prov(rq); total = total + 1; ok = ~has(r, 'tide_station'); pass = pass + ok;
fprintf('  12b same tide station: no tide refusal       %d  %s\n', ok, strjoin(r.refusals, ' | '));

% 9 no provenance at all
f9 = mk('L4', 'NOPROV_L4.mat'); x = 1; save(f9, 'x');   %#ok<NASGU>
rq = req4; rq.matPath = f9; r = check_prov(rq); total = total + 1; ok = ~r.ok && has(r, 'HARD: no provenance'); pass = pass + ok;
fprintf('  9 file without provenance refused             %d\n', ok);

fprintf('\n=== provenance closure: %d/%d cases as required\n', pass, total);
if pass ~= total, error('test_provenance:failed', 'provenance closure FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');
