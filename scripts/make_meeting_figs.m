% MAKE_MEETING_FIGS  Generate simple, one-thing-per-figure plots for the
% TBR23 / cross-site walkthrough. Matches the style of Bill's MOP511 PDF —
% matter-of-fact captions, default colours, minimal styling.
% Author: Holden Leslie-Bole, 2026

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

outDir = 'docs/meeting_walkthrough/figures';
if ~exist(outDir,'dir'), mkdir(outDir); end

instruments = {'MOP580_5m','MOP586_5m','MOP580_7m','MOP586_7m'};
labels      = {'MOP580 5m','MOP586 5m','MOP580 7m','MOP586 7m'};
colors      = lines(4);

%% Load all 4 L1, L2, L3 records
L1 = cell(4,1); L2 = cell(4,1); L3 = cell(4,1);
for k = 1:4
    L1{k} = load(['outputs/L1/TBR23/' instruments{k} '_processed.mat']).PUV;
    L2{k} = load(['outputs/L2/TBR23/' instruments{k} '_L2.mat']).L2;
    L3{k} = load(['outputs/L3/TBR23/' instruments{k} '_L3.mat']).L3;
end

%% --- Fig 1: raw L1 timeseries for one instrument (MOP586_7m) ---
PUV = L1{4};
fs = PUV.fs;
% Subsample to 1-min for plotting (otherwise too dense)
step = max(1, round(60*fs));
idx = 1:step:numel(PUV.time);
t = PUV.time(idx);

figure('Visible','off','Position',[100 100 900 600]);
subplot(4,1,1)
plot(t, PUV.P(idx), 'k-'); grid on
ylabel('P (dBar)'); title('TBR23 / MOP586 7m — raw L1 record (1-min subsample)');

subplot(4,1,2)
plot(t, PUV.BuoyCoord.U(idx), 'b-'); grid on
ylabel('U (m/s)');

subplot(4,1,3)
plot(t, PUV.BuoyCoord.V(idx), 'r-'); grid on
ylabel('V (m/s)');

subplot(4,1,4)
plot(t, PUV.BuoyCoord.W(idx), 'g-'); grid on
ylabel('W (m/s)'); xlabel('Date');

exportgraphics(gcf, fullfile(outDir,'fig01_L1_timeseries.png'), 'Resolution', 150);
close

%% --- Fig 2: L2 Hs across all 4 PUVs ---
figure('Visible','off','Position',[100 100 900 400]);
hold on
for k = 1:4
    L2k = L2{k};
    v = L2k.segValid;
    plot(L2k.time(v), L2k.Hs(v), '.', 'Color', colors(k,:), 'MarkerSize',4);
end
grid on
xlabel('Date'); ylabel('H_s (m)');
title('TBR23 — hourly H_s, all 4 PUVs');
legend(labels,'Location','best');
exportgraphics(gcf, fullfile(outDir,'fig02_L2_Hs_timeseries.png'), 'Resolution', 150);
close

%% --- Fig 3: pressure energy density spectrogram for MOP586_7m ---
% Mirror Bill's Fig 4: log10(Spp) vs (record number, frequency)
L2k = L2{4};
v = L2k.segValid;
Spp = L2k.Spp(:, v);
f = L2k.f;
fMask = f > 0 & f <= 0.3;

figure('Visible','off','Position',[100 100 900 500]);
imagesc(1:sum(v), f(fMask), log10(Spp(fMask,:)));
set(gca,'YDir','normal','CLim',[-7 6]);
colorbar; colormap(jet)
xlabel('Hourly record number'); ylabel('Frequency (Hz)');
title('TBR23 / MOP586 7m — log_{10} pressure energy density (m^2/Hz)');
exportgraphics(gcf, fullfile(outDir,'fig03_L2_pressure_spectra.png'), 'Resolution', 150);
close

%% --- Fig 4: L2 hourly uMean for all 4 PUVs ---
figure('Visible','off','Position',[100 100 900 400]);
hold on
for k = 1:4
    L2k = L2{k};
    v = L2k.segValid;
    plot(L2k.time(v), L2k.uMean(v), '.', 'Color', colors(k,:), 'MarkerSize',4);
