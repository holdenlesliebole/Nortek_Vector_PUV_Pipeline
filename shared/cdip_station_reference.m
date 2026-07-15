function REF = cdip_station_reference(stationID, tStart, tEnd, opts)
% CDIP_STATION_REFERENCE  Offshore wave reference from ANY CDIP station.
%
%   REF = cdip_station_reference(stationID, tStart, tEnd)
%   REF = cdip_station_reference(stationID, tStart, tEnd, opts)
%
%   Returns bulk + directional wave data for a CDIP station over a time window,
%   in the SAME struct shape as read_MOPline2, so it drops straight into the L3
%   storm/forcing context and the L2 validation figures (analyze_bound_waves,
%   compare_directional_spread) at any site — not just California.
%
%   This is the generic "offshore reference" reader: it fills the role the CDIP
%   MOP model plays in San Diego for sites that instead have a nearby CDIP
%   directional BUOY (e.g. 233p1 near Pearl Harbor, HI). It is NOT the
%   shore-normal source — shore-normal is a property of your deployment site's
%   local bathymetry, set manually via instr.shorenormal (see NEW_DEPLOYMENT.md).
%
%   INPUTS
%     stationID   CDIP station string, one of two forms:
%                   * Directional buoy, e.g. '233p1' (pattern \d{3}p\d) — read
%                     natively from the CDIP THREDDS netCDF (needs internet;
%                     Signal/base MATLAB only, no extra toolbox).
%                   * MOP model point, e.g. 'D0580' — DELEGATED to read_MOPline2
%                     (California only; requires that toolbox on the path). This
%                     preserves existing San Diego behavior byte-for-byte.
%     tStart,tEnd datetime window. Timezone-naive inputs are treated as UTC.
%                 Data are subset to [tStart, tEnd].
%     opts        (optional) struct:
%                   .flagMax  keep records with CDIP waveFlagPrimary <= this
%                             (1 good, 2 not-evaluated, 3 questionable, 4 bad).
%                             Default 2. Records above it -> NaN bulk params.
%                   .verbose  print progress (default true).
%
%   OUTPUT  REF struct (doubles; time is datetime UTC), matching read_MOPline2:
%     .time   [nT x 1]     record times
%     .Hs     [nT x 1]     significant wave height (m)
%     .Tp     [nT x 1]     peak period (s)
%     .fp     [nT x 1]     peak frequency (Hz) = 1./Tp   (read_MOPline2 name)
%     .Dp     [nT x 1]     peak direction (deg, coming-from, true north)
%     .depth  scalar       station water depth (m)
%     .frequency [nF x 1]  spectral band centers (Hz)
%     .fbw    [nF x 1]     spectral band widths (Hz)
%     .spec1D [nT x nF]    energy density (m^2/Hz)
%     .a1,.b1,.a2,.b2 [nT x nF]  normalized directional Fourier coefficients
%     .station            the station string used
%     .source             'buoy' or 'MOP'
%     .flag   [nT x 1]     CDIP primary QC flag (buoy path; NaN for MOP path)
%
%   EXAMPLE
%     REF = cdip_station_reference('233p1', datetime(2023,1,1), datetime(2023,1,8));
%
%   SEE ALSO  read_MOPline2, PUV_L3_storms, analyze_bound_waves,
%             compare_directional_spread, docs/NEW_DEPLOYMENT.md
% Author: Holden Leslie-Bole, 2026

if nargin < 4 || isempty(opts), opts = struct(); end
if ~isfield(opts,'flagMax'),  opts.flagMax = 2;    end
if ~isfield(opts,'verbose'),  opts.verbose = true; end

% --- Normalize the time window to UTC datetimes ---
tStart = local_to_utc(tStart);
tEnd   = local_to_utc(tEnd);

% --- Dispatch on station type ---
isBuoy = ~isempty(regexp(stationID, '^\d{3}p\d$', 'once'));
isMop  = ~isempty(regexp(stationID, '^[A-Za-z]\d+$', 'once'));

if isBuoy
    REF = read_cdip_buoy(stationID, tStart, tEnd, opts);
elseif isMop
    if exist('read_MOPline2','file') ~= 2
        error('cdip_station_reference:noMopReader', ...
            ['Station "%s" looks like a MOP model point, which is read via ' ...
             'read_MOPline2 (California MOP toolbox) — not on the path. For a ' ...
             'non-California site use a CDIP buoy id instead (e.g. ''233p1'').'], ...
            stationID);
    end
    if opts.verbose
        fprintf('  CDIP reference: MOP station %s (via read_MOPline2)\n', stationID);
    end
    MOP = read_MOPline2(stationID, tStart, tEnd);
    REF = normalize_mop_struct(MOP, stationID);
