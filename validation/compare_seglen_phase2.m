function compare_seglen_phase2()
% COMPARE_SEGLEN_PHASE2  Side-by-side scatter of Phase 2 (alpha, beta, R^2,
% modulation amplitude) for 17-min vs 1-hour segmentation across every
% instrument. Demonstrates that the cross-shore mean flow result is
% segmentation-independent — addresses the rebuttal that the 17-min mean
% reflects sampling noise rather than wave-driven flow.
%
% Logic
%   Random instrument noise averages down as 1/sqrt(N). 17-min segment
%   already has ~2048 samples → noise floor in segment mean is sqrt(2048)
%   smaller than the 2 cm/s instantaneous noise floor. Going to 1-hour
%   adds another ~1.9x averaging. So:
%     - If signal: alpha unchanged, beta tighter
%     - If noise: alpha drifts toward 0, beta tighter
%   Showing alpha is unchanged across segmentations rules out the noise
%   hypothesis quantitatively.
%
% Inputs (auto-loaded):
%   outputs/validation/mean_flow/_aggregate/phase2_summary.mat        (17-min)
%   outputs/validation/mean_flow_17min/_aggregate/phase2_summary.mat (legacy 17-min)
%   outputs/validation/mean_flow/_aggregate/phase2_summary.mat        (canonical 1-hour)
%
% Output:
%   outputs/validation/mean_flow/_aggregate/seglen_compare_alpha_beta.png
% Author: Holden Leslie-Bole, 2026

thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
% After May 2026 rename, mean_flow_17min/ holds the legacy 17-min
% Phase 2 summary; mean_flow/ holds the canonical 1-hour summary.
aggDir = fullfile(pipelineRoot,'outputs','validation','mean_flow_17min','_aggregate');
hrDir  = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate');

S17 = load(fullfile(aggDir,'phase2_summary.mat'));     s17 = S17.summary;
S60 = load(fullfile(hrDir,'phase2_summary.mat'));      s60 = S60.summary;

% Force column vectors
nums = {'h_med','alpha','alpha_lo','alpha_hi','beta','beta_lo','beta_hi','R2_Hs2','alpha_th','modAmp_high','N_segs'};
for k = 1:numel(nums)
    s17.(nums{k}) = s17.(nums{k})(:);
    s60.(nums{k}) = s60.(nums{k})(:);
end
s17.label = s17.label(:); s17.deployment = s17.deployment(:);
s60.label = s60.label(:); s60.deployment = s60.deployment(:);

% Match instruments by (deployment, label)
key17 = strings(numel(s17.label),1);
for k=1:numel(s17.label), key17(k) = sprintf('%s/%s', s17.deployment{k}, s17.label{k}); end
key60 = strings(numel(s60.label),1);
for k=1:numel(s60.label), key60(k) = sprintf('%s/%s', s60.deployment{k}, s60.label{k}); end

[shared, i17, i60] = intersect(key17, key60, 'stable');
fprintf('Matched %d instruments between 17-min and 1-hour Phase 2 summaries.\n', numel(shared));

a17 = s17.alpha(i17); a60 = s60.alpha(i60);
b17 = s17.beta(i17);  b60 = s60.beta(i60);
r17 = s17.R2_Hs2(i17); r60 = s60.R2_Hs2(i60);
m17 = s17.modAmp_high(i17); m60 = s60.modAmp_high(i60);
hmed = s17.h_med(i17);

% Site for color coding
site = strings(numel(shared),1);
for k = 1:numel(shared)
    d = s17.deployment{i17(k)};
    if startsWith(d,'TBR')||startsWith(d,'TOR'), site(k)="Torrey";
    elseif startsWith(d,'SOL'),                  site(k)="Solana";
    elseif startsWith(d,'SIO'),                  site(k)="SIO Pier";
    elseif startsWith(d,'LPL'),                  site(k)="LPL lagoon";
    else,                                        site(k)="other";
    end
