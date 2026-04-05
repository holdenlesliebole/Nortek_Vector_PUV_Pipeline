% MAKE_SITE_MAP  Generate a publication-quality site map of all PUV deployments.
%
%   Reads all instrument positions and depths from deployment_registry(),
%   de-duplicates by unique lat/lon/depth, groups by MOP line, and creates
%   a two-panel figure:
%     Left  — overview of all sites along the San Diego coast
%     Right — zoomed inset of the Torrey Pines / Los Penasquitos cluster
%
%   Saves to outputs/validation/site_map.png at 300 DPI.

startup_puv

%% ---- Extract unique instrument positions from all configs ---------------

registry    = deployment_registry();
deployNames = sort(keys(registry));

% Collect every instrument record
allLat   = [];
allLon   = [];
allDepth = [];
allMOP   = [];
allLabel = {};

for d = 1:numel(deployNames)
    cfg = registry(deployNames{d})();
    for k = 1:numel(cfg.instruments)
        inst = cfg.instruments(k);
        allLat(end+1)   = inst.latlon(1);
        allLon(end+1)   = inst.latlon(2);
        allDepth(end+1) = inst.depth_nominal;
        allMOP(end+1)   = inst.mopLine;
        allLabel{end+1}  = inst.label;
    end
end

% De-duplicate: keep unique (lat, lon, depth) combinations
% Round to 5 decimal places to merge near-identical positions across deployments
coords = round([allLat(:), allLon(:), allDepth(:)], 5);
[~, ia] = unique(coords, 'rows');

lat   = allLat(ia);
lon   = allLon(ia);
depth = allDepth(ia);
mop   = allMOP(ia);
label = allLabel(ia);

fprintf('Extracted %d unique instrument positions from %d deployments.\n', ...
    numel(lat), numel(deployNames));

%% ---- Define site groups by MOP line ------------------------------------

% Unique MOP lines for labeling
siteDefs = struct('mop', {}, 'name', {});
siteDefs(end+1) = struct('mop', 580,   'name', 'Torrey Pines MOP 580');
siteDefs(end+1) = struct('mop', 586,   'name', 'Torrey Pines MOP 586');
siteDefs(end+1) = struct('mop', 511,   'name', 'SIO Pier MOP 511');
siteDefs(end+1) = struct('mop', 591,   'name', 'Los Penasquitos MOP 591');
siteDefs(end+1) = struct('mop', 651,   'name', 'Solana Beach MOP 651');
siteDefs(end+1) = struct('mop', 654.5, 'name', 'Solana Beach MOP 654');

%% ---- Depth colormap ----------------------------------------------------

depthLevels = sort(unique(depth));
nLevels     = numel(depthLevels);

% Perceptually distinct colors (dark to light blue with warm accents)
cmap = [
    0.20  0.56  0.90   % 5m  — medium blue
    0.10  0.38  0.70   % 6m  — darker blue
    0.00  0.24  0.53   % 7m  — navy
    0.85  0.33  0.10   % 8m  — rust/orange
    0.64  0.08  0.18   % 10m — dark red
    0.44  0.00  0.44   % 15m — purple
];

% Map only the levels that exist
if nLevels <= size(cmap, 1)
    depthColors = cmap(1:nLevels, :);
else
    depthColors = parula(nLevels);
end

% Build a color vector for each point
ptColors = zeros(numel(depth), 3);
for i = 1:numel(depth)
    idx = find(depthLevels == depth(i), 1);
    ptColors(i,:) = depthColors(idx,:);
end

%% ---- Approximate coastline ---------------------------------------------
% The coastline runs roughly NNW-SSE.  We use a simple polyline at the
% approximate shoreline longitude for this stretch of coast.

coastLat = linspace(32.84, 33.01, 50);
% Linear fit: shoreline longitude shifts slightly west going north
coastLon = interp1([32.84, 33.01], [-117.253, -117.273], coastLat);

%% ---- Create figure (16:9 for Beamer) -----------------------------------

fig = figure('Units', 'inches', 'Position', [1 1 12 5.5], ...
    'Color', 'w', 'PaperPositionMode', 'auto');

markerSize = 70;

% ---- Left panel: overview -----------------------------------------------
ax1 = axes('Position', [0.06 0.12 0.42 0.82]);
hold on; box on;

% Coastline shading: fill land side (east of coastline)
fill([coastLon, ones(1,numel(coastLon))*-117.24], ...
     [coastLat, fliplr(coastLat)], ...
     [0.93 0.91 0.87], 'EdgeColor', 'none');

% Coastline
plot(coastLon, coastLat, '-', 'Color', [0.45 0.40 0.35], 'LineWidth', 1.5);

% Instrument positions
scatter(lon, lat, markerSize, ptColors, 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5);

