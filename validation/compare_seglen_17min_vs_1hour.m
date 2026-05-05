function cmp = compare_seglen_17min_vs_1hour(deployment, label, opts)
% COMPARE_SEGLEN_17MIN_VS_1HOUR  Head-to-head of 17-min vs 1-hour L2.
%
%   cmp = compare_seglen_17min_vs_1hour('TBR23', 'MOP586_5m')
%
% For each 1-hour L2 timestamp, gathers the 17-min L2 segments within
% +/-30 min of that hour and rolls them up using physically-correct
% averaging (energy averaging for Hs and band energies; spectral-moment
% averaging for Tm02; circular mean for direction). Then compares
% bulk parameters and spectra at the matched times.
%
% INPUTS
%   deployment - 'TBR23'
%   label      - 'MOP586_5m' or 'MOP586_7m'
%   opts.L2dir       - default outputs/L2
%   opts.L2hourlyDir - default outputs/L2_hourly
%   opts.figDir      - default outputs/validation/seglen_compare
%   opts.matchTolMin - max +/- minutes from hour center (default 30)
%   opts.minMatch    - min 17-min segs per hour for valid match (default 3)
%   opts.spectraHours- char vec or datetime array of times for spectral
%                      overlay panels (default: auto-pick 4 representative)
%
% OUTPUTS
%   cmp - struct with matched arrays and stats
%   Figures: bulk scatter, timeseries, spectral overlay panels, band energies
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),       opts.L2dir       = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts, 'L2hourlyDir'), opts.L2hourlyDir = fullfile(pipelineRoot,'outputs','L2_hourly'); end
if ~isfield(opts, 'figDir'),      opts.figDir      = fullfile(pipelineRoot,'outputs','validation','seglen_compare'); end
if ~isfield(opts, 'matchTolMin'), opts.matchTolMin = 30; end
if ~isfield(opts, 'minMatch'),    opts.minMatch    = 3;  end

figDirOut = fullfile(opts.figDir, deployment, label);
if ~exist(figDirOut, 'dir'), mkdir(figDirOut); end

S17 = load(fullfile(opts.L2dir,       deployment, [label '_L2.mat']));  L17 = S17.L2;
S60 = load(fullfile(opts.L2hourlyDir, deployment, [label '_L2.mat']));  L60 = S60.L2;

fprintf('\n=== %s / %s ===\n', deployment, label);
fprintf('  17-min: nf=%d, df=%.5f Hz, %d valid segments\n', ...
    numel(L17.f), L17.f(2)-L17.f(1), sum(L17.segValid));
fprintf('  1-hour: nf=%d, df=%.5f Hz, %d valid segments\n', ...
    numel(L60.f), L60.f(2)-L60.f(1), sum(L60.segValid));

% ---- Match each valid 1-hour segment with 17-min neighbors ----
v60 = find(L60.segValid(:) & ~isnan(L60.Hs(:)));
v17 = find(L17.segValid(:) & ~isnan(L17.Hs(:)));
t60 = L60.time(v60);
t17 = L17.time(v17);

tolMin = opts.matchTolMin;
N = numel(v60);

% Pre-allocate matched fields
m = struct();
m.time      = t60;
m.Hs60      = L60.Hs(v60);
m.Hs17_lin  = nan(N,1);    m.Hs17_eng = nan(N,1);
m.HsSS60    = L60.Hs_SS(v60);  m.HsSS17 = nan(N,1);
m.HsIG60    = L60.Hs_IG(v60);  m.HsIG17 = nan(N,1);
m.Tp60      = L60.Tp(v60);     m.Tp17   = nan(N,1);
m.Tm0260    = L60.Tm02(v60);   m.Tm0217 = nan(N,1);
m.dir60     = L60.meanDir(v60); m.dir17 = nan(N,1);
m.Ef60      = L60.Ef(v60);      m.Ef17  = nan(N,1);
m.depth60   = L60.depth(v60);   m.depth17 = nan(N,1);
m.Sk60      = L60.vmom.skewness(v60);  m.Sk17 = nan(N,1);
m.As60      = L60.vmom.asymmetry(v60); m.As17 = nan(N,1);
m.uMean60   = L60.uMean(v60);          m.uMean17 = nan(N,1);
m.vMean60   = L60.vMean(v60);          m.vMean17 = nan(N,1);
m.nMatch    = zeros(N,1);

% Spectral roll-up: average 17-min spectra in time, keep on 17-min freq grid
nf17 = numel(L17.f);
m.S_eta_17_avg = nan(nf17, N);
m.S_eta_60     = L60.S_eta(:, v60);  % already on 1-hour grid
m.f17 = L17.f;
m.f60 = L60.f;

