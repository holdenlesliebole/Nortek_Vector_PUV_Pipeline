% MAKE_SITE_MAP  Generate site map with satellite basemap and MOP transects.
%
%   Uses MATLAB Mapping Toolbox geoplot/geobasemap for satellite imagery.
%   Reads all instrument positions from deployment_registry().
%   Draws MOP transect lines from shore to the outermost instrument using
%   the shore-normal angle from the config.
%
%   Saves to outputs/validation/site_map.png at 300 DPI.
% Author: Holden Leslie-Bole, 2026

startup_puv

%% ======================== EXTRACT INSTRUMENT POSITIONS ========================
registry = deployment_registry();
deployNames = sort(keys(registry));

allLat   = [];
allLon   = [];
allDepth = [];
allMOP   = [];
allLabel = {};

for d = 1:numel(deployNames)
    configFn = registry(deployNames{d});
    cfg = configFn();
    for k = 1:numel(cfg.instruments)
        inst = cfg.instruments(k);
        allLat(end+1)   = inst.latlon(1);
        allLon(end+1)   = inst.latlon(2);
        allDepth(end+1) = inst.depth_nominal;
        allMOP(end+1)   = inst.mopLine;
        allLabel{end+1} = inst.label;
    end
end

% De-duplicate (same instrument redeployed at same location)
coords = round([allLat(:) allLon(:) allDepth(:)], 5);
[~, iUniq] = unique(coords, 'rows', 'stable');
lat   = allLat(iUniq);
lon   = allLon(iUniq);
depth = allDepth(iUniq);
mop   = allMOP(iUniq);
label = allLabel(iUniq);

fprintf('Extracted %d unique instrument positions from %d deployments.\n', ...
    length(lat), numel(deployNames));

%% ======================== DEPTH COLORS ========================
depthLevels = [5 6 7 8 10 15];
depthColors = [0.2 0.6 1.0;    % 5m  - light blue
               0.1 0.3 0.8;    % 6m  - blue
               0.8 0.2 0.2;    % 7m  - red
               0.9 0.5 0.1;    % 8m  - orange
               0.6 0.1 0.6;    % 10m - purple
               0.3 0.3 0.3];   % 15m - dark gray

markerColors = zeros(length(depth), 3);
for i = 1:length(depth)
    [~, iClose] = min(abs(depthLevels - depth(i)));
    markerColors(i,:) = depthColors(iClose,:);
end

%% ======================== MOP TRANSECT LINES ========================
% Group instruments by MOP line and draw transect from shallowest to deepest
uniqueMOP = unique(mop(~isnan(mop)));

% Shore-normal angles (approximate, from CDIP)
% These define the direction the transect extends offshore
mopAngles = containers.Map('KeyType', 'double', 'ValueType', 'double');
mopAngles(580) = 263.9;  % degrees compass, direction waves come FROM
mopAngles(586) = 264.5;
mopAngles(511) = 260.0;  % approximate
mopAngles(591) = 264.0;  % approximate
mopAngles(651) = 259.5;
mopAngles(654) = 262.0;

%% ======================== FIGURE 1: OVERVIEW WITH SATELLITE ========================
fig1 = figure('Position', [50 50 1400 700], 'Color', 'w');

% --- Left panel: Overview ---
gx1 = geoaxes(fig1, 'Position', [0.03 0.08 0.45 0.85]);
hold(gx1, 'on');

