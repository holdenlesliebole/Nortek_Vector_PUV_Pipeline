function results = test1b_robustness_checks(opts)
% TEST1B_ROBUSTNESS_CHECKS  Two follow-up fits per instrument addressing
% the strongest objections to the H_s² scaling argument:
%   (a) Same fit on the alongshore component vMean (= α_v·H_s² + β_v).
%       Tests whether α is specific to cross-shore physics or generic
%       storm-coherent forcing (wind, atmospheric pressure, alongshore
%       gradients all correlate with H_s).
%   (b) Cross-shore fit restricted to H_s ≥ 1 m. Stokes return-flow
%       theory is supposed to apply cleanly only in the wave-forcing-
%       dominant regime; refitting just that subset isolates whether
%       low R² at the full range was contamination by quiescent-period
%       residual currents.
%
% Reads L2 files from outputs/L2_17min/ (legacy 17-min) and outputs/L2/
% (canonical 1-hour). Saves alongshore_summary and highHs_summary
% structs to outputs/validation/mean_flow/_aggregate/robustness_summary.mat
% plus diagnostic figures.
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts,'L2dir_17'),  opts.L2dir_17 = fullfile(pipelineRoot,'outputs','L2_17min'); end
if ~isfield(opts,'L2dir_60'),  opts.L2dir_60 = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts,'aggDir'),    opts.aggDir   = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate'); end
if ~isfield(opts,'HsMin'),     opts.HsMin    = 0.2; end
if ~isfield(opts,'HsHigh'),    opts.HsHigh   = 1.0; end
if ~exist(opts.aggDir,'dir'), mkdir(opts.aggDir); end

reg = deployment_registry();
deployments = sort(keys(reg));

g = 9.81;
results = struct();
results.deployment = {};
results.label = {};
results.h_med = [];
% Cross-shore (u) fits
results.alpha_u_17 = []; results.beta_u_17 = []; results.R2_u_17 = []; results.N_17 = [];
results.alpha_u_60 = []; results.beta_u_60 = []; results.R2_u_60 = []; results.N_60 = [];
% Alongshore (v) fits — same segments
results.alpha_v_17 = []; results.beta_v_17 = []; results.R2_v_17 = [];
results.alpha_v_60 = []; results.beta_v_60 = []; results.R2_v_60 = [];
% Cross-shore high-H_s-only (H_s ≥ HsHigh)
results.alpha_uH_17 = []; results.beta_uH_17 = []; results.R2_uH_17 = []; results.N_uH_17 = [];
results.alpha_uH_60 = []; results.beta_uH_60 = []; results.R2_uH_60 = []; results.N_uH_60 = [];
% Theory
results.alpha_th = [];