for i = 1:N
    dtMin = abs(minutes(t17 - t60(i)));
    in = dtMin <= tolMin;
    if sum(in) < opts.minMatch, continue; end

    idx = v17(in);
    m.nMatch(i) = numel(idx);

    Hs_arr   = L17.Hs(idx);
    HsSS_arr = L17.Hs_SS(idx);
    HsIG_arr = L17.Hs_IG(idx);
    Tp_arr   = L17.Tp(idx);
    Tm_arr   = L17.Tm02(idx);
    Ef_arr   = L17.Ef(idx);
    dir_arr  = L17.meanDir(idx);
    d_arr    = L17.depth(idx);
    Sk_arr   = L17.vmom.skewness(idx);
    As_arr   = L17.vmom.asymmetry(idx);
    uM_arr   = L17.uMean(idx);
    vM_arr   = L17.vMean(idx);

    m.Hs17_lin(i) = mean(Hs_arr, 'omitnan');
    m.Hs17_eng(i) = sqrt(mean(Hs_arr.^2, 'omitnan'));
    m.HsSS17(i)   = sqrt(mean(HsSS_arr.^2, 'omitnan'));
    m.HsIG17(i)   = sqrt(mean(HsIG_arr.^2, 'omitnan'));
    m.Tp17(i)     = median(Tp_arr, 'omitnan');     % Tp is jumpy — median is more robust
    m.Tm0217(i)   = mean(Tm_arr, 'omitnan');       % full-spectrum moment, linear avg OK
    m.Ef17(i)     = mean(Ef_arr, 'omitnan');       % linear avg of energy fluxes
    m.depth17(i)  = mean(d_arr, 'omitnan');
    m.Sk17(i)     = mean(Sk_arr, 'omitnan');
    m.As17(i)     = mean(As_arr, 'omitnan');
    m.uMean17(i)  = mean(uM_arr, 'omitnan');
    m.vMean17(i)  = mean(vM_arr, 'omitnan');

    % Hs^2-weighted circular mean direction
    th = deg2rad(dir_arr);
    w  = Hs_arr.^2;
    good = ~isnan(th) & ~isnan(w);
    if any(good)
        C = sum(w(good) .* cos(th(good)));
        Sn = sum(w(good) .* sin(th(good)));
        m.dir17(i) = mod(rad2deg(atan2(Sn, C)), 360);
    end

    % Average 17-min spectra in time
    Spec = L17.S_eta(:, idx);
    m.S_eta_17_avg(:, i) = mean(Spec, 2, 'omitnan');
end

ok = m.nMatch >= opts.minMatch;
fprintf('  Matched %d / %d hourly segments to >= %d 17-min neighbors\n', ...
    sum(ok), N, opts.minMatch);

% ---- Stats ----
varList = {
    'Hs',     m.Hs17_eng,  m.Hs60,    'm',   'H_s'
    'Hs_SS',  m.HsSS17,    m.HsSS60,  'm',   'H_{s,SS}'
    'Hs_IG',  m.HsIG17,    m.HsIG60,  'm',   'H_{s,IG}'
    'Tp',     m.Tp17,      m.Tp60,    's',   'T_p'
    'Tm02',   m.Tm0217,    m.Tm0260,  's',   'T_{m02}'
    'Ef',     m.Ef17,      m.Ef60,    'W/m', 'E_f'
    'depth',  m.depth17,   m.depth60, 'm',   'h'
    'Sk',     m.Sk17,      m.Sk60,    '-',   'Sk'
    'As',     m.As17,      m.As60,    '-',   'As'
    'uMean',  m.uMean17,   m.uMean60, 'm/s', 'uMean (X-sh)'
    'vMean',  m.vMean17,   m.vMean60, 'm/s', 'vMean (alongsh)'
};

fprintf('\n  Variable      bias (60-17)   RMSE      R^2     slope    N\n');
fprintf('  ----------    -----------    -------   -----   ------   ----\n');
stats = struct();
for v = 1:size(varList,1)
    nm  = varList{v,1};  x17 = varList{v,2};  x60 = varList{v,3};
    units = varList{v,4};
    g = ok & ~isnan(x17) & ~isnan(x60);
    if sum(g) < 5, continue; end
    bias = mean(x60(g) - x17(g));
    rmse = sqrt(mean((x60(g) - x17(g)).^2));
    R = corrcoef(x17(g), x60(g));
    slope = (x17(g) - mean(x17(g))) \ (x60(g) - mean(x60(g)));
    fprintf('  %-12s  %+9.4f %s   %7.4f   %5.3f   %5.3f   %4d\n', ...
        varList{v,5}, bias, units, rmse, R(1,2)^2, slope, sum(g));
    stats.(nm) = struct('bias',bias,'rmse',rmse,'R2',R(1,2)^2,'slope',slope,'N',sum(g));
end
% Hs linear-vs-energy roll-up
g = ok & ~isnan(m.Hs17_lin) & ~isnan(m.Hs17_eng);
fprintf('\n  Hs roll-up bias (energy - linear) on 17-min: median = %+.4f m\n', ...
    median(m.Hs17_eng(g) - m.Hs17_lin(g)));

