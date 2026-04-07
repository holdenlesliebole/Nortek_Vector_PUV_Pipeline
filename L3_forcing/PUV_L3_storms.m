function L3 = PUV_L3_storms(L3, L2, toolboxPath)
% PUV_L3_STORMS  Level 3b: storm/event detection and MOP gap-filling.
%
%   L3 = PUV_L3_storms(L3, L2)
%   L3 = PUV_L3_storms(L3, L2, toolboxPath)
%
%   Identifies storm events from the Hs time series and loads MOP data
%   to provide continuous wave forcing context (including during PUV gaps
%   from instrument damage, burial, or kelp fouling).
%
%   INPUTS
%     L3          - L3 struct from PUV_L3_bands (gets appended to)
%     L2          - L2 struct from PUV_L2_spectral
%     toolboxPath - (optional) path to toolbox/ with read_MOPline2.m
%
%   OUTPUTS
%     L3 - updated struct with storm detection and MOP context fields

if nargin < 3 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

g = 9.81;
rho = 1025;

validIdx = L3.segValid;
nSeg = length(L3.time);

%% ======================== STORM DETECTION FROM PUV ========================
% Detect events where Hs exceeds a threshold for a minimum duration.

% Thresholds (configurable)
Hs_storm_thresh = 1.5;  % meters — Hs above this = storm conditions
min_duration_hr = 6;    % hours — minimum event duration
gap_merge_hr = 12;      % hours — merge events separated by less than this

Hs = L2.Hs;
Hs(~validIdx) = NaN;
dt_hr = median(diff(L2.time(validIdx)), 'omitnan');
dt_hr = hours(dt_hr);  % segment spacing in hours (~0.285 hr for 17-min)

% Find exceedance periods
above = Hs > Hs_storm_thresh;
above(isnan(Hs)) = false;

% Label connected regions (no Image Processing Toolbox needed)
labels = zeros(size(above));
currentLabel = 0;
for j = 1:length(above)
    if above(j)
        if j == 1 || ~above(j-1)
            currentLabel = currentLabel + 1;
        end
        labels(j) = currentLabel;
    end
end
nRegions = max(labels);

events = struct('start', {}, 'end_time', {}, 'duration_hr', {}, ...
    'peak_Hs', {}, 'peak_time', {}, 'mean_Hs', {}, ...
    'total_Ef', {}, 'source', {});

for r = 1:nRegions
    idx = find(labels == r);
    dur = length(idx) * dt_hr;

    if dur >= min_duration_hr
        ev = struct();
        ev.start = L2.time(idx(1));
        ev.end_time = L2.time(idx(end));
        ev.duration_hr = dur;
        [ev.peak_Hs, iPk] = max(Hs(idx));
        ev.peak_time = L2.time(idx(iPk));
        ev.mean_Hs = mean(Hs(idx), 'omitnan');
        ev.total_Ef = sum(L2.Ef(idx), 'omitnan') * dt_hr * 3600;  % W*s/m = J/m
        ev.source = 'PUV';
        events(end+1) = ev; %#ok<AGROW>
    end
end

% Merge events separated by less than gap_merge_hr
merged = true;
while merged
    merged = false;
    for e = 1:length(events)-1
        gap = hours(events(e+1).start - events(e).end_time);
        if gap < gap_merge_hr
            % Merge e and e+1
            events(e).end_time = events(e+1).end_time;
            events(e).duration_hr = hours(events(e).end_time - events(e).start);
            if events(e+1).peak_Hs > events(e).peak_Hs
                events(e).peak_Hs = events(e+1).peak_Hs;
                events(e).peak_time = events(e+1).peak_time;
            end
            events(e).mean_Hs = NaN;  % would need to recompute
            events(e).total_Ef = events(e).total_Ef + events(e+1).total_Ef;
            events(e+1) = [];
            merged = true;
            break
        end
    end
end

fprintf('  L3b storms (PUV): %d events detected (Hs > %.1f m, min %.0f hr)\n', ...
    length(events), Hs_storm_thresh, min_duration_hr);

%% ======================== MOP CONTEXT ========================
% Load MOP hourly data to provide continuous forcing context,
% including during PUV data gaps (storms that damaged instruments).

if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
    mopStation = L2.mopStation;
else
    mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if ~isempty(mopNum)
        mopStation = ['D0' mopNum{1}];
    else
        mopStation = '';
    end
end