end
% Flag the kelp-fouled TBR23 MOP580_5m AND the 61-segment SIO25C partial
% deployment (R²=0.001 — fit is meaningless, dominates the RMS Δα).
isBad = false(numel(shared),1);
isPartial = false(numel(shared),1);
for k = 1:numel(shared)
    dep = s17.deployment{i17(k)}; lab = s17.label{i17(k)};
    isBad(k)     = strcmp(dep,'TBR23')  && strcmp(lab,'MOP580_5m');
    isPartial(k) = strcmp(dep,'SIO25C') && strcmp(lab,'SIO_6m');
end

siteColors = containers.Map();
siteColors('Torrey')     = [0.20 0.45 0.85];
siteColors('Solana')     = [0.85 0.30 0.20];
siteColors('SIO Pier')   = [0.95 0.65 0.10];
siteColors('LPL lagoon') = [0.30 0.65 0.30];

% ============== FIGURE: 4 panels =============================
fig = figure('Visible','off','Position',[100 100 1500 1100]);

% --- Panel 1: alpha 17-min vs 1-hour (axis clipped to bulk; partial deployment annotated)
subplot(2,2,1); hold on;
keep = ~isBad & ~isPartial;
lim = max([abs(a17(keep)); abs(a60(keep))])*1.15;
plot([-lim lim],[-lim lim], 'k:', 'LineWidth', 1.0, 'HandleVisibility','off');
plot([-lim lim],[0 0], 'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-lim lim], 'k-','LineWidth',0.5,'HandleVisibility','off');
sites = unique(site);
for st = sites'
    pick = (site == st) & ~isBad & ~isPartial;
    if any(pick)
        scatter(a17(pick), a60(pick), 70, siteColors(char(st)), 'filled', ...
            'MarkerEdgeColor','k', 'DisplayName', char(st));
    end
end
if any(isBad)
    scatter(a17(isBad), a60(isBad), 100, 'rx', 'LineWidth', 2, 'DisplayName','flagged (kelp)');
end
% Note any partial deployments outside the visible range
if any(isPartial)
    text(0.02, 0.98, sprintf('SIO25C (N=61, R^2=0.001) excluded; \\alpha_{1hr}=%+.3f off-axis', ...
        a60(isPartial)), 'Units','normalized','VerticalAlignment','top','FontSize',8, ...
        'BackgroundColor',[1 1 1 0.85],'EdgeColor','k','Margin',3);
end
xlabel('\alpha  (17-min, m/s per m^2)');
ylabel('\alpha  (1-hour, m/s per m^2)');
% Recompute headline stats excluding the partial-deployment outlier
a17k = a17(keep); a60k = a60(keep);
title(sprintf('H_s^2 slope: 17-min vs 1-hour   (R=%.3f, RMS \\Delta\\alpha=%.4f, |\\Delta\\alpha|<0.005 in %.0f%%)', ...
    corr(a17k,a60k), rms(a17k-a60k), 100*mean(abs(a17k-a60k)<0.005)), 'FontSize', 10);
xlim([-lim lim]); ylim([-lim lim]);
legend('Location','best','FontSize',9); grid on; axis square;

% --- Panel 2: beta 17-min vs 1-hour (axis clipped to bulk)
subplot(2,2,2); hold on;
b17k = b17(keep); b60k = b60(keep);
lim_b = max([abs(b17k); abs(b60k); 0.025])*1.15;
plot([-lim_b lim_b],[-lim_b lim_b], 'k:', 'LineWidth', 1.0, 'HandleVisibility','off');
plot([-lim_b lim_b],[0 0], 'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-lim_b lim_b], 'k-','LineWidth',0.5,'HandleVisibility','off');
rectangle('Position',[-0.02,-0.02,0.04,0.04],'EdgeColor','r','LineStyle','--','LineWidth',1.2);
text(0.02, -0.022, '\pm 2 cm/s noise box', 'Color','r','FontSize',9, ...
     'HorizontalAlignment','right','VerticalAlignment','top');
for st = sites'
    pick = (site == st) & ~isBad & ~isPartial;
    if any(pick)
        scatter(b17(pick), b60(pick), 70, siteColors(char(st)), 'filled', ...
            'MarkerEdgeColor','k','HandleVisibility','off');
    end
end
xlabel('\beta  (17-min, m/s)');
ylabel('\beta  (1-hour, m/s)');
title(sprintf('Intercept: 17-min vs 1-hour   (median |\\beta|: 17-min=%.4f, 1-hour=%.4f)', ...
    median(abs(b17k),'omitnan'), median(abs(b60k),'omitnan')), 'FontSize', 10);
xlim([-lim_b lim_b]); ylim([-lim_b lim_b]);
grid on; axis square;

% --- Panel 3: R^2 17-min vs 1-hour (above-diagonal = 1-hour fits better)
subplot(2,2,3); hold on;
plot([0 1],[0 1], 'k:', 'LineWidth', 1.0, 'HandleVisibility','off');
for st = sites'
    pick = (site == st) & ~isBad & ~isPartial;
    if any(pick)
        scatter(r17(pick), r60(pick), 70, siteColors(char(st)), 'filled', ...
            'MarkerEdgeColor','k','HandleVisibility','off');
    end
end
xlabel('R^2  (17-min)');
ylabel('R^2  (1-hour)');
nUp = sum((r60(keep) > r17(keep)));
title(sprintf('H_s^2-fit explanatory power   (median: 17-min=%.3f, 1-hour=%.3f, R^2 improves in %d/%d)', ...
    median(r17(keep),'omitnan'), median(r60(keep),'omitnan'), nUp, sum(keep)), 'FontSize', 10);
xlim([0 max([r17(keep);r60(keep);0.3])*1.1]); ylim([0 max([r17(keep);r60(keep);0.3])*1.1]);
grid on; axis square;

% --- Panel 4: delta-alpha histogram (clip to bulk; partial deployment off-axis)
subplot(2,2,4); hold on;
da = a60 - a17;
da_keep = da(keep);
% Bin width 0.002 (= 2 mm/s/m^2); range clipped to ±0.04 around 0
binEdges = -0.04:0.002:0.04;
histogram(da_keep, 'BinEdges', binEdges, 'FaceColor', [0.55 0.4 0.75], 'EdgeColor','k');
xline(0, 'k--', 'LineWidth', 1.2);
xline(median(da_keep,'omitnan'), 'r-', 'LineWidth', 1.4, ...
    'Label', sprintf('median \\Delta\\alpha = %+.4f', median(da_keep,'omitnan')), ...
    'LabelOrientation','horizontal');
xlabel('\Delta\alpha = \alpha_{1-hour} - \alpha_{17-min}   (m/s per m^2)');
ylabel('# instruments');
title(sprintf('Slope shift (1-hour − 17-min)   RMS=%.4f, |\\Delta\\alpha|<0.005 in %.0f%%, \\Delta\\alpha<0 in %.0f%%', ...
    rms(da_keep), 100*mean(abs(da_keep)<0.005), 100*mean(da_keep<0)), 'FontSize', 9);
xlim([-0.04 0.04]);
grid on;

% Save
out = fullfile(aggDir, 'seglen_compare_alpha_beta.png');
exportgraphics(fig, out, 'Resolution', 200);
close(fig);

% --- Print summary
fprintf('\nSeglen comparison summary (matched %d instruments):\n', numel(shared));
fprintf('  alpha:   R(17,60) = %.3f   RMS Δα = %.4f m/s/m²   |Δα|<0.005 in %.0f%%\n', ...
    corr(a17,a60), rms(a17-a60), 100*mean(abs(a17-a60)<0.005));
fprintf('  beta:    median |β| 17-min = %.4f m/s,  1-hour = %.4f m/s\n', ...
    median(abs(b17),'omitnan'), median(abs(b60),'omitnan'));
fprintf('           |β|<2cm/s in 17-min: %.0f%%   in 1-hour: %.0f%%\n', ...
    100*mean(abs(b17)<0.02,'omitnan'), 100*mean(abs(b60)<0.02,'omitnan'));
fprintf('  R²:      median 17-min = %.3f,  1-hour = %.3f\n', ...
    median(r17,'omitnan'), median(r60,'omitnan'));
fprintf('\nFigure: %s\n', out);
end


function y = rms(x)
y = sqrt(mean(x.^2,'omitnan'));
end