else
    error('cdip_station_reference:badStation', ...
        ['Unrecognized station id "%s". Expected a CDIP buoy (e.g. ''233p1'') ' ...
         'or a MOP point (e.g. ''D0580'').'], stationID);
end
end


% ======================================================================
function REF = read_cdip_buoy(stn, tStart, tEnd, opts)
% Read a CDIP directional buoy from THREDDS, subset to the time window.
% Tries the archived-historic file first, then the realtime file, and merges
% (recent post-recovery data may only be in realtime until CDIP archives it).

base = 'https://thredds.cdip.ucsd.edu/thredds/dodsC/cdip';
urls = { sprintf('%s/archive/%s/%s_historic.nc', base, stn, stn), ...
         sprintf('%s/realtime/%s_rt.nc',          base, stn) };

parts = {};
depth = NaN;
for u = 1:numel(urls)
    try
        p = read_one_buoy_file(urls{u}, tStart, tEnd, opts);
    catch ME
        if opts.verbose
            fprintf('  CDIP reference: %s not read (%s)\n', urls{u}, ME.message);
        end
        continue
    end
    if ~isempty(p.time)
        parts{end+1} = p; %#ok<AGROW>
        if isnan(depth) && isfinite(p.depth), depth = p.depth; end
    end
end

if isempty(parts)
    error('cdip_station_reference:noBuoyData', ...
        ['No CDIP data for buoy %s in [%s, %s]. Check the station id, the ' ...
         'window, and internet access to thredds.cdip.ucsd.edu.'], ...
        stn, datestr(tStart), datestr(tEnd));
end

% Concatenate over files, then de-duplicate times (historic/realtime overlap)
REF = parts{1};
for j = 2:numel(parts)
    REF.time   = [REF.time;   parts{j}.time];
    REF.Hs     = [REF.Hs;     parts{j}.Hs];
    REF.Tp     = [REF.Tp;     parts{j}.Tp];
    REF.Dp     = [REF.Dp;     parts{j}.Dp];
    REF.flag   = [REF.flag;   parts{j}.flag];
    REF.spec1D = [REF.spec1D; parts{j}.spec1D];
    REF.a1     = [REF.a1;     parts{j}.a1];
    REF.b1     = [REF.b1;     parts{j}.b1];
    REF.a2     = [REF.a2;     parts{j}.a2];
    REF.b2     = [REF.b2;     parts{j}.b2];
end
[REF.time, iu] = unique(REF.time);   % sorted + de-duped
REF.Hs = REF.Hs(iu);   REF.Tp = REF.Tp(iu);   REF.Dp = REF.Dp(iu);
REF.flag = REF.flag(iu);
REF.spec1D = REF.spec1D(iu,:);
REF.a1 = REF.a1(iu,:);  REF.b1 = REF.b1(iu,:);
REF.a2 = REF.a2(iu,:);  REF.b2 = REF.b2(iu,:);

REF.fp      = 1 ./ REF.Tp;
REF.depth   = depth;
REF.frequency = parts{1}.frequency;
REF.fbw       = parts{1}.fbw;
REF.station = stn;
REF.source  = 'buoy';

if opts.verbose
    fprintf('  CDIP reference: buoy %s, %d records in window, Hs %.2f-%.2f m\n', ...
        stn, numel(REF.time), min(REF.Hs), max(REF.Hs));
end
end


% ======================================================================
function p = read_one_buoy_file(url, tStart, tEnd, opts)
% Read one CDIP buoy netCDF, subsetting the time-varying arrays to the window.
% Orientation is resolved from ncinfo so 2D spectra always come back [nT x nF].

info = ncinfo(url);

% --- time axis (posix seconds since 1970 UTC) ---
tsec = double(ncread(url, 'waveTime'));
tall = datetime(tsec, 'ConvertFrom','posixtime','TimeZone','UTC');
inWin = tall >= tStart & tall <= tEnd;
p = empty_part();
if ~any(inWin), return; end
i0 = find(inWin, 1, 'first');
i1 = find(inWin, 1, 'last');
n  = i1 - i0 + 1;

% --- frequency axis (read fully) ---
freq = double(ncread(url, 'waveFrequency'));   p.frequency = freq(:);
fbw  = double(ncread(url, 'waveBandwidth'));   p.fbw       = fbw(:);
nF   = numel(freq);

