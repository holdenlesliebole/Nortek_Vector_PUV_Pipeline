% FIG_L4_BOUNDWAVE_CATALOG  Cross-deployment summary of L4 bound/free IG split.
%
%   Loads every outputs/L4/{deployment}/*_L4.mat and the corresponding
%   L2 file, then produces a 4-panel PNG summarising the Hasselmann
%   bound-wave result across the catalog:
%
%     (1) median bound_frac per instrument vs median depth, color-coded
%         by deployment. The expected Hasselmann-Herbers monotonic
%         depth dependence should show as a clear shallow→deep transition.
%     (2) per-segment var_ig_bound vs Hs_SS^2 (log-log) — the Herbers
%         signature: bound IG variance scales as the square of swell
%         amplitude squared, i.e. ~Hs^4. Color by depth class.
%     (3) frequency-resolved bound_frac_f(f) within the IG band,
%         averaged across instruments in each depth class.
%     (4) bound_frac histogram across all instruments, with the 0.95
%         saturation flag marked.
%
%   Output: outputs/validation/L4_boundwave/boundwave_catalog.png
% Author: Holden Leslie-Bole, 2026

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

% --- collect per-instrument summary ---
items = struct('deployment',{},'instrument',{},'depth',{}, ...
               'bound_frac_med',{},'bound_frac_q1',{},'bound_frac_q3',{}, ...
               'var_bound',{},'var_total',{},'Hs_SS',{}, ...
               'fIG',{},'bound_frac_f',{});

nItem = 0;

for d = 1:nDeploy
    dName = deployNames{d};
    try
        configFn = registry(dName);
        cfg = configFn();
    catch
        continue
    end
    l4Dir = fullfile(cfg.outputDir, 'L4', cfg.name);
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l4Dir), continue, end
    l4Files = dir(fullfile(l4Dir, '*_L4.mat'));

    for k = 1:numel(l4Files)
        instr = regexprep(l4Files(k).name, '_L4\.mat$', '');
        l4Path = fullfile(l4Dir, l4Files(k).name);
        l2Path = fullfile(l2Dir, [instr '_L2.mat']);
        if ~isfile(l2Path), continue, end
        try
            ld = load(l4Path, 'L4'); L4 = ld.L4;
            l2 = load(l2Path, 'L2'); L2 = l2.L2;
            if ~isfield(L4, 'boundwave'), continue, end
        catch
            continue
        end

        % L4 and L2 segment arrays are not guaranteed to align by index --
        % see shared/l4_l2_index_map.m. Masking L2.Hs_SS with an L4-length
        % logical is silently wrong on the records whose L2 gained a leading
        % segment, so pair the two by time.
        [l4map, ainfo] = l4_l2_index_map(L2, L4);
        if ~ainfo.identity
            fprintf('  [align] %s/%s: L4 %d segs vs L2 %d, max index offset %d\n', ...
                dName, instr, ainfo.nL4, ainfo.nL2, ainfo.maxOffset);
        end
        % keep L2 segments that have an L4 counterpart which L4 calls valid
        i2 = find(~isnan(l4map));
        i2 = i2(L4.boundwave.segValid(l4map(i2)));
        if isempty(i2), continue, end
        i4 = l4map(i2);

        bf = L4.boundwave.bound_frac(i4);
        vb = L4.boundwave.var_ig_bound(i4);
        vt = L4.boundwave.var_ig_total(i4);
        HsSS = L2.Hs_SS(i2);
        depth = median(L4.boundwave.depth, 'omitnan');

        % per-bin bound fraction, averaged over valid segments
        bff = mean(L4.boundwave.bound_frac_f(:, i4), 2, 'omitnan');

        nItem = nItem + 1;
        items(nItem).deployment    = dName;
        items(nItem).instrument    = instr;
        items(nItem).depth         = depth;
        items(nItem).bound_frac_med = median(bf, 'omitnan');
        items(nItem).bound_frac_q1  = quantile(bf, 0.25);
        items(nItem).bound_frac_q3  = quantile(bf, 0.75);
        items(nItem).var_bound      = vb;
        items(nItem).var_total      = vt;
        items(nItem).Hs_SS          = HsSS;
        items(nItem).fIG            = L4.boundwave.fIG;
        items(nItem).bound_frac_f   = bff;
    end
end

fprintf('Loaded %d instruments with bound-wave outputs.\n', numel(items));
if isempty(items)
    error('fig_L4_boundwave_catalog:noData', 'No L4.boundwave found.');
end

%% --- prepare aggregates ---
depths        = [items.depth].';
bfMed         = [items.bound_frac_med].';
bfQ1          = [items.bound_frac_q1].';
bfQ3          = [items.bound_frac_q3].';
deployList    = {items.deployment}.';
deployUnique  = unique(deployList);
nDep          = numel(deployUnique);
depCmap       = lines(nDep);

% depth classes for panels 2/3
classEdges  = [0 6 8.5 12.5 35];
classLabels = {'shallow (\leq 6 m)','mid (7-8 m)','deep (9-12 m)','outer (\geq 13 m)'};
classCols   = [0.78 0.16 0.16;   0.86 0.50 0.16;   0.16 0.50 0.86;   0.10 0.30 0.60];
classIdxItem = discretize(depths, classEdges);

% panel 3: bound_frac_f averaged within each class
fIG = items(1).fIG;
nf  = numel(fIG);
classMeanF = NaN(nf, numel(classLabels));
for c = 1:numel(classLabels)
    mask = classIdxItem == c;
    if ~any(mask), continue, end
    M = cat(2, items(mask).bound_frac_f);
    classMeanF(:, c) = mean(M, 2, 'omitnan');
end

% panel 2: per-segment scatter (subsample for speed)
maxPerInstr = 200;
panel2_x = []; panel2_y = []; panel2_c = [];
for i = 1:numel(items)
    nS = numel(items(i).Hs_SS);
    if nS == 0, continue, end
    idx = randperm(nS, min(maxPerInstr, nS));
    panel2_x = [panel2_x; items(i).Hs_SS(idx).^2];           %#ok<AGROW>
    panel2_y = [panel2_y; items(i).var_bound(idx)];          %#ok<AGROW>
    cIdx = classIdxItem(i);
    if isnan(cIdx), cIdx = 1; end
    panel2_c = [panel2_c; repmat(classCols(cIdx,:), numel(idx), 1)]; %#ok<AGROW>
end

%% --- figure ---
figDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation', 'L4_boundwave');
if ~exist(figDir, 'dir'), mkdir(figDir); end

fig = figure('Visible','off','Position',[100 100 1400 1000]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

% (1) bound_frac vs depth
nexttile;
hold on;
hDep = gobjects(nDep, 1);
for d = 1:nDep
    mask = strcmp(deployList, deployUnique{d});
    errorbar(depths(mask), bfMed(mask), ...
        bfMed(mask)-bfQ1(mask), bfQ3(mask)-bfMed(mask), ...
        'o', 'Color', depCmap(d,:), 'MarkerFaceColor', depCmap(d,:), ...
        'MarkerSize', 7, 'LineWidth', 1.0, 'CapSize', 3, ...
        'DisplayName', deployUnique{d});
    hDep(d) = plot(NaN, NaN, 'o', 'MarkerFaceColor', depCmap(d,:), ...
        'MarkerEdgeColor', depCmap(d,:), 'DisplayName', deployUnique{d});
end
yline(0.95, 'k:', 'DisplayName', 'saturation');
xlabel('mean depth (m)');
ylabel('bound\_frac (median \pm IQR per instrument)');
title('IG bound fraction vs depth');
xlim([4 32]);
ylim([0 1.05]);
legend(hDep, 'Location','eastoutside','FontSize',7);
grid on;

% (2) var_bound vs Hs_SS^2
nexttile;
hold on;
scatter(panel2_x, panel2_y, 6, panel2_c, 'filled', 'MarkerFaceAlpha', 0.35);
set(gca, 'XScale','log','YScale','log');
% reference Hs^4 line (var_bound ~ Hs^4 expected for fixed depth)
xRef = logspace(log10(min(panel2_x)+1e-3), log10(max(panel2_x)), 50);
plot(xRef, 1e-4 * xRef.^2 / median(panel2_x).^2, 'k:', 'LineWidth', 1.2);
text(xRef(end), 1e-4*xRef(end).^2/median(panel2_x).^2, ' var \propto Hs^4', ...
    'FontSize', 9, 'VerticalAlignment','bottom');
xlabel('Hs_{SS}^2 (m^2)');
ylabel('var(\eta_{IG,bound}) (m^2)');
title('Bound IG variance vs swell amplitude');
grid on;

% legend by class
for c = 1:numel(classLabels)
    plot(NaN, NaN, 'o', 'MarkerFaceColor', classCols(c,:), ...
         'MarkerEdgeColor', classCols(c,:), 'DisplayName', classLabels{c});
end
legend('Location','northwest', 'FontSize', 8);

% (3) bound_frac_f vs IG frequency by depth class
nexttile;
hold on;
for c = 1:numel(classLabels)
    if all(isnan(classMeanF(:, c))), continue, end
    plot(fIG, classMeanF(:, c), '-', 'Color', classCols(c,:), ...
         'LineWidth', 1.8, 'DisplayName', classLabels{c});
end
yline(0.5, 'k:');
xlabel('frequency (Hz)');
ylabel('bound\_frac(f)');
title('Per-bin bound fraction in IG band');
xlim([0.004 0.04]);
ylim([0 1.05]);
legend('Location','best','FontSize',8);
grid on;

% (4) histogram + saturation flag
nexttile;
edges = 0:0.05:1.0;
histogram(bfMed, edges, 'FaceColor', [0.4 0.5 0.7], 'EdgeColor', 'k');
hold on;
xline(0.95, 'r--', 'LineWidth', 1.5);
text(0.95, 0.5*max(histcounts(bfMed,edges)), '  saturated (>= 0.95)', ...
    'Color','r','FontSize',9);
xlabel('median bound\_frac per instrument');
ylabel('count');
title(sprintf('Distribution across %d instruments', numel(items)));
grid on;

%% --- save ---
outPng = fullfile(figDir, 'boundwave_catalog.png');
exportgraphics(fig, outPng, 'Resolution', 200);
close(fig);
fprintf('Saved: %s\n', outPng);

%% --- print summary table ---
fprintf('\nPer-instrument summary (bound_frac median):\n');
fprintf('  %-10s  %-14s  %5s  %8s\n', 'deploy', 'instrument', 'depth', 'bound_f');
[~, ord] = sort(depths);
for j = 1:numel(ord)
    i = ord(j);
    fprintf('  %-10s  %-14s  %5.2f  %8.3f\n', ...
        items(i).deployment, items(i).instrument, items(i).depth, items(i).bound_frac_med);
end
nSat = sum(bfMed >= 0.95);
fprintf('\n%d/%d instruments saturated (bound_frac >= 0.95).\n', nSat, numel(items));