end
grid on; yline(0,'k:');
xlabel('Date'); ylabel('uMean (m/s)');
title('TBR23 — hourly cross-shore mean velocity, all 4 PUVs');
legend(labels,'Location','best');
exportgraphics(gcf, fullfile(outDir,'fig04_L2_uMean_timeseries.png'), 'Resolution', 150);
close

%% --- Fig 5: uMean vs Hs^2 for MOP586_7m with Stokes line ---
L2k = L2{4};
v = L2k.segValid;
Hs = L2k.Hs(v);
uM = L2k.uMean(v);
h_med = median(L2k.depth(v),'omitnan');
g = 9.81; c = sqrt(g*h_med);
alpha_th = -g/(16*c*h_med);

figure('Visible','off','Position',[100 100 700 500]);
scatter(Hs.^2, uM, 8, 'filled', 'MarkerFaceAlpha',0.2); hold on;
xPlot = linspace(0, max(Hs)^2, 50);
plot(xPlot, alpha_th * xPlot, 'r-', 'LineWidth', 1.5);
yline(0,'k:'); grid on;
xlabel('H_s^2 (m^2)'); ylabel('uMean (m/s)');
title(sprintf('TBR23 / MOP586 7m — uMean vs H_s^2 (h_{med}=%.1f m, \\alpha_{th}=%.4f)', h_med, alpha_th));
legend({'Hourly segments', sprintf('Stokes return-flow theory \\alpha = %+.4f', alpha_th)}, 'Location','best');
exportgraphics(gcf, fullfile(outDir,'fig05_L2_uMean_vs_Hs2.png'), 'Resolution', 150);
close

%% --- Fig 6: U skewness time series ---
figure('Visible','off','Position',[100 100 900 400]);
hold on
for k = 1:4
    L2k = L2{k};
    v = L2k.segValid;
    plot(L2k.time(v), L2k.vmom.skewness(v), '.', 'Color', colors(k,:), 'MarkerSize',4);
end
yline(0,'k:'); grid on;
xlabel('Date'); ylabel('U skewness');
title('TBR23 — hourly cross-shore velocity skewness, all 4 PUVs');
legend(labels,'Location','best');
exportgraphics(gcf, fullfile(outDir,'fig06_L2_Uskew_timeseries.png'), 'Resolution', 150);
close

%% --- Fig 7: Skewness vs Ursell number, all 4 PUVs ---
all_Ur = []; all_Sk = []; all_inst = [];
for k = 1:4
    L2k = L2{k};
    v = L2k.segValid & ~isnan(L2k.Hs(:)) & ~isnan(L2k.Tp(:)) & ~isnan(L2k.depth(:));
    Hs = L2k.Hs(v); Tp = L2k.Tp(v); h = L2k.depth(v);
    a = Hs/2;
    omega = 2*pi./Tp;
    k_w = omega.^2 / 9.81;  % deep-water guess
    for ii = 1:5
        k_w = omega.^2 ./ (9.81 * tanh(k_w .* h));
    end
    Ur = (3/4) * a .* k_w ./ (k_w .* h).^3;
    all_Ur = [all_Ur; Ur];
    all_Sk = [all_Sk; L2k.vmom.skewness(v)];
    all_inst = [all_inst; k*ones(sum(v),1)];
end

% Ruessink 2012: Sk = B*cos(psi); B = p1 + (p2-p1)/(1+exp((p3-log10(Ur))/p4));
% psi = -pi/2 + (pi/2)*tanh(p5 / Ur^p6).  p1=0, p2=0.857, p3=-0.471,
% p4=0.297, p5=0.815, p6=0.672 (Ruessink et al. 2012, Coastal Eng).
B   = 0.857 ./ (1 + exp((-0.471 - log10(all_Ur)) ./ 0.297));
psi = -pi/2 + (pi/2) .* tanh(0.815 ./ all_Ur.^0.672);
Sk_R = B .* cos(psi);

figure('Visible','off','Position',[100 100 700 500]);
hold on
for k = 1:4
    msk = all_inst == k;
    scatter(log10(all_Ur(msk)), all_Sk(msk), 8, colors(k,:), 'filled', 'MarkerFaceAlpha',0.25);
end
[~, srt] = sort(all_Ur);
plot(log10(all_Ur(srt)), Sk_R(srt), 'k-', 'LineWidth', 1.5);
yline(0,'k:'); grid on;
ylim([-1 1])
xlabel('log_{10}(Ursell number)'); ylabel('U skewness');
title('TBR23 — U skewness vs Ursell number, with Ruessink (2012)');
legend([labels {'Ruessink 2012'}], 'Location','best');
exportgraphics(gcf, fullfile(outDir,'fig07_L3_Uskew_vs_Ursell.png'), 'Resolution', 150);
close

