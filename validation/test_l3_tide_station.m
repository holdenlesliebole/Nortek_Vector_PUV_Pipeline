% TEST_L3_TIDE_STATION  PUV_L3_currents takes its NOAA tide station from the
% config, defaults to La Jolla 9410230 only in the San Diego region, and refuses
% a failed NOAA download and a missing t_tide unless the caller opts in.
%
% WHY (2026-10-15). The station was hardcoded to 9410230 in the toolbox
% getztide2.m, so Catalina (110 km away, a different tidal regime) used La
% Jolla with nothing recorded; a failed NOAA download fell back to the t_tide
% fit silently (TOR24W/MOP586_10m sat in the catalog that way until 10-12, and
% only the rebuild script refused it); and a missing t_tide produced an L3
% without tidal or subtidal fields after a warning.
%
% Method. Synthetic 10-day hourly L2 (M2 + K1 currents and depth). The NOAA
% fetch is replaced, for this test only, by a stand-in noaa_tide_predictions in
% a temporary folder in front of the path: it records the station it was asked
% for and returns a synthetic hourly prediction, or throws when told to. No
% network. t_tide v1.3 must be on the path (run_all_tests skips this test
% otherwise). Criteria fixed before the first run:
%   1  Catalina LATLON, no tideStation        -> error PUV_L3_currents:noTideStation
%   2  no LATLON at all, no tideStation        -> error PUV_L3_currents:noTideStation
%   3  San Diego LATLON, no tideStation        -> NOAA asked for 9410230; tidal.station
%                                                 '9410230', station_source default, depth_source NOAA
%   4  Catalina LATLON, tideStation '9410079'  -> NOAA asked for 9410079; tidal.station '9410079'
%   5  NOAA fails, no opt-in                   -> error PUV_L3_currents:noaaFailed
%   6  NOAA fails, allowTtideFallback = true   -> returns, depth_source 't_tide'
%   7  t_tide hidden, no opt-in                -> error PUV_L3_currents:noTtide
%   8  t_tide hidden, allowNoTides = true      -> returns, no tidal field
%   9  prov_applied on case 3 records tide_station '9410230'; on case 6 a fallback
%
% To watch it fail on an old copy: set oldDir = '<folder holding the old
% PUV_L3_currents.m>' before running (put in front of the path for the run).
%
% Run from PUV_Pipeline/:  >> run validation/test_l3_tide_station

if ~exist('PUV_L3_currents', 'file'), startup_puv; end
T = tempname; mkdir(T);
cleanT = onCleanup(@() rmdir(T, 's'));
oldPath = path; cleanP = onCleanup(@() path(oldPath));
oldHome = getenv('HOME'); cleanH = onCleanup(@() setenv('HOME', oldHome));
cleanA = onCleanup(@() rmappdata_safe());
fid = fopen(fullfile(T, 'noaa_tide_predictions.m'), 'w');
fprintf(fid, ['function [t, h] = noaa_tide_predictions(station, d1, d2)\n' ...
    '%% stand-in for test_l3_tide_station: records the station, returns a synthetic prediction\n' ...
    'setappdata(0, ''tideTestStations'', [getappdata(0, ''tideTestStations''), {char(station)}]);\n' ...
    'if isequal(getappdata(0, ''tideTestFail''), true), error(''stand:in'', ''simulated NOAA outage''); end\n' ...
    'dn = (ceil(d1*24):floor(d2*24))''/24;\n' ...
    't = cellstr(datestr(dn, ''yyyy-mm-dd HH:MM''));\n' ...
    'h = 0.8*cos(2*pi*(dn - 738000)*24/12.42);\nend\n']);
fclose(fid);
addpath(T);
if exist('oldDir', 'var') && ~isempty(oldDir), addpath(oldDir); end
fprintf('PUV_L3_currents under test: %s\nnoaa_tide_predictions: %s\n', which('PUV_L3_currents'), which('noaa_tide_predictions'));

% synthetic L2/L3: 10 days hourly
t = (datetime(2021,3,1):hours(1):datetime(2021,3,11))'; n = numel(t);
th = hours(t - t(1));
L2 = struct('time', t, 'segValid', true(n,1), ...
    'uMean', 0.10*cos(2*pi*th/12.42) + 0.04*cos(2*pi*th/23.93), ...
    'vMean', 0.05*cos(2*pi*th/12.42 + 1), 'depth', 7 + 0.8*cos(2*pi*th/12.42));
L3 = struct('time', t, 'segValid', true(n,1));
CAT = [33.334072 -118.309038]; SD = [32.93056 -117.26319];
pass = 0; total = 0;

