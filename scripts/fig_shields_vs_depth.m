% fig_shields_vs_depth.m
% Author: Holden Leslie-Bole, 2026
% Two-panel figure: Shields parameter and mobilization fraction vs depth
% across all 33 PUV instruments. For Beamer slide.

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

%% Load all L3 files
L3files = dir('outputs/L3/**/*_L3.mat');
nFiles = numel(L3files);
fprintf('Found %d L3 files\n', nFiles);

medDepth   = nan(nFiles, 1);
medShields = nan(nFiles, 1);
mobFrac    = nan(nFiles, 1);
labels     = cell(nFiles, 1);
deployments = cell(nFiles, 1);
siteID     = zeros(nFiles, 1);  % 1=TorreyPines, 2=SIO, 3=Solana, 4=LPL

for k = 1:nFiles
    S = load(fullfile(L3files(k).folder, L3files(k).name));
    L3 = S.L3;

    valid = L3.segValid;
    if sum(valid) < 5
        fprintf('Skipping %s/%s: only %d valid segments\n', ...
            L3files(k).folder, L3files(k).name, sum(valid));
        continue
    end

    medDepth(k)   = median(L3.depth(valid), 'omitnan');
    medShields(k) = median(L3.shields(valid), 'omitnan');
    mobFrac(k)    = mean(L3.mobilized(valid));
    labels{k}     = L3.label;
    deployments{k} = L3.deploymentName;

    % Classify site
    lbl = L3.label;
    dep = L3.deploymentName;
    if contains(lbl, 'SIO')
        siteID(k) = 2;
    elseif contains(lbl, 'LPL')
        siteID(k) = 4;
    elseif contains(lbl, 'MOP654') || contains(lbl, 'MOP651')
        siteID(k) = 3;  % Solana Beach
    elseif contains(lbl, 'MOP580') || contains(lbl, 'MOP586')
        siteID(k) = 1;  % Torrey Pines
    else
        siteID(k) = 1;  % default to Torrey Pines
    end
end

% Remove any skipped entries
good = ~isnan(medDepth);
medDepth   = medDepth(good);
medShields = medShields(good);
mobFrac    = mobFrac(good);
siteID     = siteID(good);
labels     = labels(good);

fprintf('Plotting %d instruments\n', numel(medDepth));

%% Site colors and names
siteNames = {'Torrey Pines', 'SIO Pier', 'Solana Beach', 'Los Penasquitos'};
colors = [0.204 0.373 0.647;   % dark blue - Torrey Pines
          0.831 0.325 0.098;   % orange - SIO
          0.392 0.671 0.278;   % green - Solana
          0.596 0.306 0.639];  % purple - LPL

markers = {'o', 's', 'd', '^'};

%% Create figure
fig = figure('Units', 'centimeters', 'Position', [2 2 20 11]);
fig.Color = 'w';

tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): Shields vs Depth ---
ax1 = nexttile;
hold(ax1, 'on');

hLeg = gobjects(5, 1);
for s = 1:5
    idx = siteID == s;
    if any(idx)
        hLeg(s) = scatter(ax1, medDepth(idx), medShields(idx), ...
            60, colors(s,:), markers{s}, 'filled', ...
            'MarkerEdgeColor', colors(s,:)*0.7, 'LineWidth', 0.8);
    end
end

% Critical Shields line
xLim = [floor(min(medDepth))-0.5, ceil(max(medDepth))+0.5];
plot(ax1, xLim, [0.05 0.05], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
text(ax1, xLim(2)-0.3, 0.042, '$\theta_{cr} = 0.05$', ...
    'HorizontalAlignment', 'right', 'FontSize', 8, ...
    'Color', [0.4 0.4 0.4]);

xlim(ax1, xLim);
xlabel(ax1, 'Depth (m)');
ylabel(ax1, 'Shields parameter $\theta_s$');
title(ax1, '(a) Median Shields parameter', 'FontWeight', 'normal');
set(ax1, 'Box', 'on');
grid(ax1, 'on');
ax1.GridAlpha = 0.15;

% --- Panel (b): Mobilization fraction vs Depth ---
ax2 = nexttile;
hold(ax2, 'on');

for s = 1:5
    idx = siteID == s;
    if any(idx)
        scatter(ax2, medDepth(idx), mobFrac(idx)*100, ...
            60, colors(s,:), markers{s}, 'filled', ...
            'MarkerEdgeColor', colors(s,:)*0.7, 'LineWidth', 0.8);
    end
end

xlim(ax2, xLim);
ylim(ax2, [0 max(mobFrac*100)*1.08]);
xlabel(ax2, 'Depth (m)');
ylabel(ax2, 'Time above $\theta_{cr}$ (%)');
title(ax2, '(b) Mobilization fraction', 'FontWeight', 'normal');
set(ax2, 'Box', 'on');
grid(ax2, 'on');
ax2.GridAlpha = 0.15;

% Shared legend
validSites = unique(siteID);
lg = legend(ax1, hLeg(validSites), siteNames(validSites), ...
    'Location', 'northeast', 'FontSize', 8);
lg.BoxFace.ColorType = 'truecoloralpha';
lg.BoxFace.ColorData = uint8([255;255;255;230]);

%% Save
outPath = 'outputs/validation/shields_vs_depth.png';
exportgraphics(fig, outPath, 'Resolution', 300);
fprintf('Saved to %s\n', outPath);
close(fig);