% Site labels
for s = 1:numel(siteDefs)
    mask = abs(mop - siteDefs(s).mop) < 0.1;
    if ~any(mask), continue; end
    meanLat = mean(lat(mask));
    meanLon = mean(lon(mask));

    % Offset labels to avoid overlap
    switch siteDefs(s).mop
        case 511
            dx = 0.006; dy = -0.002;
        case 580
            dx = 0.008; dy = -0.003;
        case 586
            dx = 0.008; dy = 0.002;
        case 591
            dx = 0.008; dy = 0.000;
        case 651
            dx = 0.008; dy = -0.002;
        case 654.5
            dx = 0.008; dy = 0.002;
        otherwise
            dx = 0.006; dy = 0.000;
    end

    text(meanLon + dx, meanLat + dy, siteDefs(s).name, ...
        'FontSize', 7.5, 'FontName', 'Helvetica', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

xlabel('Longitude (^{\circ}W)');
ylabel('Latitude (^{\circ}N)');
title('PUV Deployment Sites — San Diego', 'FontSize', 11, 'FontWeight', 'bold');

xlim([-117.30 -117.23]);
ylim([32.85 33.00]);
set(ax1, 'FontSize', 9, 'FontName', 'Helvetica', 'TickDir', 'out', ...
    'XDir', 'normal', 'Layer', 'top');

% Draw box showing inset extent
insetLon = [-117.275 -117.258];
insetLat = [32.920 32.940];
rectangle('Position', [insetLon(1), insetLat(1), ...
    diff(insetLon), diff(insetLat)], ...
    'EdgeColor', [0.7 0.1 0.1], 'LineWidth', 1.2, 'LineStyle', '--');

% ---- Right panel: Torrey Pines / LPL inset ------------------------------
ax2 = axes('Position', [0.55 0.12 0.38 0.82]);
hold on; box on;

% Coastline
coastMask = coastLat >= 32.915 & coastLat <= 32.945;
fill([coastLon(coastMask), ones(1,sum(coastMask))*-117.255], ...
     [coastLat(coastMask), fliplr(coastLat(coastMask))], ...
     [0.93 0.91 0.87], 'EdgeColor', 'none');
plot(coastLon(coastMask), coastLat(coastMask), '-', ...
    'Color', [0.45 0.40 0.35], 'LineWidth', 1.5);

% Only instruments in the inset region
inMask = lat >= insetLat(1) & lat <= insetLat(2) & ...
         lon >= insetLon(1) & lon <= insetLon(2);

scatter(lon(inMask), lat(inMask), markerSize*1.5, ptColors(inMask,:), 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.6);

% Label individual instruments in inset with depth
for i = find(inMask)
    depthStr = sprintf('%gm', depth(i));
    % Offset label slightly above/below to reduce overlap
    dy = 0.0004;
    if depth(i) >= 10
        dy = -0.0004;
    end
    text(lon(i) + 0.0005, lat(i) + dy, depthStr, ...
        'FontSize', 7, 'FontName', 'Helvetica', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'Color', ptColors(i,:), 'FontWeight', 'bold');
end

% MOP line labels in inset
for s = 1:numel(siteDefs)
    if siteDefs(s).mop == 511 || siteDefs(s).mop >= 650
        continue;  % outside inset
    end
    mask = abs(mop - siteDefs(s).mop) < 0.1 & inMask;
    if ~any(mask), continue; end

    % Draw a thin line connecting instruments on the same MOP transect
    sortIdx = find(mask);
    [~, order] = sort(depth(sortIdx));
    sortIdx = sortIdx(order);
    plot(lon(sortIdx), lat(sortIdx), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);

    % Label at shallowest instrument
    text(lon(sortIdx(1)) + 0.001, lat(sortIdx(1)) + 0.0008, ...
        strrep(siteDefs(s).name, 'Torrey Pines ', 'TP '), ...
        'FontSize', 8, 'FontName', 'Helvetica', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');
end

xlabel('Longitude (^{\circ}W)');
ylabel('Latitude (^{\circ}N)');
title('Torrey Pines / Los Penasquitos Inset', 'FontSize', 11, 'FontWeight', 'bold');

xlim(insetLon + [-0.001 0.004]);
ylim(insetLat + [-0.002 0.002]);
set(ax2, 'FontSize', 9, 'FontName', 'Helvetica', 'TickDir', 'out', ...
    'Layer', 'top');

% Add "LAND" / "OCEAN" labels
text(-117.258, 32.937, 'land', 'FontSize', 8, 'FontAngle', 'italic', ...
    'Color', [0.55 0.50 0.45], 'HorizontalAlignment', 'center', ...
    'Parent', ax2);
text(-117.270, 32.922, 'ocean', 'FontSize', 8, 'FontAngle', 'italic', ...
    'Color', [0.30 0.45 0.65], 'HorizontalAlignment', 'center', ...
    'Parent', ax2);

%% ---- Legend for depth ---------------------------------------------------
% Place a compact legend below the right panel
lgdAx = axes('Position', [0.55 0.01 0.38 0.08], 'Visible', 'off');
hold on;
lgdHandles = gobjects(nLevels, 1);
for i = 1:nLevels
    lgdHandles(i) = scatter(NaN, NaN, 50, depthColors(i,:), 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
end
lgdLabels = arrayfun(@(d) sprintf('%g m', d), depthLevels, 'UniformOutput', false);
leg = legend(lgdHandles, lgdLabels, ...
    'Orientation', 'horizontal', 'Location', 'south', ...
    'FontSize', 8, 'FontName', 'Helvetica', 'Box', 'off');
leg.Title.String = 'Nominal Depth';
leg.Title.FontWeight = 'bold';
leg.Title.FontSize = 8.5;

%% ---- Save ---------------------------------------------------------------
outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs', 'validation');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
outFile = fullfile(outDir, 'site_map.png');
exportgraphics(fig, outFile, 'Resolution', 300);
fprintf('Saved: %s\n', outFile);
close(fig);
