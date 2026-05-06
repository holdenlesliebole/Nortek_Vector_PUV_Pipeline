function out = mean_flow_all_instruments(opts)
% MEAN_FLOW_ALL_INSTRUMENTS  Build cross-deployment mean-flow time-series
% figures and back them with a .mat file. Uses the 1-hour L2 outputs.
%
% Produces three figures plus the backing .mat:
%   (a) overlay_uMean.png  — uMean time series for all instruments on one
%       axis, colored by site, scaled-down stroke for visual clarity.
%   (b) overlay_uMean_vMean.png  — side-by-side panels of uMean and vMean
%       overlays, same coloring.
%   (c) stacked_per_instrument.png  — one row per instrument, shared time
%       axis, uMean (blue) and vMean (red) per row.
%
%   .mat: outputs/validation/mean_flow/_aggregate/mean_flow_timeseries.mat
%   contains a struct array with one entry per instrument:
%     .deployment, .label, .site, .h_med, .time, .uMean, .vMean, .Hs, .depth
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts,'L2dir'),  opts.L2dir  = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts,'aggDir'), opts.aggDir = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate'); end
if ~exist(opts.aggDir,'dir'), mkdir(opts.aggDir); end

reg = deployment_registry();
deployments = sort(keys(reg));

records = struct('deployment',{},'label',{},'site',{},'h_med',{}, ...
    'time',{},'uMean',{},'vMean',{},'Hs',{},'depth',{}, ...
    'date_start',{},'date_end',{});

for iD = 1:numel(deployments)
    dep = deployments{iD};
    depDir = fullfile(opts.L2dir, dep);
    if ~isfolder(depDir), continue; end
    files = dir(fullfile(depDir,'*_L2.mat'));
    files = files(~contains({files.name},'.bak'));
    for iF = 1:numel(files)
        label = regexprep(files(iF).name,'_L2\.mat$','');
        L = load(fullfile(depDir, files(iF).name));  L = L.L2;
        if ~isfield(L,'uMean') || ~isfield(L,'vMean'), continue; end
        valid = L.segValid(:) & ~isnan(L.uMean(:)) & ~isnan(L.vMean(:));
        if sum(valid) < 50, continue; end
        records(end+1) = struct( ...
            'deployment', dep, ...
            'label',      label, ...
            'site',       site_for(dep), ...
            'h_med',      median(L.depth(valid)), ...
            'time',       L.time(valid), ...
            'uMean',      L.uMean(valid), ...
            'vMean',      L.vMean(valid), ...
            'Hs',         L.Hs(valid), ...
            'depth',      L.depth(valid), ...
            'date_start', min(L.time(valid)), ...
            'date_end',   max(L.time(valid))); %#ok<AGROW>
    end
end

nI = numel(records);
fprintf('Loaded %d instruments.\n', nI);

% Save backing .mat
matFile = fullfile(opts.aggDir,'mean_flow_timeseries.mat');
save(matFile, 'records', '-v7.3');
fprintf('Saved: %s\n', matFile);

% Site colors
siteColors = containers.Map();
siteColors('Torrey')     = [0.20 0.45 0.85];
siteColors('Solana')     = [0.85 0.30 0.20];
siteColors('SIO Pier')   = [0.95 0.65 0.10];
siteColors('LPL lagoon') = [0.30 0.65 0.30];
siteColors('other')      = [0.50 0.50 0.50];

% Sort by date_start so legend order makes sense
[~, ix] = sort([records.date_start]);
records = records(ix);

% =========== Figure (a): uMean overlay ===========
fig = figure('Visible','off','Position',[100 100 1700 700]);
hold on;
sitesSeen = strings(0,1);
for k = 1:nI
    r = records(k);
    col = siteColors(char(r.site));
    h = plot(r.time, r.uMean, '-', 'Color', [col 0.55], 'LineWidth', 0.6);
    if ~ismember(r.site, sitesSeen)
        h.DisplayName = char(r.site);
        sitesSeen(end+1) = r.site; %#ok<AGROW>
    else
        h.HandleVisibility = 'off';
    end
end
yline(0, 'k:', 'LineWidth', 0.8, 'HandleVisibility','off');
xlabel('time');
ylabel('cross-shore mean velocity uMean (m/s)');
title(sprintf('All instruments — segment-mean cross-shore velocity (1-hour L2, N=%d)', nI), 'FontSize', 12);
ylim([-0.4 0.4]);
grid on;
legend('Location','northeastoutside','FontSize',10);
exportgraphics(fig, fullfile(opts.aggDir,'overlay_uMean.png'), 'Resolution', 180);
close(fig);
fprintf('Wrote: %s\n', fullfile(opts.aggDir,'overlay_uMean.png'));

% =========== Figure (b): uMean and vMean side-by-side ===========
fig = figure('Visible','off','Position',[100 100 1700 1000]);
% Top: uMean
ax1 = subplot(2,1,1); hold(ax1,'on');
sitesSeen = strings(0,1);
for k = 1:nI
    r = records(k);
    col = siteColors(char(r.site));
    h = plot(ax1, r.time, r.uMean, '-', 'Color', [col 0.55], 'LineWidth', 0.6);
    if ~ismember(r.site, sitesSeen)
        h.DisplayName = char(r.site);
        sitesSeen(end+1) = r.site; %#ok<AGROW>
    else
        h.HandleVisibility = 'off';
    end
