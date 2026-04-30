% make_annotated_spectrum.m
% Author: Holden Leslie-Bole, 2026
% Generate an annotated wave spectrum figure for Beamer presentation
% Explains how bulk wave parameters are extracted from S_eta(f)

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

D = load('outputs/L2/TBR23/MOP580_7m_L2.mat');
L2 = D.L2;

%% Pick segment
iSeg = 1;
S = L2.S_eta(:, iSeg);
f = L2.f;
fCut = L2.fCut(iSeg);

% Band boundaries
f_IG_lo  = 0.004;
f_IG_hi  = 0.04;
f_SS_hi  = 0.25;

% Peak frequency
[Speak, ipk] = max(S);
fp = f(ipk);
Tp = 1/fp;

% Compute m0 in sea-swell band
mask_ss = f >= f_IG_hi & f <= f_SS_hi;
m0_ss = trapz(f(mask_ss), S(mask_ss));
Hs_calc = 4*sqrt(m0_ss);

% IG band mask
mask_ig = f >= f_IG_lo & f <= f_IG_hi;

%% Create figure
fig = figure('Visible','off');
fig.Units = 'centimeters';
fig.Position = [2 2 22 13];
fig.Color = 'w';

ax = axes(fig);
ax.Position = [0.11 0.14 0.84 0.80];  % give more room
hold(ax, 'on');

% Set limits
ymax = Speak * 1.45;
yl = [0 ymax];
ylim(ax, yl);
xlim(ax, [0 0.34]);

drawnow;

% --- Shaded bands ---
% IG: light blue
fill(ax, [f(mask_ig); flipud(f(mask_ig))], ...
    [S(mask_ig); zeros(sum(mask_ig),1)], ...
    [0.7 0.85 1], 'EdgeColor','none', 'FaceAlpha', 0.5);

% Sea-swell: light orange
fill(ax, [f(mask_ss); flipud(f(mask_ss))], ...
    [S(mask_ss); zeros(sum(mask_ss),1)], ...
    [1 0.85 0.65], 'EdgeColor','none', 'FaceAlpha', 0.45);

% --- Spectrum line ---
mask_plot = f <= fCut & f >= f_IG_lo;
plot(ax, f(mask_plot), S(mask_plot), 'k-', 'LineWidth', 2);

% --- Vertical dashed lines ---
lineCol = [0.5 0.5 0.5];
plot(ax, [f_IG_lo f_IG_lo], yl, '--', 'Color', lineCol, 'LineWidth', 0.8);
plot(ax, [f_IG_hi f_IG_hi], yl, '--', 'Color', lineCol, 'LineWidth', 0.8);
plot(ax, [f_SS_hi f_SS_hi], yl, '--', 'Color', lineCol, 'LineWidth', 0.8);

% fCut line
fCutCol = [0.75 0.15 0.15];
plot(ax, [fCut fCut], yl, ':', 'Color', fCutCol, 'LineWidth', 1.5);

% --- Band labels at top ---
text(ax, (f_IG_lo + f_IG_hi)/2, ymax*0.96, 'IG', ...
    'HorizontalAlignment','center', 'FontSize', 13, 'FontWeight','bold', ...
    'Color', [0.2 0.4 0.8], 'Interpreter','tex');
text(ax, 0.14, ymax*0.96, 'Sea-Swell', ...
    'HorizontalAlignment','center', 'FontSize', 13, 'FontWeight','bold', ...
    'Color', [0.85 0.45 0.1], 'Interpreter','tex');

% --- fCut label (to the left of line) ---
text(ax, fCut - 0.005, ymax*0.78, 'f_{cut}', ...
    'FontSize', 11, 'Color', fCutCol, 'Interpreter','tex', ...
    'HorizontalAlignment', 'right');

% --- Peak frequency annotation ---
% Arrow from label to peak, label positioned upper-left of peak
[nx, ny] = pos2norm(ax, [fp + 0.065, fp + 0.005], [Speak*1.05, Speak*1.01]);
annotation(fig, 'textarrow', nx, ny, ...
    'String', sprintf('f_p  \\rightarrow  T_p = 1/f_p = %.1f s', Tp), ...
    'FontSize', 11, 'Interpreter','tex', ...
    'HeadLength', 7, 'HeadWidth', 5, 'Color', [0.1 0.1 0.1]);

% --- m0 annotation (arrow into the shaded area mid-section) ---
[nx2, ny2] = pos2norm(ax, [0.21, 0.10], [ymax*0.50, 0.06]);
annotation(fig, 'textarrow', nx2, ny2, ...
    'String', 'm_0 = \int S(f) df', ...
    'FontSize', 11, 'Interpreter','tex', ...
    'HeadLength', 7, 'HeadWidth', 5, 'Color', [0.6 0.35 0]);

% --- Hs text box (upper right corner, clear space) ---
hs_str = sprintf('H_s = 4%cm_0 = %.2f m', char(8730), Hs_calc);
text(ax, 0.24, ymax*0.88, hs_str, ...
    'FontSize', 12, 'Interpreter','tex', ...
    'BackgroundColor', 'w', 'EdgeColor', [0.3 0.3 0.3], ...
    'Margin', 5, 'LineWidth', 1);

% --- Axes ---
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'S_{\eta} (m^2/Hz)');

box(ax, 'on');

% Export
outpath = 'outputs/validation/annotated_spectrum_example.png';
exportgraphics(fig, outpath, 'Resolution', 300);
fprintf('Saved to %s\n', outpath);

%% Helper
function [nx, ny] = pos2norm(ax, xdata, ydata)
    xlims = ax.XLim;
    ylims = ax.YLim;
    axPos = ax.Position;
    nx = axPos(1) + axPos(3) * (xdata - xlims(1)) / diff(xlims);
    ny = axPos(2) + axPos(4) * (ydata - ylims(1)) / diff(ylims);
end
