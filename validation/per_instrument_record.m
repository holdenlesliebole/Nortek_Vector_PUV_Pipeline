function per_instrument_record(opts)
% PER_INSTRUMENT_RECORD  For each instrument with an L2 file, produce a
% one-page summary showing the uMean time series colored by Hs and the
% uMean vs Hs^2 scatter with Stokes return-flow theory.
%
% Saves:
%   outputs/validation/mean_flow/_per_instrument/<deployment>_<label>.png
%   outputs/validation/mean_flow/_per_instrument/contact_sheet.pdf
%
% Purpose
%   Show the *records* themselves, not just aggregate statistics. Each
%   instrument should display:
%     (a) a uMean time series that tracks storm events (not flat noise),
%     (b) a Hs^2 scatter where the slope is comparable to Stokes theory.
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts,'L2dir'),  opts.L2dir  = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts,'outDir'), opts.outDir = fullfile(pipelineRoot,'outputs','validation','mean_flow','_per_instrument'); end
if ~isfield(opts,'HsMin'),  opts.HsMin  = 0.2; end
if ~exist(opts.outDir,'dir'), mkdir(opts.outDir); end

reg = deployment_registry();
deployments = sort(keys(reg));

g = 9.81;
allMeta = struct('deployment',{},'label',{},'h_med',{},'alpha',{}, ...
                 'beta',{},'R2',{},'N',{},'pngFile',{});

