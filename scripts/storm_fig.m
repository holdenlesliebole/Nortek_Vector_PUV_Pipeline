% storm_fig.m - SOL23 MOP651_7m storm overview figure (PUV vs MOP Hs)
% Author: Holden Leslie-Bole, 2026
cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline'); startup_puv;
d = load('outputs/L3/SOL23/MOP651_7m_L3.mat');
L = d.L3;

%% Prepare data
t_puv = L.time;
hs_puv = L.Hs_total;
valid = L.segValid;

t_mop = L.mop.time;
hs_mop = L.mop.Hs;

% Strip time zones so all datetimes are consistent
if ~isempty(t_puv.TimeZone), t_puv.TimeZone = ''; end
if ~isempty(t_mop.TimeZone), t_mop.TimeZone = ''; end
for i = 1:numel(L.events)
    if ~isempty(L.events(i).start.TimeZone), L.events(i).start.TimeZone = ''; end
    if ~isempty(L.events(i).end_time.TimeZone), L.events(i).end_time.TimeZone = ''; end
    if ~isempty(L.events(i).peak_time.TimeZone), L.events(i).peak_time.TimeZone = ''; end
end

% Mask invalid PUV to NaN for plotting
hs_puv_plot = hs_puv;
hs_puv_plot(~valid) = NaN;

thresh = L.storm_params.Hs_thresh;

%% Identify gap boundaries
gap_starts = find(diff([true; valid]) == -1);
gap_ends   = find(diff([valid; true]) == -1);

%% Create figure
fig = figure('Units','centimeters','Position',[2 2 22 14], 'Visible','off');
fig.Color = 'w';

% --- Panel 1: Time series ---
ax1 = subplot(6,1,1:5);
hold on; box on;

% 1) Shade data gaps prominently (light gray, behind everything)
for g = 1:numel(gap_starts)
    gs = t_puv(gap_starts(g));
    ge = t_puv(gap_ends(g));
    fill([gs ge ge gs], [0 0 6 6], [0.88 0.88 0.88], ...
        'EdgeColor','none');
end

% 2) Shade storm events
for i = 1:numel(L.events)
    ev = L.events(i);
    if strcmp(ev.source, 'PUV')
        fc = [0.55 0.72 0.95]; % blue
    else
        fc = [0.95 0.55 0.55]; % red
    end
    xp = [ev.start ev.end_time ev.end_time ev.start];
    yp = [0 0 6 6];
    fill(xp, yp, fc, 'EdgeColor','none', 'FaceAlpha', 0.55);
end

% 3) Storm threshold
yline(thresh, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
text(max(t_puv) - days(1), thresh + 0.08, sprintf('H_s threshold = %.1f m', thresh), ...
    'FontSize', 8, 'Color', [0.4 0.4 0.4], 'HorizontalAlignment','right', ...
    'VerticalAlignment','bottom');

% 4) MOP Hs
h_mop = plot(t_mop, hs_mop, '-', 'Color', [0.82 0.18 0.18], 'LineWidth', 1.2);

% 5) PUV Hs (on top, thicker)
h_puv = plot(t_puv(valid), hs_puv(valid), '-', 'Color', [0.1 0.25 0.65], 'LineWidth', 1.5);

% 6) Annotate the largest storm
[~, imax] = max([L.events.peak_Hs]);
ev_big = L.events(imax);
plot(ev_big.peak_time, ev_big.peak_Hs, 'v', 'MarkerSize', 8, ...
    'MarkerFaceColor', [0.82 0.18 0.18], 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
text(ev_big.peak_time - hours(6), ev_big.peak_Hs + 0.25, ...
    sprintf('%.0f-hr storm\nH_s = %.2f m\n(MOP only)', ev_big.duration_hr, ev_big.peak_Hs), ...
    'FontSize', 8.5, 'Color', [0.15 0.15 0.15], 'VerticalAlignment','bottom', ...
    'HorizontalAlignment','center');

% 7) Annotate smaller events
for i = 1:numel(L.events)
    if i == imax, continue; end
    ev = L.events(i);
    plot(ev.peak_time, ev.peak_Hs, 'v', 'MarkerSize', 6, ...
        'MarkerFaceColor', [0.82 0.18 0.18], 'MarkerEdgeColor', 'k', 'LineWidth', 0.6);
    text(ev.peak_time, ev.peak_Hs + 0.15, ...
        sprintf('%.0f hr', ev.duration_hr), ...
        'FontSize', 8, 'Color', [0.3 0.3 0.3], 'VerticalAlignment','bottom', ...
        'HorizontalAlignment','center');