% 1, 2: no station outside San Diego / no LATLON
L2c = L2; L2c.LATLON = CAT;
[~, id] = call(L3, L2c, struct());
total = total + 1; ok = strcmp(id, 'PUV_L3_currents:noTideStation'); pass = pass + ok;
fprintf('  1 Catalina, no tideStation: %-32s %d\n', tern(isempty(id), 'no error', id), ok);
[~, id] = call(L3, L2, struct());
total = total + 1; ok = strcmp(id, 'PUV_L3_currents:noTideStation'); pass = pass + ok;
fprintf('  2 no LATLON, no tideStation: %-31s %d\n', tern(isempty(id), 'no error', id), ok);

% 3: San Diego default
L2s = L2; L2s.LATLON = SD;
setappdata(0, 'tideTestStations', {});
[O3, id] = call(L3, L2s, struct());
st = getappdata(0, 'tideTestStations');
ok = isempty(id) && ~isempty(st) && all(strcmp(st, '9410230')) && strcmp(getf(O3, 'station'), '9410230') ...
     && startsWith(getf(O3, 'station_source'), 'default') && strcmp(getf(O3, 'depth_source'), 'NOAA');
total = total + 1; pass = pass + ok;
fprintf('  3 San Diego default: asked %s, station %s (%s), depth %s   %d\n', strjoin(unique(st), ','), ...
    getf(O3, 'station'), getf(O3, 'station_source'), getf(O3, 'depth_source'), ok);

% 4: explicit station
setappdata(0, 'tideTestStations', {});
[O4, id] = call(L3, L2c, struct('tideStation', '9410079'));
st = getappdata(0, 'tideTestStations');
ok = isempty(id) && ~isempty(st) && all(strcmp(st, '9410079')) && strcmp(getf(O4, 'station'), '9410079') ...
     && strcmp(getf(O4, 'station_source'), 'config');
total = total + 1; pass = pass + ok;
fprintf('  4 Catalina, tideStation 9410079: asked %s, station %s   %d\n', strjoin(unique(st), ','), getf(O4, 'station'), ok);

% 5, 6: NOAA fails
setappdata(0, 'tideTestFail', true);
[~, id] = call(L3, L2s, struct('tideStation', '9410230'));
total = total + 1; ok = strcmp(id, 'PUV_L3_currents:noaaFailed'); pass = pass + ok;
fprintf('  5 NOAA fails, no opt-in: %-35s %d\n', tern(isempty(id), 'no error', id), ok);
[O6, id] = call(L3, L2s, struct('tideStation', '9410230', 'allowTtideFallback', true));
total = total + 1; ok = isempty(id) && strcmp(getf(O6, 'depth_source'), 't_tide'); pass = pass + ok;
fprintf('  6 NOAA fails, allowTtideFallback: depth %s   %d\n', getf(O6, 'depth_source'), ok);
setappdata(0, 'tideTestFail', false);

% 9: provenance records the station, and the fallback
okP = false;
if isstruct(O3) && isstruct(O6)
    [a3, f3] = prov_applied('L3', O3); [a6, f6] = prov_applied('L3', O6);
    okP = strcmp(a3.tide_station, '9410230') && isempty(f3) && strcmp(a6.tide_station, '9410230') ...
          && any(contains(f6, 't_tide'));
end
total = total + 1; pass = pass + okP;
fprintf('  9 provenance: tide_station stamped, t_tide fallback recorded   %d\n', okP);

% 7, 8: t_tide hidden (removed from the path; HOME redirected so the lab copy
% under ~/Documents/Scripps/Research/toolbox is not found either)
while ~isempty(which('t_tide')), rmpath(fileparts(which('t_tide'))); end
setenv('HOME', T);
[~, id] = call(L3, L2s, struct('tideStation', '9410230'));
total = total + 1; ok = strcmp(id, 'PUV_L3_currents:noTtide'); pass = pass + ok;
fprintf('  7 t_tide hidden, no opt-in: %-32s %d\n', tern(isempty(id), 'no error', id), ok);
[O8, id] = call(L3, L2s, struct('tideStation', '9410230', 'allowNoTides', true));
total = total + 1; ok = isempty(id) && isstruct(O8) && ~isfield(O8, 'tidal'); pass = pass + ok;
fprintf('  8 t_tide hidden, allowNoTides: returned without tidal %d\n', ok);
setenv('HOME', oldHome);

fprintf('\n=== L3 tide station: %d/%d checks as required\n', pass, total);
if pass ~= total, error('test_l3_tide_station:failed', 'L3 tide station FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');

function [O, id] = call(L3, L2, opts)
% PUV_L3_currents without its console chatter; [] and the error id on error
    O = []; id = '';
    try
        [~, O] = evalc('PUV_L3_currents(L3, L2, opts)');
    catch ME
        id = ME.identifier;
        if isempty(id), id = ['(no id) ' ME.message]; end
    end
end

function v = getf(O, f)
    v = 'absent';
    if isstruct(O) && isfield(O, 'tidal') && isfield(O.tidal, f), v = O.tidal.(f); end
end

function rmappdata_safe()
    for k = {'tideTestStations', 'tideTestFail'}
        if isappdata(0, k{1}), rmappdata(0, k{1}); end
    end
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