% Plot instruments
for i = 1:length(lat)
    geoplot(gx1, lat(i), lon(i), 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', markerColors(i,:), 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
end

% Draw MOP transect lines (extend from shore to outermost instrument)
for m = 1:length(uniqueMOP)
    mLine = uniqueMOP(m);
    idx = find(mop == mLine);
    if length(idx) < 1, continue; end

    % Sort by depth (shallowest to deepest = closest to farthest from shore)
    [~, sortIdx] = sort(depth(idx));
    idx = idx(sortIdx);

    if isKey(mopAngles, mLine)
        % Extend the line slightly shoreward of shallowest instrument
        shoreAngle = mopAngles(mLine) + 180;  % onshore direction
        shoreAngleRad = deg2rad(90 - shoreAngle);  % convert to math convention
        extendDeg = 0.003;  % ~300m shoreward extension

        shoreLat = lat(idx(1)) + extendDeg * sin(shoreAngleRad);
        shoreLon = lon(idx(1)) + extendDeg * cos(shoreAngleRad) / cosd(lat(idx(1)));

        transectLat = [shoreLat, lat(idx)];
        transectLon = [shoreLon, lon(idx)];
    else
        transectLat = lat(idx);
        transectLon = lon(idx);
    end

    geoplot(gx1, transectLat, transectLon, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
end

% Site labels
siteLabels = {
    'Solana Beach MOP 654', 32.991, -117.282;
    'Solana Beach MOP 651', 32.988, -117.280;
    'Los Pen. MOP 591',     32.936, -117.268;
    'Torrey Pines MOP 586', 32.931, -117.268;
    'Torrey Pines MOP 580', 32.925, -117.265;
    'SIO Pier MOP 511',     32.866, -117.261;
};
for s = 1:size(siteLabels, 1)
    text(gx1, siteLabels{s,2}, siteLabels{s,3}, ['  ' siteLabels{s,1}], ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', 'w', ...
        'BackgroundColor', [0 0 0 0.5], 'Margin', 1);
end

geobasemap(gx1, 'satellite');
geolimits(gx1, [32.855 33.00], [-117.315 -117.235]);
title(gx1, 'PUV Deployment Sites — San Diego Coast', 'FontSize', 13);

% --- Right panel: Torrey Pines inset ---
gx2 = geoaxes(fig1, 'Position', [0.52 0.08 0.45 0.85]);
hold(gx2, 'on');

% Plot instruments with depth labels
for i = 1:length(lat)
    if lat(i) < 32.920 || lat(i) > 32.942, continue; end  % only TP/LPL area
    geoplot(gx2, lat(i), lon(i), 'o', 'MarkerSize', 12, ...
        'MarkerFaceColor', markerColors(i,:), 'MarkerEdgeColor', 'w', 'LineWidth', 1);
    text(gx2, lat(i), lon(i) + 0.0004, sprintf('%dm', depth(i)), ...
        'FontSize', 7, 'Color', 'w', 'FontWeight', 'bold');
end

% Draw MOP transects for TP/LPL area
for m = 1:length(uniqueMOP)
    mLine = uniqueMOP(m);
    idx = find(mop == mLine);
    tpIdx = idx(lat(idx) > 32.920 & lat(idx) < 32.942);
    if length(tpIdx) < 1, continue; end

    [~, sortIdx] = sort(depth(tpIdx));
    tpIdx = tpIdx(sortIdx);

    if isKey(mopAngles, mLine)
        shoreAngle = mopAngles(mLine) + 180;
        shoreAngleRad = deg2rad(90 - shoreAngle);
        extendDeg = 0.002;

        shoreLat = lat(tpIdx(1)) + extendDeg * sin(shoreAngleRad);
        shoreLon = lon(tpIdx(1)) + extendDeg * cos(shoreAngleRad) / cosd(lat(tpIdx(1)));

        transectLat = [shoreLat, lat(tpIdx)];
        transectLon = [shoreLon, lon(tpIdx)];
    else
        transectLat = lat(tpIdx);
        transectLon = lon(tpIdx);
    end

    geoplot(gx2, transectLat, transectLon, '-', 'Color', [1 1 1 0.7], 'LineWidth', 2);

    % Label the MOP line
    midIdx = ceil(length(transectLat)/2);
    text(gx2, transectLat(midIdx) + 0.0005, transectLon(midIdx), ...
        sprintf('MOP %d', mLine), 'FontSize', 8, 'Color', 'y', 'FontWeight', 'bold');
end

geobasemap(gx2, 'satellite');
geolimits(gx2, [32.922 32.940], [-117.275 -117.258]);
title(gx2, 'Torrey Pines / Los Pe\~nasquitos Inset', 'FontSize', 13);

%% ======================== DEPTH LEGEND ========================
% Create a manual legend using annotation
legendStr = {};
legendColors = [];
for d = 1:length(depthLevels)
    idx = find(abs(depth - depthLevels(d)) < 1, 1);
    if ~isempty(idx)
        legendStr{end+1} = sprintf('%dm', depthLevels(d));
        legendColors(end+1,:) = depthColors(d,:);
    end
end

% Use invisible plots on gx1 for legend
for d = 1:length(legendStr)
    geoplot(gx1, NaN, NaN, 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', legendColors(d,:), 'MarkerEdgeColor', 'k', ...
        'DisplayName', legendStr{d});
end
legend(gx1, 'Location', 'southwest', 'FontSize', 9, 'TextColor', 'w', ...
    'Color', [0.2 0.2 0.2], 'EdgeColor', 'w');

%% ======================== SAVE ========================
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end
outFile = fullfile(diagDir, 'site_map.png');
exportgraphics(fig1, outFile, 'Resolution', 300);
fprintf('Saved: %s\n', outFile);