cmp.match = m;
cmp.stats = stats;
cmp.label = label;
cmp.deployment = deployment;

% ============================== FIGURES ==============================
% Scatter grid
f1 = figure('Visible','off','Position',[100 100 1500 1000]);
for v = 1:size(varList,1)
    subplot(3,4,v);
    nm = varList{v,5}; x17 = varList{v,2}; x60 = varList{v,3};
    g = ok & ~isnan(x17) & ~isnan(x60);
    scatter(x17(g), x60(g), 8, 'filled', 'MarkerFaceAlpha', 0.3); hold on;
    lim = [min([x17(g);x60(g)]) max([x17(g);x60(g)])];
    plot(lim, lim, 'k:'); axis equal tight;
    xlabel(sprintf('17-min L2, averaged to hourly [%s]', varList{v,4}));
    ylabel(sprintf('1-hour L2 [%s]', varList{v,4}));
    title(nm);
    grid on;
    if isfield(stats, varList{v,1})
        st = stats.(varList{v,1});
        text(0.05, 0.95, sprintf('R^2=%.3f\nbias=%+.3f\nN=%d', st.R2, st.bias, st.N), ...
            'Units','normalized','VerticalAlignment','top','FontSize',8, ...
            'BackgroundColor','w','EdgeColor','k');
    end
end
sgtitle(sprintf('%s — bulk params: 17-min L2 (hourly avg) vs 1-hour L2', tex_label(label)));
saveas(f1, fullfile(figDirOut, 'bulk_scatter.png'));
close(f1);

% Timeseries overlay (Hs, Tp, uMean, Sk, As)
f2 = figure('Visible','off','Position',[100 100 1300 1100]);
panels = {'H_s (m)',          m.Hs17_eng, m.Hs60;
          'T_p (s)',           m.Tp17,     m.Tp60;
          'uMean X-sh (m/s)',  m.uMean17,  m.uMean60;
          'Sk',                m.Sk17,     m.Sk60;
          'As',                m.As17,     m.As60};
nP = size(panels,1);
for k = 1:nP
    subplot(nP,1,k);
    plot(m.time(ok), panels{k,2}(ok), 'b-', 'LineWidth', 0.6); hold on;
    plot(m.time(ok), panels{k,3}(ok), 'r-', 'LineWidth', 0.6);
    ylabel(panels{k,1}); grid on;
    if strcmp(panels{k,1}, 'uMean X-sh (m/s)'), yline(0, 'k:'); end
    if k==1, legend('17-min L2 (hourly avg)','1-hour L2','Location','best'); end
end
xlabel('time');
sgtitle(sprintf('%s — timeseries overlay', tex_label(label)));
saveas(f2, fullfile(figDirOut, 'timeseries.png'));
close(f2);

% Spectral overlay at 4 representative hours
% Pick: lowest Hs, highest Hs, peak rising tide, peak falling tide
Hs60 = m.Hs60;
[~, iLow]  = min(Hs60(ok));    iLow  = find(ok,1) + iLow - 1;
[~, iHigh] = max(Hs60(ok));    iHigh = find(ok,1) + iHigh - 1;
% Tide rate: |dh/dt| from depth60 differences
dhdt = [nan; abs(diff(m.depth60))];
[~, iFlood] = max(dhdt .* ok);
% Pick a "typical" mid hour
midIdx = find(ok);
iMid = midIdx(round(numel(midIdx)/2));
picks = unique([iLow iHigh iFlood iMid]);
picks = picks(picks>0 & picks<=N);
nP = numel(picks);

f3 = figure('Visible','off','Position',[100 100 1200 250*nP]);
for p = 1:nP
    i = picks(p);
    subplot(nP,1,p);
    loglog(m.f17, m.S_eta_17_avg(:,i), 'b-', 'LineWidth', 1.0); hold on;
    loglog(m.f60, m.S_eta_60(:,i),     'r-', 'LineWidth', 1.0);
    xlim([0.003 0.5]);
    xlabel('frequency (Hz)'); ylabel('S_{\eta\eta} (m^2/Hz)');
    title(sprintf('%s    H_s = %.2f m   h = %.2f m   |dh/dt| = %.2f m/hr', ...
        datestr(m.time(i),'yyyy-mm-dd HH:MM'), m.Hs60(i), m.depth60(i), ...
        ifelse(isnan(dhdt(i)), 0, dhdt(i))));
    grid on;
    if p==1, legend('17-min L2 (avg in hour)','1-hour L2','Location','southwest'); end
    xline(0.04,'k:'); xline(0.25,'k:');  % SS band markers
end
sgtitle(sprintf('%s — surface elevation spectra', tex_label(label)));
saveas(f3, fullfile(figDirOut, 'spectra_overlay.png'));
close(f3);

fprintf('  Figures saved to %s\n', figDirOut);
end


function y = ifelse(cond, a, b)
if cond, y = a; else, y = b; end
end
