% fig_bulk_Hs_all_deployments.m
% Author: Holden Leslie-Bole, 2026
% Cross-deployment Hs comparison: PUV vs MOP for all instruments.
% Produces a multi-panel scatter (one per instrument) and a summary
% bar chart of bias and RMSE. For Beamer slide.

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
if ~exist('read_MOPline2', 'file'), addpath(toolboxPath); end

registry    = deployment_registry();
deployNames = sort(keys(registry));

%% Collect per-instrument Hs comparison data
results = struct('deploy', {}, 'label', {}, 'depth', {}, ...
    'Hs_puv', {}, 'Hs_mop', {}, ...
    'R2', {}, 'RMSE', {}, 'bias', {}, 'N', {}, 'siteID', {});

for d = 1:numel(deployNames)
    dName = deployNames{d};
    try
        configFn = registry(dName);
        cfg = configFn();
    catch
        continue
    end

    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l2Dir), continue; end

    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);
        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l2File), continue; end

        L2 = load(l2File, 'L2').L2;
        if ~isfield(L2, 'mopStation') || isempty(L2.mopStation)
            continue
        end

        validIdx = L2.segValid;
        if sum(validIdx) < 50, continue; end

        % Load MOP
        tStart = min(L2.time(validIdx));
        tEnd   = max(L2.time(validIdx));
        if isempty(tStart.TimeZone), tStart.TimeZone = 'UTC'; tEnd.TimeZone = 'UTC'; end

        try
            MOP = read_MOPline2(L2.mopStation, tStart, tEnd);
        catch
            continue
        end

        h_mop = double(MOP.depth);
        h_puv = median(L2.depth(validIdx), 'omitnan');
        freq_mop = double(MOP.frequency(:));
        fbw = double(MOP.fbw(:));

        % Shoaling factor
        omega_mop = 2*pi*freq_mop;
        k_mop = get_wavenumber(omega_mop, h_mop);
        k_puv = get_wavenumber(omega_mop, h_puv);
        cg_mop = get_cg(k_mop, h_mop);
        cg_puv = get_cg(k_puv, h_puv);
        shoalFactor = cg_mop(:) ./ cg_puv(:);
        spec_shoaled = MOP.spec1D .* shoalFactor';

        % SS band
        fSS = L2.params.fSS;
        iSS = freq_mop >= fSS(1) & freq_mop <= fSS(2);

        % Match times
        t_mop = MOP.time;
        L2_time = L2.time;
        if isempty(L2_time.TimeZone), L2_time.TimeZone = t_mop.TimeZone; end

        validTimes = find(validIdx);
        Hs_puv_all = [];
        Hs_mop_all = [];

        for t = 1:length(t_mop)
            dt = abs(L2_time(validTimes) - t_mop(t));
            [minDt, iMin] = min(dt);
            if minDt > minutes(30), continue; end

            pi_idx = validTimes(iMin);
            Hs_p = L2.Hs(pi_idx);
            m0_m = sum(spec_shoaled(t, iSS) .* fbw(iSS)');
            Hs_m = 4 * sqrt(max(m0_m, 0));

            if Hs_m > 0.05 && ~isnan(Hs_p)
                Hs_puv_all(end+1) = Hs_p; %#ok<SAGROW>
                Hs_mop_all(end+1) = Hs_m; %#ok<SAGROW>
            end
        end

        if length(Hs_puv_all) < 30, continue; end

        R = corrcoef(Hs_puv_all, Hs_mop_all);
        r2 = R(1,2)^2;
        rmse = sqrt(mean((Hs_puv_all - Hs_mop_all).^2));
        bias = mean(Hs_puv_all - Hs_mop_all);

        % Site classification
        lbl = L2.label;
        dep = L2.deploymentName;
        if contains(lbl, 'SIO'),          sid = 2;
        elseif contains(lbl, 'LPL'),      sid = 4;
        elseif contains(lbl, 'MOP651') || contains(lbl, 'MOP654') || contains(dep, 'SOL'), sid = 3;
        elseif contains(lbl, 'MOP580') || contains(lbl, 'MOP586'), sid = 1;
        else,                              sid = 1;
        end

        r = struct('deploy', dep, 'label', lbl, 'depth', h_puv, ...
            'Hs_puv', {Hs_puv_all}, 'Hs_mop', {Hs_mop_all}, ...
            'R2', r2, 'RMSE', rmse, 'bias', bias, 'N', length(Hs_puv_all), ...
            'siteID', sid);
        results(end+1) = r; %#ok<SAGROW>

        fprintf('  %s/%s: R2=%.2f, RMSE=%.3f, bias=%.3f m, N=%d\n', ...
            dep, lbl, r2, rmse, bias, length(Hs_puv_all));
    end
end

nInstr = numel(results);
fprintf('\n=== %d instruments with MOP comparison ===\n', nInstr);

%% Figure 1: Combined scatter plot with per-site fit lines
fig1 = figure('Position', [100 100 700 600], 'Name', 'All-instrument Hs scatter');

siteNames = {'Torrey Pines', 'SIO Pier', 'Solana Beach', 'Los Penasquitos'};
siteColors = [0.2 0.4 0.8;   % blue
              0.9 0.3 0.2;   % red
              0.3 0.7 0.3;   % green
              0.8 0.6 0.1];  % gold

hold on;
maxH = 0;

% First pass: scatter points
for s = 1:4
    hp_all = []; hm_all = [];
    for i = 1:nInstr
        if results(i).siteID == s
            hp_all = [hp_all results(i).Hs_puv]; %#ok<AGROW>
            hm_all = [hm_all results(i).Hs_mop]; %#ok<AGROW>
        end
    end
    if ~isempty(hp_all)
        scatter(hm_all, hp_all, 6, siteColors(s,:), 'filled', ...
            'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
        maxH = max(maxH, max([hp_all hm_all]));
    end
end

% 1:1 line
plot([0 maxH*1.1], [0 maxH*1.1], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');

% Second pass: fit lines with equations in legend
for s = 1:4
    hp_all = []; hm_all = [];
    for i = 1:nInstr
        if results(i).siteID == s
            hp_all = [hp_all results(i).Hs_puv]; %#ok<AGROW>
            hm_all = [hm_all results(i).Hs_mop]; %#ok<AGROW>
        end
    end
    if length(hp_all) > 50
        p = polyfit(hm_all, hp_all, 1);
        xfit = linspace(min(hm_all), max(hm_all), 100);
        yfit = polyval(p, xfit);
        plot(xfit, yfit, '-', 'Color', siteColors(s,:), 'LineWidth', 2, ...
            'DisplayName', sprintf('%s: %.2fx %+.2f', siteNames{s}, p(1), p(2)));
    end
end

xlabel('H_s MOP shoaled (m)');
ylabel('H_s PUV (m)');
title(sprintf('PUV vs MOP H_s — %d instruments, all deployments', nInstr));
legend('Location', 'northwest', 'FontSize', 7);
axis equal; grid on;
xlim([0 maxH*1.1]); ylim([0 maxH*1.1]);

%% Figure 2: Summary bar chart — R2, RMSE, bias per instrument
fig2 = figure('Position', [100 100 1100 650], 'Name', 'Cross-deployment summary');

% Sort by depth
[~, sortIdx] = sort([results.depth]);
sortedR = results(sortIdx);

x = 1:nInstr;
% Single-line labels: "DEPLOY LABEL (Xm)"
instrLabels = arrayfun(@(r) sprintf('%s %s (%.0fm)', r.deploy, ...
    strrep(r.label, '_', ' '), r.depth), sortedR, 'UniformOutput', false);

% Color bars by site
barColors = siteColors([sortedR.siteID], :);

subplot(3,1,1)
bh1 = bar(x, [sortedR.R2], 'FaceColor', 'flat');
bh1.CData = barColors;
ylabel('R^2');
title('Cross-deployment H_s validation: PUV vs MOP (sorted by depth)');
set(gca, 'XTick', [], 'XLim', [0.5 nInstr+0.5]);
ylim([0.5 1]); yline(0.8, 'r--'); grid on;

subplot(3,1,2)
bh2 = bar(x, [sortedR.RMSE]*100, 'FaceColor', 'flat');
bh2.CData = barColors;
ylabel('RMSE (cm)');
set(gca, 'XTick', [], 'XLim', [0.5 nInstr+0.5]);
grid on;

subplot(3,1,3)
bh3 = bar(x, [sortedR.bias]*100, 'FaceColor', 'flat');
bh3.CData = barColors;
ylabel('Bias (cm)');
set(gca, 'XTick', x, 'XTickLabel', instrLabels, 'XLim', [0.5 nInstr+0.5], ...
    'FontSize', 5.5);
xtickangle(60);
yline(0, 'k-'); grid on;

%% Save
diagDir = fullfile('outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

exportgraphics(fig1, fullfile(diagDir, 'all_deployments_Hs_scatter.png'), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, 'all_deployments_Hs_summary.png'), 'Resolution', 200);
fprintf('\nFigures saved to %s\n', diagDir);

% Print summary table
fprintf('\n  %-8s  %-14s  %5s  %5s  %6s  %6s  %5s\n', ...
    'Deploy', 'Instrument', 'Depth', 'R2', 'RMSE', 'Bias', 'N');
fprintf('  %s\n', repmat('-', 1, 60));
for i = 1:nInstr
    r = sortedR(i);
    fprintf('  %-8s  %-14s  %5.1f  %5.2f  %5.3fm  %+5.3fm  %5d\n', ...
        r.deploy, r.label, r.depth, r.R2, r.RMSE, r.bias, r.N);
end
