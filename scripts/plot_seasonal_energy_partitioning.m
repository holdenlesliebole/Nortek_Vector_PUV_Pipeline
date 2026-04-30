% plot_seasonal_energy_partitioning.m
% Author: Holden Leslie-Bole, 2026
% Stacked area plot of daily-averaged energy flux by frequency band
% Two subplots: winter (TOR24W) vs summer (TOR24S) at MOP586, 7 m depth
% For Beamer presentation: "Seasonal Energy Partitioning" slide

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

W = load('outputs/L3/TOR24W/MOP586_7m_L3.mat'); W = W.L3;
S = load('outputs/L3/TOR24S/MOP586_7m_L3.mat'); S = S.L3;

fig = figure('Units','centimeters','Position',[2 2 22 14],'Color','w');

% Colors — distinct, colorblind-friendly
cIG    = [0.35 0.55 0.85];   % medium blue
cSwell = [0.93 0.55 0.14];   % orange
cSea   = [0.30 0.72 0.38];   % green
cHs    = [0.15 0.15 0.15];   % near-black

datasets = {W, S};
titles_str = {'(a) Winter  --  Torrey Pines, 7 m  (Nov 2024 -- Feb 2025)', ...
              '(b) Summer  --  Torrey Pines, 7 m  (Feb -- May 2024)'};

% First pass: compute daily averages and find shared y-limits
all_ef_max = 0;
all_hs_max = 0;
daily = struct();
for k = 1:2
    D = datasets{k};
    v = D.segValid;
    t = D.time(v);

    days = dateshift(t, 'start', 'day');
    [udays, ~, ic] = unique(days);
    nd = numel(udays);

    daily(k).udays = udays;
    daily(k).ig = accumarray(ic, D.Ef_ig(v),    [nd 1], @mean) / 1000;
    daily(k).sw = accumarray(ic, D.Ef_swell(v), [nd 1], @mean) / 1000;
    daily(k).se = accumarray(ic, D.Ef_sea(v),   [nd 1], @mean) / 1000;
    daily(k).hs = accumarray(ic, D.Hs_total(v), [nd 1], @mean);

    stk = daily(k).ig + daily(k).sw + daily(k).se;
    all_ef_max = max(all_ef_max, max(stk));
    all_hs_max = max(all_hs_max, max(daily(k).hs));
end

% Shared limits with a bit of headroom
ef_ylim = [0, ceil(all_ef_max * 1.08)];
hs_ylim = [0, ceil(all_hs_max * 10) / 10 + 0.2];

axs = gobjects(2,1);
for k = 1:2
    axs(k) = subplot(2,1,k);
    ud = daily(k).udays;

    % Stacked area: IG (bottom), Swell (middle), Sea (top)
    h = area(ud, [daily(k).ig, daily(k).sw, daily(k).se]);
    h(1).FaceColor = cIG;
    h(2).FaceColor = cSwell;
    h(3).FaceColor = cSea;
    for j = 1:3
        h(j).FaceAlpha = 0.85;
        h(j).EdgeColor = 'none';
    end

    ylabel('Energy Flux (kW/m)');
    title(titles_str{k}, 'FontSize', 11);
    xlim([min(ud) max(ud)]);
    ylim(ef_ylim);

    % Hs on right axis
    yyaxis right;
    plot(ud, daily(k).hs, '-', 'Color', cHs, 'LineWidth', 1.6);
    ylabel('H_s (m)');
    ylim(hs_ylim);
    axs(k).YAxis(2).Color = cHs;

    grid on;
    axs(k).GridAlpha = 0.12;
    axs(k).Toolbar.Visible = 'off';
    disableDefaultInteractivity(axs(k));
    box on;
end

% Single legend at top of figure, horizontal
lg = legend(axs(1), {'Infragravity','Swell','Sea','H_s'}, ...
    'Orientation','horizontal', 'FontSize', 9, 'NumColumns', 4);
lg.Position(2) = 0.96;   % near top
lg.Position(1) = 0.5 - lg.Position(3)/2;  % centered

% Tighten vertical spacing
axs(1).Position(2) = 0.56;
axs(1).Position(4) = 0.34;
axs(2).Position(2) = 0.10;
axs(2).Position(4) = 0.34;

outpath = 'outputs/validation/seasonal_energy_partitioning.png';
exportgraphics(fig, outpath, 'Resolution', 300);
fprintf('Saved to %s\n', outpath);