for iD = 1:numel(deployments)
    dep = deployments{iD};
    for tag = {'17','60'}
        if strcmp(tag{1},'17'), L2dir = opts.L2dir_17; else, L2dir = opts.L2dir_60; end
        depDir = fullfile(L2dir, dep);
        if ~isfolder(depDir), continue; end
    end
    depDir17 = fullfile(opts.L2dir_17, dep);
    depDir60 = fullfile(opts.L2dir_60, dep);
    if ~isfolder(depDir17), continue; end

    files = dir(fullfile(depDir17, '*_L2.mat'));
    files = files(~contains({files.name},'.bak'));
    for iF = 1:numel(files)
        label = regexprep(files(iF).name,'_L2\.mat$','');
        L2file_17 = fullfile(depDir17, [label '_L2.mat']);
        L2file_60 = fullfile(depDir60, [label '_L2.mat']);
        if ~isfile(L2file_17) || ~isfile(L2file_60), continue; end

        S17 = load(L2file_17); L17 = S17.L2;
        S60 = load(L2file_60); L60 = S60.L2;

        % Common-field fits at both segmentations
        [a17_u, b17_u, R17_u, N17_full] = fit_HsScale(L17, 'uMean', opts.HsMin, [opts.HsMin, inf]);
        [a60_u, b60_u, R60_u, N60_full] = fit_HsScale(L60, 'uMean', opts.HsMin, [opts.HsMin, inf]);
        [a17_v, b17_v, R17_v, ~]        = fit_HsScale(L17, 'vMean', opts.HsMin, [opts.HsMin, inf]);
        [a60_v, b60_v, R60_v, ~]        = fit_HsScale(L60, 'vMean', opts.HsMin, [opts.HsMin, inf]);
        [a17_uH, b17_uH, R17_uH, N17_uH] = fit_HsScale(L17, 'uMean', opts.HsHigh, [opts.HsHigh, inf]);
        [a60_uH, b60_uH, R60_uH, N60_uH] = fit_HsScale(L60, 'uMean', opts.HsHigh, [opts.HsHigh, inf]);

        if isnan(a17_u) || isnan(a60_u), continue; end

        valid17 = L17.segValid(:) & ~isnan(L17.depth(:));
        h_med = median(L17.depth(valid17));
        alpha_th = -g / (16 * sqrt(g*h_med) * h_med);

        results.deployment{end+1} = dep;
        results.label{end+1}      = label;
        results.h_med(end+1)      = h_med;
        results.alpha_u_17(end+1) = a17_u;  results.beta_u_17(end+1) = b17_u;  results.R2_u_17(end+1) = R17_u;  results.N_17(end+1)  = N17_full;
        results.alpha_u_60(end+1) = a60_u;  results.beta_u_60(end+1) = b60_u;  results.R2_u_60(end+1) = R60_u;  results.N_60(end+1)  = N60_full;
        results.alpha_v_17(end+1) = a17_v;  results.beta_v_17(end+1) = b17_v;  results.R2_v_17(end+1) = R17_v;
        results.alpha_v_60(end+1) = a60_v;  results.beta_v_60(end+1) = b60_v;  results.R2_v_60(end+1) = R60_v;
        results.alpha_uH_17(end+1) = a17_uH; results.beta_uH_17(end+1) = b17_uH; results.R2_uH_17(end+1) = R17_uH; results.N_uH_17(end+1) = N17_uH;
        results.alpha_uH_60(end+1) = a60_uH; results.beta_uH_60(end+1) = b60_uH; results.R2_uH_60(end+1) = R60_uH; results.N_uH_60(end+1) = N60_uH;
        results.alpha_th(end+1)   = alpha_th;
    end
end

save(fullfile(opts.aggDir,'robustness_summary.mat'),'results');
fprintf('Saved %d-instrument robustness summary to %s\n', numel(results.label), fullfile(opts.aggDir,'robustness_summary.mat'));

% Print key headlines
nI = numel(results.label);
au17 = results.alpha_u_17(:);  av17 = results.alpha_v_17(:);
au60 = results.alpha_u_60(:);  av60 = results.alpha_v_60(:);
auH17 = results.alpha_uH_17(:); auH60 = results.alpha_uH_60(:);
R2u17 = results.R2_u_17(:);    R2uH17 = results.R2_uH_17(:);
R2u60 = results.R2_u_60(:);    R2uH60 = results.R2_uH_60(:);

fprintf('\n=== Alongshore α check ===\n');
fprintf('  cross-shore α (17-min):  median = %+.4f m/s/m^2,   α<0 in %.0f%%\n', median(au17), 100*mean(au17<0));
fprintf('  alongshore  α (17-min):  median = %+.4f m/s/m^2,   α<0 in %.0f%%\n', median(av17), 100*mean(av17<0));
fprintf('  cross-shore α (1-hour):  median = %+.4f m/s/m^2,   α<0 in %.0f%%\n', median(au60), 100*mean(au60<0));
fprintf('  alongshore  α (1-hour):  median = %+.4f m/s/m^2,   α<0 in %.0f%%\n', median(av60), 100*mean(av60<0));
fprintf('  median |α_u|/|α_v| (17-min) = %.2f  (1-hour) = %.2f\n', median(abs(au17))/median(abs(av17)), median(abs(au60))/median(abs(av60)));