end
yline(ax1, 0, 'k:','HandleVisibility','off');
ylabel(ax1,'uMean (cross-shore, m/s)');
title(ax1, sprintf('Cross-shore segment-mean velocity (uMean) — all 33 instruments (1-hour L2)'),'FontSize',11);
ylim(ax1, [-0.4 0.4]); grid(ax1,'on');
legend(ax1,'Location','northeastoutside','FontSize', 9);

% Bottom: vMean
ax2 = subplot(2,1,2); hold(ax2,'on');
for k = 1:nI
    r = records(k);
    col = siteColors(char(r.site));
    plot(ax2, r.time, r.vMean, '-', 'Color', [col 0.55], 'LineWidth', 0.6, 'HandleVisibility','off');
end
yline(ax2, 0, 'k:','HandleVisibility','off');
ylabel(ax2,'vMean (alongshore, m/s)');
xlabel(ax2,'time');
title(ax2, 'Alongshore segment-mean velocity (vMean)', 'FontSize',11);
ylim(ax2, [-0.4 0.4]); grid(ax2,'on');
linkaxes([ax1 ax2], 'x');
exportgraphics(fig, fullfile(opts.aggDir,'overlay_uMean_vMean.png'), 'Resolution', 180);
close(fig);
fprintf('Wrote: %s\n', fullfile(opts.aggDir,'overlay_uMean_vMean.png'));

% =========== Figure (c): stacked-per-instrument ===========
% One row per instrument, sorted by site → date. Shared time axis.
% Sort: Torrey first (most instruments), then by date within site.
siteOrder = ["Torrey","LPL lagoon","Solana","SIO Pier","other"];
sortKey = zeros(nI,1);
for k = 1:nI
    [~, sIdx] = ismember(records(k).site, siteOrder);
    if sIdx == 0, sIdx = numel(siteOrder)+1; end
    sortKey(k) = sIdx*1e6 + datenum(records(k).date_start);
end
[~, sIx] = sort(sortKey);
recSorted = records(sIx);

% Determine global time range
allTimes = vertcat(records.time);
t_min = min(allTimes); t_max = max(allTimes);

% Use tiledlayout for compact, well-controlled spacing
rowH = 110;  % px per row at 150 dpi → ~0.73 inches per row
figH = max(900, rowH*nI + 200);
fig = figure('Visible','off','Position',[100 100 1700 figH]);
tl = tiledlayout(fig, nI, 1, 'TileSpacing','tight','Padding','compact');
title(tl, sprintf('Per-instrument segment-mean velocity (uMean blue, vMean red, 1-hour L2)  —  %d instruments', nI), ...
      'FontSize', 12);
for k = 1:nI
    r = recSorted(k);
    ax = nexttile(tl); hold(ax,'on');
    % Plot vMean first (lighter), uMean second on top (heavier) for legibility
    plot(ax, r.time, r.vMean, '-', 'Color', [0.95 0.55 0.30 0.55], 'LineWidth', 0.6, 'DisplayName','vMean (alongshore)');
    plot(ax, r.time, r.uMean, '-', 'Color', [0.10 0.30 0.75],      'LineWidth', 1.0, 'DisplayName','uMean (cross-shore)');
    yline(ax, 0, 'k:','HandleVisibility','off');
    ylim(ax, [-0.3 0.3]);
    xlim(ax, [t_min t_max]);
    grid(ax,'on');
    set(ax,'YTick',[-0.2 0 0.2], 'FontSize', 8);
    % Site-tagged label inside the panel (left side, on top of grid)
    siteCol = siteColors(char(r.site));
    text(ax, t_min + days(10), 0.18, ...
        sprintf('%s / %s   (h=%.1f m, %s)', r.deployment, r.label, r.h_med, r.site), ...
        'FontSize', 9, 'HorizontalAlignment','left','VerticalAlignment','middle', ...
        'Color', siteCol*0.55, 'BackgroundColor',[1 1 1 0.7], 'Interpreter','none');
    if k < nI
        set(ax,'XTickLabel',[]);
    else
        xlabel(ax,'time');
    end
    if k == 1
        legend(ax,'Location','northeastoutside','FontSize',8);
    end
end
exportgraphics(fig, fullfile(opts.aggDir,'stacked_per_instrument.png'), 'Resolution', 150);
close(fig);
fprintf('Wrote: %s\n', fullfile(opts.aggDir,'stacked_per_instrument.png'));

out = records;
end


function s = site_for(dep)
if startsWith(dep,'TBR') || startsWith(dep,'TOR') || startsWith(dep,'RUBY'), s = "Torrey";
elseif startsWith(dep,'SOL'),                       s = "Solana";
elseif startsWith(dep,'SIO'),                       s = "SIO Pier";
elseif startsWith(dep,'LPL'),                       s = "LPL lagoon";
elseif startsWith(dep,'CAT'),                       s = "Catalina";
elseif startsWith(dep,'IB'),                        s = "Imperial Beach";
else,                                               s = "other";
end
end