%% --- Fig 8: Time-median Bailard moments by site, two clean bars ---
% Use medians (not means) — the cubic terms blow up under storm-tail
% outliers. Categorical x-axis so bars are clearly visible.
inst_h      = NaN(4,1);
med_skew    = NaN(4,1);
med_under   = NaN(4,1);
for k = 1:4
    L2k = L2{k};
    v = L2k.segValid;
    inst_h(k)    = median(L2k.depth(v),'omitnan');
    med_skew(k)  = median(L2k.vmom.u_uabs2(v), 'omitnan');
    med_under(k) = median(L2k.uMean(v) .* (L2k.Ub(v).^2), 'omitnan');
end
% Sort by depth
[~, srt] = sort(inst_h);
labels_sort = labels(srt);
med_skew    = med_skew(srt);
med_under   = med_under(srt);
inst_h_sort = inst_h(srt);

% Build x-axis labels with depth
xLabs = cell(4,1);
for k = 1:4
    xLabs{k} = sprintf('%s\n(h=%.1fm)', labels_sort{k}, inst_h_sort(k));
end

figure('Visible','off','Position',[100 100 800 500]);
B = bar(categorical(xLabs, xLabs), [med_skew, med_under], 0.7, 'grouped');
B(1).FaceColor = [0.85 0.40 0.10];
B(2).FaceColor = [0.20 0.45 0.85];
yline(0,'k:'); grid on;
ylabel('Median Bailard moment (m^3/s^3)');
title('TBR23 — onshore (skewness) vs offshore (undertow) Bailard moments per instrument');
legend({'Skewness term \langle u|u|^2 \rangle  (onshore +)', ...
        'Undertow term \langle u \rangle \langle |u|^2 \rangle  (offshore -)'}, ...
       'Location','best');
exportgraphics(gcf, fullfile(outDir,'fig08_L3_transport_components.png'), 'Resolution', 150);
close

%% --- Fig 9: Tidal modulation of uMean for MOP586_7m ---
L2k = L2{4};
v = L2k.segValid;
% Use depth as a tidal-phase proxy: rank segments by depth-residual (depth minus
% deployment-mean depth)
depth = L2k.depth(v);
uM = L2k.uMean(v);
Hs = L2k.Hs(v);
dep_resid = depth - median(depth, 'omitnan');

% Stratify by Hs
HsBins = [0 0.5 1.0 2.0];
HsLab = {'Hs<0.5','0.5-1','1-2','Hs>2'};

figure('Visible','off','Position',[100 100 800 500]);
hold on
nbins = 12;
edges = linspace(min(dep_resid), max(dep_resid), nbins+1);
ctrs = 0.5*(edges(1:end-1)+edges(2:end));
plotcolors = [0.2 0.6 0.9; 0.2 0.5 0.4; 0.85 0.55 0.1; 0.8 0.2 0.2];
for j = 1:4
    if j == 4
        msk = Hs >= HsBins(end);
    else
        msk = Hs >= HsBins(j) & Hs < HsBins(j+1);
    end
    if sum(msk) < 20, continue; end
    binMean = NaN(nbins,1);
    for b = 1:nbins
        bMsk = msk & dep_resid >= edges(b) & dep_resid < edges(b+1);
        if sum(bMsk) >= 3
            binMean(b) = mean(uM(bMsk),'omitnan');
        end
    end
    plot(ctrs, binMean, 'o-', 'Color', plotcolors(j,:), 'LineWidth', 1.5, ...
        'MarkerFaceColor', plotcolors(j,:), 'DisplayName', HsLab{j});
end
yline(0,'k:'); grid on;
xlabel('Depth residual (m, positive = high tide)'); ylabel('Mean uMean in bin (m/s)');
title('TBR23 / MOP586 7m — tidal modulation of uMean, stratified by H_s');
legend('Location','best');
exportgraphics(gcf, fullfile(outDir,'fig09_L3_tidal_modulation.png'), 'Resolution', 150);
close

%% --- Done ---
fprintf('All figures written to %s\n', outDir);