end

ylabel('H_s (m)');
ylim([0 3.8]);
xlim([min(t_puv) max(t_puv)]);

% Legend
h_puvS = fill(NaN,NaN,[0.55 0.72 0.95], 'EdgeColor','none', 'FaceAlpha',0.55);
h_mopS = fill(NaN,NaN,[0.95 0.55 0.55], 'EdgeColor','none', 'FaceAlpha',0.55);
h_gap  = fill(NaN,NaN,[0.88 0.88 0.88], 'EdgeColor','none');
lg = legend([h_puv, h_mop, h_mopS, h_gap], ...
    {'PUV H_s', 'MOP H_s', 'MOP storm', 'PUV data gap'}, ...
    'Location','northwest', 'FontSize', 8);
lg.BoxFace.ColorType = 'truecoloralpha';
lg.BoxFace.ColorData = uint8([255;255;255;230]);

% Title with escaped underscore
title_str = strrep(L.label, '_', '\_');
title(sprintf('%s  %s', L.deploymentName, title_str), 'FontSize', 11);
set(ax1, 'XTickLabel', []);

% --- Panel 2: Data source bar ---
ax2 = subplot(6,1,6);
hold on; box on;

% Build source flag per PUV timestep
src_puv = double(valid); % 1 = PUV, 0 = gap

% Plot PUV segments as blue, gaps as red (MOP-filled)
% Use contiguous blocks for efficiency
changes = find(diff([NaN; src_puv; NaN]));
for c = 1:numel(changes)-1
    i1 = changes(c);
    i2 = changes(c+1)-1;
    if i1 > numel(t_puv), continue; end
    i2 = min(i2, numel(t_puv));
    if src_puv(i1) == 1
        clr = [0.1 0.25 0.65];
    else
        clr = [0.82 0.18 0.18];
    end
    fill([t_puv(i1) t_puv(i2) t_puv(i2) t_puv(i1)], [0 0 1 1], ...
        clr, 'EdgeColor','none', 'FaceAlpha', 0.7);
end

ylim([0 1]);
xlim([min(t_puv) max(t_puv)]);
set(ax2, 'YTick', []);
ylabel('Source', 'FontSize', 9);
xlabel('Date');

% Inline labels for source bar
text(min(t_puv) + days(1.5), 0.5, 'PUV', 'Color', 'w', ...
    'FontWeight','bold', 'FontSize', 8, 'VerticalAlignment','middle');
% Find a gap region for MOP label
if numel(gap_starts) > 0
    mid_gap = t_puv(gap_starts(end)) + (t_puv(gap_ends(end)) - t_puv(gap_starts(end)))/2;
    text(mid_gap, 0.5, 'MOP', 'Color', 'w', ...
        'FontWeight','bold', 'FontSize', 8, 'VerticalAlignment','middle', ...
        'HorizontalAlignment','center');
end

% Link axes
linkaxes([ax1 ax2], 'x');

% Tighten layout
ax1.Position = [0.09 0.28 0.87 0.65];
ax2.Position = [0.09 0.10 0.87 0.12];

%% Export
outpath = 'outputs/validation/storm_gap_filling_example.png';
exportgraphics(fig, outpath, 'Resolution', 300);
fprintf('Saved to %s\n', outpath);