% --- water depth (reduce to a scalar; some files store it per-deployment) ---
try
    d = double(ncread(url, 'metaWaterDepth'));
    d = d(isfinite(d));
    if isempty(d), p.depth = NaN; else, p.depth = d(1); end
catch
    p.depth = NaN;
end

% --- 1-D time series (subset with start/count) ---
p.time = tall(i0:i1);
p.Hs   = read_time_1d(url, 'waveHs',  info, i0, n);
p.Tp   = read_time_1d(url, 'waveTp',  info, i0, n);
p.Dp   = read_time_1d(url, 'waveDp',  info, i0, n);
p.flag = read_time_1d(url, 'waveFlagPrimary', info, i0, n);

% --- 2-D [time x freq] spectra/coeffs, oriented to [nT x nF] ---
p.spec1D = read_time_freq(url, 'waveEnergyDensity', info, i0, n, nF);
p.a1     = read_time_freq(url, 'waveA1Value',       info, i0, n, nF);
p.b1     = read_time_freq(url, 'waveB1Value',       info, i0, n, nF);
p.a2     = read_time_freq(url, 'waveA2Value',       info, i0, n, nF);
p.b2     = read_time_freq(url, 'waveB2Value',       info, i0, n, nF);

% --- QC: null out bulk params on questionable/bad records ---
bad = p.flag > opts.flagMax;
p.Hs(bad) = NaN;  p.Tp(bad) = NaN;  p.Dp(bad) = NaN;
end


% ======================================================================
function v = read_time_1d(url, name, info, i0, n)
% Read a 1-D time-indexed variable over [i0, i0+n-1].
dimName = time_dim_name(info, name);
v = double(ncread(url, name, i0, n));
v = v(:);
if isempty(dimName)  % defensive; waveTime-only vars are 1-D anyway
    v = v(:);
end
end


% ======================================================================
function M = read_time_freq(url, name, info, i0, n, nF)
% Read a 2-D variable with dims {waveTime, waveFrequency} (any order) over the
% time window, and return it oriented as [nT x nF].
dims = var_dim_names(info, name);
tPos = find(strcmp(dims, 'waveTime'));
fPos = find(strcmp(dims, 'waveFrequency'));
if isempty(tPos) || isempty(fPos)
    error('cdip_station_reference:dimNames', ...
        'Variable %s does not have waveTime/waveFrequency dims as expected.', name);
end
start = ones(1, numel(dims));  count = ones(1, numel(dims));
start(tPos) = i0;   count(tPos) = n;
start(fPos) = 1;    count(fPos) = nF;
raw = double(ncread(url, name, start, count));   % dims in file order
% ncread returns dims in the file's listed order; put time first.
if tPos > fPos
    raw = raw.';               % [nF x nT] -> [nT x nF]
end
M = raw;
if size(M,1) ~= n || size(M,2) ~= nF
    % Last-resort orientation guard
    if size(M,1) == nF && size(M,2) == n, M = M.'; end
end
end


% ======================================================================
function dims = var_dim_names(info, name)
v = info.Variables(strcmp({info.Variables.Name}, name));
dims = {v.Dimensions.Name};
end

function dn = time_dim_name(info, name)
dims = var_dim_names(info, name);
dn = dims(strcmp(dims, 'waveTime'));
if ~isempty(dn), dn = dn{1}; else, dn = ''; end
end


% ======================================================================
function p = empty_part()
p = struct('time', datetime.empty(0,1), 'Hs', [], 'Tp', [], 'Dp', [], ...
    'flag', [], 'frequency', [], 'fbw', [], 'depth', NaN, ...
    'spec1D', zeros(0,0), 'a1', zeros(0,0), 'b1', zeros(0,0), ...
    'a2', zeros(0,0), 'b2', zeros(0,0));
end


% ======================================================================
function REF = normalize_mop_struct(MOP, stationID)
% Wrap a read_MOPline2 result into the common REF shape (adds Tp, source, flag).
REF = MOP;
if ~isfield(REF,'fp') && isfield(REF,'Tp'), REF.fp = 1 ./ double(REF.Tp); end
if isfield(REF,'fp'), REF.Tp = 1 ./ double(REF.fp); end
REF.station = stationID;
REF.source  = 'MOP';
if ~isfield(REF,'flag'), REF.flag = nan(numel(REF.time),1); end
end


% ======================================================================
function t = local_to_utc(t)
if ~isa(t,'datetime')
    error('cdip_station_reference:badTime','tStart/tEnd must be datetime.');
end
if isempty(t.TimeZone), t.TimeZone = 'UTC'; end
end
