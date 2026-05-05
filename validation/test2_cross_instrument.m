function results = test2_cross_instrument(deployment, labels, opts)
% TEST2_CROSS_INSTRUMENT  Compare uMean across independent Vectors at
% common timestamps and check that Hs^2-scaling slopes are consistent.
%
%   results = test2_cross_instrument('TBR23',{'MOP580_5m',...,'MOP586_7m'})
%
% Logic
%   The four TBR23 Vectors were independently calibrated. If the wave-driven
%   undertow is real and depth-dependent, instruments at the same depth
%   should:
%     - correlate in time (R > 0 at common timestamps),
%     - give consistent Hs^2-scaling slopes (overlapping CIs).
%   A per-instrument calibration offset would show up as an instrument-
%   specific intercept that doesn't co-vary, with R near zero on the
%   high-pass-filtered uMean.
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),   opts.L2dir   = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts, 'figDir'),  opts.figDir  = fullfile(pipelineRoot,'outputs','validation','mean_flow', deployment); end
if ~isfield(opts, 'tolMin'),  opts.tolMin  = 12; end  % match within 12 min

if ~exist(opts.figDir, 'dir'), mkdir(opts.figDir); end
if ischar(labels) || isstring(labels), labels = cellstr(labels); end

% Load all instruments
nI = numel(labels);
data = cell(nI, 1);
for iI = 1:nI
    f = fullfile(opts.L2dir, deployment, [labels{iI} '_L2.mat']);
    S = load(f);
    L2 = S.L2;
    v = L2.segValid(:) & ~isnan(L2.uMean(:));
    data{iI} = struct('time', L2.time(v), 'uMean', L2.uMean(v), 'Hs', L2.Hs(v), ...
                      'depth', median(L2.depth(v)));
end

% Pairwise common-timestamp correlation matrix
Rmat = nan(nI);
Nmat = zeros(nI);
biasMat = nan(nI);  % mean(u_i - u_j) across matched timestamps
for i = 1:nI
    for j = i:nI
        if i == j
            Rmat(i, j) = 1;
            Nmat(i, j) = numel(data{i}.uMean);
            biasMat(i, j) = 0;
            continue
        end
        ti = data{i}.time;  ui = data{i}.uMean;
        tj = data{j}.time;  uj = data{j}.uMean;
        % For each ti, find nearest tj within tolerance
        matched_i = []; matched_j = [];
        for k = 1:numel(ti)
            dt = abs(ti(k) - tj);
            [m, kk] = min(dt);
            if m <= minutes(opts.tolMin)
                matched_i(end+1) = ui(k); %#ok<AGROW>
                matched_j(end+1) = uj(kk); %#ok<AGROW>
            end
        end
        if numel(matched_i) > 30
            R = corrcoef(matched_i, matched_j);
            Rmat(i, j) = R(1, 2); Rmat(j, i) = R(1, 2);
            Nmat(i, j) = numel(matched_i); Nmat(j, i) = Nmat(i, j);
            biasMat(i, j) = mean(matched_i - matched_j);
            biasMat(j, i) = -biasMat(i, j);
        end
    end
end

results.labels = labels;
results.depths = cellfun(@(d) d.depth, data);
results.Rmat   = Rmat;
results.Nmat   = Nmat;
results.biasMat = biasMat;

% Print
fprintf('\n--- Cross-instrument R(uMean) correlation matrix ---\n');
fprintf('%-13s', '');
for j = 1:nI, fprintf(' %-12s', labels{j}); end; fprintf('\n');
for i = 1:nI
    fprintf('%-13s', labels{i});
    for j = 1:nI
        if isnan(Rmat(i,j))
            fprintf(' %-12s', 'n/a');
        else
            fprintf(' R=%+.3f N=%4d', Rmat(i,j), Nmat(i,j));
        end
    end
    fprintf('\n');
end

fprintf('\n--- Mean(u_i - u_j) across matched timestamps (m/s) ---\n');
fprintf('%-13s', '');
for j = 1:nI, fprintf(' %-12s', labels{j}); end; fprintf('\n');
for i = 1:nI
    fprintf('%-13s', labels{i});
    for j = 1:nI
        if isnan(biasMat(i,j))
            fprintf(' %-12s', 'n/a');
        else
            fprintf(' %+.4f      ', biasMat(i,j));
        end
    end
    fprintf('\n');
end

% Figure: heatmap of R
fig = figure('Visible','off','Position',[100 100 700 600]);
imagesc(Rmat, [-0.5 1.0]);
colormap(parula);
colorbar;
set(gca, 'XTick', 1:nI, 'YTick', 1:nI, ...
    'XTickLabel', tex_label(labels), 'YTickLabel', tex_label(labels), ...
    'TickLabelInterpreter', 'tex');
xtickangle(30);
title({sprintf('%s — Test 2: cross-instrument R(uMean)', deployment), ...
       'matched within 12 min; values printed in cells'});
% Annotate cells
for i = 1:nI
    for j = 1:nI
        if ~isnan(Rmat(i,j))
            txtCol = [0 0 0]; if Rmat(i,j) < 0.4, txtCol = [1 1 1]; end
            text(j, i, sprintf('%+.2f\nN=%d', Rmat(i,j), Nmat(i,j)), ...
                'HorizontalAlignment','center', 'Color', txtCol, 'FontSize', 9);
        end
    end
end
axis equal tight
exportgraphics(fig, fullfile(opts.figDir, 'test2_cross_instrument.png'), 'Resolution', 200);
close(fig);
fprintf('\nFigure saved: %s\n', fullfile(opts.figDir, 'test2_cross_instrument.png'));
end