fprintf('\n=== High-H_s-only fit (H_s ≥ %.1f m, cross-shore u) ===\n', opts.HsHigh);
ok17 = ~isnan(R2uH17); ok60 = ~isnan(R2uH60);
fprintf('  17-min:  median R² (full) = %.3f → median R² (H_s≥1) = %.3f  (improvement factor %.1fx)\n', ...
    median(R2u17(ok17)), median(R2uH17(ok17)), median(R2uH17(ok17))/median(R2u17(ok17)));
fprintf('  1-hour:  median R² (full) = %.3f → median R² (H_s≥1) = %.3f  (improvement factor %.1fx)\n', ...
    median(R2u60(ok60)), median(R2uH60(ok60)), median(R2uH60(ok60))/median(R2u60(ok60)));
fprintf('  17-min α<0 in (full) %.0f%% vs (H_s≥1) %.0f%%\n', 100*mean(au17(ok17)<0), 100*mean(auH17(ok17)<0));
fprintf('  1-hour α<0 in (full) %.0f%% vs (H_s≥1) %.0f%%\n', 100*mean(au60(ok60)<0), 100*mean(auH60(ok60)<0));

% ============== Build figure ==============
fig = figure('Visible','off','Position',[100 100 1500 950]);

% Panel 1: alongshore α vs cross-shore α (17-min)
subplot(2,2,1); hold on;
lim = max([abs(au17); abs(av17)])*1.1;
plot([-lim lim],[0 0],'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-lim lim],'k-','LineWidth',0.5,'HandleVisibility','off');
[siteCol, siteName] = get_site_info(results);
sites = unique(siteName);
for st = sites'
    pick = (siteName == st);
    if any(pick)
        scatter(au17(pick), av17(pick), 70, siteCol(pick,:), 'filled', 'MarkerEdgeColor','k','DisplayName',char(st));
    end
end
xlabel('\alpha cross-shore  (m/s per m^2)');
ylabel('\alpha alongshore  (m/s per m^2)');
title(sprintf('17-min: cross-shore vs alongshore \\alpha   (med |\\alpha_u|/|\\alpha_v| = %.2f)', ...
    median(abs(au17))/median(abs(av17))));
xlim([-lim lim]); ylim([-lim lim]); grid on; axis square;
legend('Location','best','FontSize',8);

% Panel 2: alongshore α vs cross-shore α (1-hour)
subplot(2,2,2); hold on;
lim = max([abs(au60); abs(av60)])*1.1;
plot([-lim lim],[0 0],'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-lim lim],'k-','LineWidth',0.5,'HandleVisibility','off');
for st = sites'
    pick = (siteName == st);
    if any(pick)
        scatter(au60(pick), av60(pick), 70, siteCol(pick,:), 'filled', 'MarkerEdgeColor','k','HandleVisibility','off');
    end
end
xlabel('\alpha cross-shore  (m/s per m^2)');
ylabel('\alpha alongshore  (m/s per m^2)');
title(sprintf('1-hour: cross-shore vs alongshore \\alpha   (med |\\alpha_u|/|\\alpha_v| = %.2f)', ...
    median(abs(au60))/median(abs(av60))));
xlim([-lim lim]); ylim([-lim lim]); grid on; axis square;

% Panel 3: R² full-range vs R² H_s ≥ 1 m (1-hour cross-shore)
subplot(2,2,3); hold on;
plot([0 1],[0 1],'k:','LineWidth',1.0,'HandleVisibility','off');
for st = sites'
    pick = (siteName == st);
    if any(pick)
        scatter(R2u60(pick), R2uH60(pick), 70, siteCol(pick,:), 'filled', 'MarkerEdgeColor','k','HandleVisibility','off');
    end
end
xlabel('R^2 full H_s range');
ylabel(sprintf('R^2  (H_s \\geq %.1f m only)', opts.HsHigh));
nUp = sum(R2uH60 > R2u60);
title(sprintf('1-hour: R^2 jumps when restricted to H_s\\geq%.1f m  (improves in %d/%d)', opts.HsHigh, nUp, sum(~isnan(R2uH60))));
xlim([0 max([R2u60;R2uH60;0.3])*1.1]); ylim([0 max([R2u60;R2uH60;0.3])*1.1]); grid on; axis square;

% Panel 4: high-H_s α with theory line
subplot(2,2,4); hold on;
hPlot = linspace(2,16,200);
ath = -g ./ (16 * sqrt(g*hPlot) .* hPlot);
plot(hPlot, ath, 'k-', 'LineWidth', 1.4, 'DisplayName','Stokes theory');
yline(0,'k:','HandleVisibility','off');
for st = sites'
    pick = (siteName == st) & ~isnan(auH60);
    if any(pick)
        scatter(results.h_med(pick), auH60(pick), 70, siteCol(pick,:), 'filled', 'MarkerEdgeColor','k','DisplayName',char(st));
    end
end
xlabel('h_{med}  (m)');
ylabel(sprintf('\\alpha (1-hour, H_s \\geq %.1f m only)', opts.HsHigh));
nNeg = sum(auH60 < 0); nTot = sum(~isnan(auH60));
title(sprintf('High-H_s \\alpha vs depth (1-hour):  \\alpha<0 in %d/%d, median \\alpha/\\alpha_{th} = %+.2f', ...
    nNeg, nTot, median(auH60(~isnan(auH60)) ./ results.alpha_th(~isnan(auH60))')));
ylim([-0.05 0.05]);
grid on;
legend('Location','best','FontSize',8);

outFig = fullfile(opts.aggDir, 'robustness_alongshore_and_highHs.png');
exportgraphics(fig, outFig, 'Resolution', 200);
close(fig);
fprintf('\nFigure: %s\n', outFig);
end


function [a, b, R2, N] = fit_HsScale(L2, field, HsMinFit, HsRange)
% Fit u = a·Hs² + b on segments with Hs in HsRange and segValid true.
a = NaN; b = NaN; R2 = NaN; N = 0;
if ~isfield(L2, field), return; end
val = L2.(field)(:);
Hs  = L2.Hs(:);
keep = L2.segValid(:) & ~isnan(val) & ~isnan(Hs) & Hs >= HsRange(1) & Hs < HsRange(2);
if sum(keep) < 30, return; end
Hs = Hs(keep); val = val(keep);
X = [Hs.^2, ones(size(Hs))];
b_ols = X \ val;
yhat = X * b_ols;
R2 = 1 - sum((val - yhat).^2) / sum((val - mean(val)).^2);
a = b_ols(1); b = b_ols(2); N = sum(keep);
end


function [siteCol, siteName] = get_site_info(results)
n = numel(results.label);
siteName = strings(n,1);
siteCol = zeros(n,3);
colors = struct('Torrey',[0.20 0.45 0.85],'Solana',[0.85 0.30 0.20], ...
                'SIO_Pier',[0.95 0.65 0.10],'LPL_lagoon',[0.30 0.65 0.30], ...
                'Catalina',[0.55 0.40 0.75], 'Imperial_Beach',[0.10 0.65 0.65], ...
                'other',[0.5 0.5 0.5]);
for k = 1:n
    d = results.deployment{k};
    if startsWith(d,'TBR')||startsWith(d,'TOR') || startsWith(d,'RUBY'), siteName(k) = "Torrey";       siteCol(k,:) = colors.Torrey;
    elseif startsWith(d,'SOL'),                  siteName(k) = "Solana";       siteCol(k,:) = colors.Solana;
    elseif startsWith(d,'SIO'),                  siteName(k) = "SIO Pier";     siteCol(k,:) = colors.SIO_Pier;
    elseif startsWith(d,'LPL'),                  siteName(k) = "LPL lagoon";   siteCol(k,:) = colors.LPL_lagoon;
    elseif startsWith(d,'CAT'),                  siteName(k) = "Catalina";     siteCol(k,:) = colors.Catalina;
    elseif startsWith(d,'IB'),                   siteName(k) = "Imperial Beach"; siteCol(k,:) = colors.Imperial_Beach;
    else,                                        siteName(k) = "other";        siteCol(k,:) = colors.other;
    end
end
end