for iD = 1:numel(deployments)
    dep = deployments{iD};
    depDir = fullfile(opts.L2dir, dep);
    if ~isfolder(depDir), continue; end
    files = dir(fullfile(depDir,'*_L2.mat'));
    files = files(~contains({files.name},'.bak'));
    if isempty(files), continue; end
    for iF = 1:numel(files)
        L2file = fullfile(depDir, files(iF).name);
        label = regexprep(files(iF).name,'_L2\.mat$','');
        try
            S = load(L2file); L2 = S.L2;
        catch ME
            warning('Could not load %s: %s', L2file, ME.message);
            continue
        end
        if ~isfield(L2,'uMean') || ~isfield(L2,'Hs') || ~isfield(L2,'time')
            continue
        end

        valid = L2.segValid(:) & ~isnan(L2.uMean(:)) & ~isnan(L2.Hs(:));
        if sum(valid) < 50, continue; end
        valid_fit = valid & L2.Hs(:) >= opts.HsMin;

        t      = L2.time(valid);
        uMean  = L2.uMean(valid);
        Hs     = L2.Hs(valid);
        depth  = L2.depth(valid);
        h_med  = median(depth);

        Hs_fit = L2.Hs(valid_fit);
        u_fit  = L2.uMean(valid_fit);
        X = [Hs_fit.^2, ones(size(Hs_fit))];
        b = regress(u_fit, X);
        yhat = X*b;
        R2   = 1 - sum((u_fit - yhat).^2) / sum((u_fit - mean(u_fit)).^2);
        alpha_th = -g / (16 * sqrt(g*h_med) * h_med);

        fig = figure('Visible','off','Position',[100 100 1400 900]);

        % Two stacked time-series panels on top half, then 2 analysis panels below
        % Use 4-row x 2-col subplot grid; rows 1,2 span both columns.
        ax1 = subplot(4,2, [1 2]);
        plot(ax1, t, Hs, 'k-', 'LineWidth', 0.6);
        ylabel(ax1, 'H_s (m)');
        grid(ax1,'on');
        title(ax1, sprintf('%s — %s   (h_{med}=%.1f m, N=%d valid segments)', ...
            dep, tex_label_local(label), h_med, sum(valid)), 'FontSize', 12);

        ax2 = subplot(4,2, [3 4]);
        scatter(ax2, t, uMean, 8, Hs, 'filled', 'MarkerEdgeColor','none'); hold(ax2,'on');
        yline(ax2, 0, 'k:','HandleVisibility','off');
        cb = colorbar(ax2,'Location','eastoutside');
        cb.Label.String = 'H_s (m)';
        colormap(ax2, parula);
        ylabel(ax2, 'uMean (m/s)');
        xlabel(ax2, 'time');
        grid(ax2,'on');
        u_clip = prctile(uMean, [1 99]);
        if range(u_clip) > 0
            ylim(ax2, u_clip + 0.1*range(u_clip)*[-1 1]);
        end
        % Match x-limits so the time series stack lines up
        linkaxes([ax1 ax2], 'x');
        xlim(ax1, [min(t) max(t)]);

        % --- Panel 3: uMean vs Hs^2 scatter with theory + fit
        ax3 = subplot(4,2, [5 7]);
        scatter(ax3, Hs.^2, uMean, 10, 'b', 'filled', 'MarkerFaceAlpha', 0.20, 'HandleVisibility','off'); hold(ax3,'on');
        xPlot = linspace(0, max(Hs)^2*1.05, 50);
        plot(ax3, xPlot, b(1)*xPlot + b(2), 'r-', 'LineWidth', 1.8, 'DisplayName','linear fit');
        plot(ax3, xPlot, alpha_th*xPlot, 'k--', 'LineWidth', 1.4, 'DisplayName','Stokes theory');
        yline(ax3, 0, 'k:','HandleVisibility','off');
        xlabel(ax3, 'H_s^2  (m^2)');
        ylabel(ax3, 'uMean (m/s)');
        title(ax3, sprintf('\\alpha=%+.4f, \\beta=%+.4f, R^2=%.3f, \\alpha_{th}=%+.4f', ...
            b(1), b(2), R2, alpha_th), 'FontSize', 10);
        legend(ax3,'Location','best','FontSize',9);
        grid(ax3,'on');

        % --- Panel 4: uMean distribution stratified by Hs
        ax4 = subplot(4,2, [6 8]);
        strata = [0 0.6; 0.6 1.0; 1.0 inf];
        cols = [0.4 0.7 1.0; 0.95 0.65 0.10; 0.85 0.20 0.20];
        labs = {'H_s<0.6 m','0.6 \leq H_s<1.0 m','H_s\geq 1.0 m'};
        any_plotted = false;
        for iS = 1:3
            in = Hs >= strata(iS,1) & Hs < strata(iS,2);
            if sum(in) >= 20
                edges = linspace(min(uMean), max(uMean), 31);
                centers = 0.5*(edges(1:end-1)+edges(2:end));
                cnt = histcounts(uMean(in), edges, 'Normalization','pdf');
                plot(ax4, centers, cnt, '-', 'Color', cols(iS,:), 'LineWidth', 1.6, ...
                     'DisplayName', sprintf('%s (N=%d, mean=%+.3f m/s)', labs{iS}, sum(in), mean(uMean(in))));
                hold(ax4,'on'); any_plotted = true;
            end
        end
        xline(ax4, 0, 'k:','HandleVisibility','off');
        xlabel(ax4, 'uMean (m/s)');
        ylabel(ax4, 'pdf');
        title(ax4, 'uMean distribution stratified by H_s','FontSize',10);
        if any_plotted
            legend(ax4,'Location','best','FontSize',9);
        end
        grid(ax4,'on');

        pngFile = fullfile(opts.outDir, sprintf('%s_%s.png', dep, label));
        exportgraphics(fig, pngFile, 'Resolution', 180);
        close(fig);

        allMeta(end+1) = struct('deployment',dep,'label',label, ...
            'h_med',h_med,'alpha',b(1),'beta',b(2),'R2',R2, ...
            'N',sum(valid),'pngFile',pngFile); %#ok<AGROW>
        fprintf('  %-12s %-14s alpha=%+.4f beta=%+.4f R2=%.3f N=%d  ->  %s\n', ...
            dep, label, b(1), b(2), R2, sum(valid), pngFile);
    end
end

% Save manifest
T = struct2table(allMeta);
writetable(T, fullfile(opts.outDir, 'per_instrument_manifest.csv'));
fprintf('\nGenerated %d per-instrument figures.\n', height(T));
fprintf('Manifest: %s\n', fullfile(opts.outDir,'per_instrument_manifest.csv'));
end


function s = tex_label_local(label)
% Convert MOP580_7m -> MOP580_{7m} for proper TeX subscripting
s = regexprep(label, '_(\w+)$', '_{$1}');
end