if ~isempty(mopStation)
    tStart = min(L2.time(validIdx));
    tEnd   = max(L2.time(validIdx));
    if isempty(tStart.TimeZone), tStart.TimeZone = 'UTC'; tEnd.TimeZone = 'UTC'; end

    % Extend time window by 1 week on each side to capture surrounding storms
    tStart_ext = tStart - days(7);
    tEnd_ext   = tEnd + days(7);

    try
        fprintf('  Loading MOP data for %s (extended window)...\n', mopStation);
        MOP = read_MOPline2(mopStation, tStart_ext, tEnd_ext);

        if ~isempty(MOP.time)
            % MOP Hs at 10m depth (not shoaled — for storm detection only)
            L3.mop.time = MOP.time;
            L3.mop.Hs = double(MOP.Hs);
            L3.mop.Tp = 1 ./ double(MOP.fp);
            L3.mop.Dp = double(MOP.Dp);
            L3.mop.station = mopStation;
            L3.mop.depth = double(MOP.depth);

            fprintf('    MOP: %d hourly records, Hs range: %.2f–%.2f m\n', ...
                length(MOP.time), min(L3.mop.Hs), max(L3.mop.Hs));

            % Ensure PUV event times have timezone for comparison with MOP
            mopTZ = MOP.time.TimeZone;
            if ~isempty(mopTZ)
                for e = 1:length(events)
                    if isempty(events(e).start.TimeZone)
                        events(e).start.TimeZone = mopTZ;
                        events(e).end_time.TimeZone = mopTZ;
                        events(e).peak_time.TimeZone = mopTZ;
                    end
                end
            end

            % Detect storms in MOP record (same thresholds)
            mop_above = L3.mop.Hs > Hs_storm_thresh;
            mop_labels = zeros(size(mop_above));
mopLabel = 0;
for j = 1:length(mop_above)
    if mop_above(j)
        if j == 1 || ~mop_above(j-1)
            mopLabel = mopLabel + 1;
        end
        mop_labels(j) = mopLabel;
    end
end
            nMopRegions = max(mop_labels);

            nMopEvents = 0;
            for r = 1:nMopRegions
                idx = find(mop_labels == r);
                dur = length(idx);  % hours (MOP is hourly)

                if dur >= min_duration_hr
                    ev = struct();
                    ev.start = MOP.time(idx(1));
                    ev.end_time = MOP.time(idx(end));
                    ev.duration_hr = dur;
                    [ev.peak_Hs, iPk] = max(L3.mop.Hs(idx));
                    ev.peak_time = MOP.time(idx(iPk));
                    ev.mean_Hs = mean(L3.mop.Hs(idx));
                    ev.total_Ef = NaN;  % would need spectral integration
                    ev.source = 'MOP';

                    % Check if this event overlaps with any PUV event
                    overlaps = false;
                    for e = 1:length(events)
                        if events(e).start <= ev.end_time && events(e).end_time >= ev.start
                            overlaps = true;
                            break
                        end
                    end

                    if ~overlaps
                        events(end+1) = ev; %#ok<AGROW>
                        nMopEvents = nMopEvents + 1;
                    end
                end
            end

            fprintf('    MOP storms: %d additional events (not captured by PUV)\n', nMopEvents);

            % Identify PUV data gaps during MOP storms
            % These are periods where MOP shows storm conditions but PUV has no valid data
            nGapStorms = 0;
            for e = 1:length(events)
                if strcmp(events(e).source, 'MOP')
                    % Check if PUV had valid data during this period
                    L2_time = L2.time;
                    if isempty(L2_time.TimeZone) && ~isempty(events(e).start.TimeZone)
                        L2_time.TimeZone = events(e).start.TimeZone;
                    end
                    inWindow = L2_time >= events(e).start & L2_time <= events(e).end_time;
                    validInWindow = inWindow & validIdx;
                    if sum(validInWindow) < sum(inWindow) * 0.3
                        nGapStorms = nGapStorms + 1;
                    end
                end
            end
            if nGapStorms > 0
                fprintf('    WARNING: %d MOP-detected storms occurred during PUV data gaps\n', nGapStorms);
            end
        end
    catch ME
        warning('PUV_L3_storms:mopFailed', ...
            'MOP data load failed: %s\nStorm detection uses PUV only.', ME.message);
    end
else
    fprintf('  No MOP station — storm detection from PUV only\n');
end

%% Sort events chronologically
if ~isempty(events)
    [~, sortIdx] = sort([events.start]);
    events = events(sortIdx);
end

%% Store results
L3.events = events;
L3.storm_params.Hs_thresh = Hs_storm_thresh;
L3.storm_params.min_duration_hr = min_duration_hr;
L3.storm_params.gap_merge_hr = gap_merge_hr;

%% Print event summary
fprintf('\n  Storm Event Summary (%s):\n', L3.deploymentName);
if isempty(events)
    fprintf('    No storm events detected.\n');
else
    fprintf('    %-4s  %-20s  %-20s  %6s  %6s  %s\n', ...
        '#', 'Start', 'End', 'Dur(h)', 'PkHs', 'Source');
    fprintf('    %s\n', repmat('-', 1, 70));
    for e = 1:length(events)
        fprintf('    %-4d  %-20s  %-20s  %6.0f  %6.2f  %s\n', ...
            e, datestr(events(e).start, 'yyyy-mm-dd HH:MM'), ...
            datestr(events(e).end_time, 'yyyy-mm-dd HH:MM'), ...
            events(e).duration_hr, events(e).peak_Hs, events(e).source);
    end
end

end
