% compare_ruby2d.m
% Author: Holden Leslie-Bole, 2026
% Compare our pipeline (multi-taper) against the legacy archived L2
% for Ruby2D MOP582_6m. Bulk parameters + representative spectrum.
%
% Three effects expected to fall out of this comparison:
%   (1) window mismatch in the legacy code (Hanning auto / Hamming cross)
%   (2) spectral estimator: full multi-taper vs single-periodogram
%   (3) Kp pressure correction floor: zero (ours) vs cap-at-10 (legacy)

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

%% Load
fprintf('Loading our L2...\n');
ours = load('outputs/L2/Ruby2D/Ruby2D_582_6m_L2.mat', 'L2');
L2   = ours.L2;

fprintf('Loading legacy bulk extract...\n');
A    = load('raw_cache/Ruby2D/legacy_bulk_582_6m.mat');
leg  = A.legacy;
rep  = A.rep;
high = A.high;

% Legacy segments are 60 min long, time = first sample. Convert to midpoint.
leg_mid = leg.time + minutes(30);

% Our segments are 17 min, time = midpoint already.
ourValid = L2.segValid;
our_t   = L2.time(ourValid);
our_Hs  = L2.Hs(ourValid);
our_Tp  = L2.Tp(ourValid);
our_dir = L2.meanDir(ourValid);
our_zSS = L2.ztest_SS(ourValid);

% Bulk spread on the fly: energy-weighted Kuik bandwidth from a1, b1
S_eta = L2.S_eta(:, ourValid);
a1    = L2.a1(:, ourValid);
b1    = L2.b1(:, ourValid);
f     = L2.f;
fSS   = L2.params.fSS;
iSS   = f >= fSS(1) & f <= fSS(2);

E     = S_eta(iSS, :);
a1ss  = a1(iSS, :);
b1ss  = b1(iSS, :);
Esum  = sum(E, 1);                          % [1 x nSeg]
a1bar = sum(a1ss .* E, 1) ./ Esum;
b1bar = sum(b1ss .* E, 1) ./ Esum;
% Kuik et al. (1988) circular spread:
%   sigma = sqrt( 2*(1 - sqrt(a1^2+b1^2)) )  [radians]
m1mag = sqrt(a1bar.^2 + b1bar.^2);
m1mag = min(m1mag, 1);                       % numerical safety
our_spr = sqrt(2 * (1 - m1mag)) * (180/pi); % degrees
our_spr = our_spr(:);

%% Match legacy -> ours by nearest midpoint, ±30 min tolerance
fprintf('\nMatching segments...\n');
N = numel(leg_mid);
idx = nan(N, 1);
for k = 1:N
    if isnat(leg_mid(k)), continue; end
    [dt, j] = min(abs(our_t - leg_mid(k)));
    if dt <= minutes(30)
        idx(k) = j;
    end
end
matched = ~isnan(idx);
nMatch  = sum(matched);
fprintf('  Matched %d / %d legacy segments (%.0f%%)\n', ...
    nMatch, N, 100*nMatch/N);

jl = find(matched);
jo = idx(matched);

% Paired arrays (legacy, ours)
Hs_l = leg.Hs(jl);        Hs_o = our_Hs(jo);
Tp_l = leg.Tp(jl);        Tp_o = our_Tp(jo);
Tm_l = leg.Tm(jl);                                    % centroid period (legacy)
Dp_l = leg.dir1(jl);      Dp_o = our_dir(jo);
Sp_l = leg.spread1(jl);   Sp_o = our_spr(jo);
zS_l = leg.ztest_ss(jl);  zS_o = our_zSS(jo);

% The legacy peak picker is not band-limited: a handful of segments
% report Tp at the IG/DC bin (Tp up to 3600 s). For Tp stats only,
% mask any segment where either side is outside the SS band.
TpMin = 1/0.25;   % 4 s   (upper SS-band frequency)
TpMax = 1/0.04;   % 25 s
tpOK  = (Tp_l >= TpMin & Tp_l <= TpMax) & ...
        (Tp_o >= TpMin & Tp_o <= TpMax);
nTpOut = sum(~tpOK);
fprintf('Tp band filter: %d / %d segments out-of-band (%.1f%%) -- excluded from Tp stats\n', ...
    nTpOut, numel(tpOK), 100*nTpOut/numel(tpOK));

%% Stats helper
stats = @(x, y) struct( ...
    'medX',  median(x, 'omitnan'), ...
    'medY',  median(y, 'omitnan'), ...
    'bias',  median(y - x, 'omitnan'), ...
    'rms',   sqrt(mean((y - x).^2, 'omitnan')), ...
    'r2',    1 - var(y - x, 'omitnan') / var(x, 'omitnan'));

sHs = stats(Hs_l, Hs_o);
sTp = stats(Tp_l(tpOK), Tp_o(tpOK));
sDp = stats(Dp_l, Dp_o);
sSp = stats(Sp_l, Sp_o);

fprintf('\n=== Bulk parameter comparison (matched pairs) ===\n');
fprintf('              Legacy(med)  MTM(med)   bias(M-L)   RMS    R2\n');
fprintf('  Hs (m)      %8.3f    %8.3f   %+7.3f   %5.3f  %5.3f\n', ...
    sHs.medX, sHs.medY, sHs.bias, sHs.rms, sHs.r2);
fprintf('  Tp (s)      %8.2f    %8.2f   %+7.2f   %5.2f  %5.3f\n', ...
    sTp.medX, sTp.medY, sTp.bias, sTp.rms, sTp.r2);
fprintf('  Dp (deg)    %8.1f    %8.1f   %+7.1f   %5.1f  %5.3f\n', ...
    sDp.medX, sDp.medY, sDp.bias, sDp.rms, sDp.r2);
fprintf('  Spread (deg)%8.1f    %8.1f   %+7.1f   %5.1f  %5.3f\n', ...
    sSp.medX, sSp.medY, sSp.bias, sSp.rms, sSp.r2);
fprintf('  Z-test SS   %8.3f    %8.3f\n', median(zS_l,'omitnan'), median(zS_o,'omitnan'));

%% Figures
outDir = 'outputs/validation/Ruby2D';
if ~exist(outDir, 'dir'), mkdir(outDir); end

% --- Figure 1: 2x2 scatter ---
fig1 = figure('Color','w','Position',[100 100 900 800]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

scat = @(x, y, lim, lbl, s) plotScatter(x, y, lim, lbl, s);

nexttile; scat(Hs_l,        Hs_o,        [0 max(Hs_l)*1.05], 'H_s (m)',         sHs);
nexttile; scat(Tp_l(tpOK),  Tp_o(tpOK),  [4 22],              'T_p (s)',         sTp);
nexttile; scat(Dp_l,        Dp_o,        [-90 90],            'Dir SS (deg)',    sDp);
nexttile; scat(Sp_l,        Sp_o,        [0 50],              'Spread SS (deg)', sSp);

sgtitle({'Ruby2D MOP582\_6m: multi-taper vs legacy', ...
         sprintf('%d matched 60-min segments, Oct 2021 -- Feb 2022', nMatch)}, ...
        'FontWeight','bold');
saveas(fig1, fullfile(outDir, 'ruby2d_582_6m_scatter.png'));
fprintf('\nSaved %s\n', fullfile(outDir, 'ruby2d_582_6m_scatter.png'));

% --- Figure 2: time series ---
fig2 = figure('Color','w','Position',[100 100 1200 900]);
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');

t = leg_mid(jl);

% Plot multi-taper as a thin line, legacy as markers on top so both are visible
cMTM = [0.00 0.45 0.74];
cLeg = [0.85 0.33 0.10];

nexttile; hold on;
plot(t, Hs_o, '-',  'Color', cMTM, 'LineWidth', 0.8, 'DisplayName','Multi-taper');
plot(t, Hs_l, 'o',  'Color', cLeg,  'MarkerSize', 3, 'MarkerFaceColor', cLeg, ...
    'DisplayName','Legacy');
ylabel('H_s (m)'); legend('Location','best'); grid on;
title('Bulk parameter time series');

nexttile; hold on;
tpOK_local = (Tp_l >= 4 & Tp_l <= 25) & (Tp_o >= 4 & Tp_o <= 25);
plot(t(tpOK_local), Tp_o(tpOK_local), '.',  'Color', cMTM, 'MarkerSize', 4);
plot(t(tpOK_local), Tp_l(tpOK_local), 'o',  'Color', cLeg,  'MarkerSize', 3);
ylabel('T_p (s)'); ylim([4 22]); grid on;

nexttile; hold on;
plot(t, Dp_o, '.',  'Color', cMTM, 'MarkerSize', 4);
plot(t, Dp_l, 'o',  'Color', cLeg,  'MarkerSize', 3);
ylabel('Dir SS (deg)'); grid on;

nexttile; hold on;
plot(t, Sp_o, '.',  'Color', cMTM, 'MarkerSize', 4);
plot(t, Sp_l, 'o',  'Color', cLeg,  'MarkerSize', 3);
ylabel('Spread SS (deg)'); ylim([0 50]); grid on;
xlabel('Time');

saveas(fig2, fullfile(outDir, 'ruby2d_582_6m_timeseries.png'));
fprintf('Saved %s\n', fullfile(outDir, 'ruby2d_582_6m_timeseries.png'));

%% Representative spectrum overlay
% For a fair compare, average our 17-min segments within the legacy 60-min
% window so we are integrating over the same time period.
[fo, Po, Hs_check_o, nUsed_o] = avgOurSpectrum(L2, rep.time, 60);
fl = rep.fm;
Pl = rep.SSE;
ml = ~isnan(fl) & ~isnan(Pl);
m0_l = trapz(fl(ml), Pl(ml));   Hs_check_l = 4*sqrt(m0_l);

fprintf('\nRepresentative segment, legacy hour starting %s (Hs~%.2f m):\n', ...
    string(rep.time), rep.Hs);
fprintf('  Legacy Hs from SSE         : %.3f m\n', Hs_check_l);
fprintf('  MTM Hs from averaged S_eta : %.3f m  (%d segments averaged)\n', ...
    Hs_check_o, nUsed_o);

% High-Hs case
[foH, PoH, Hs_check_oH, nUsed_oH] = avgOurSpectrum(L2, high.time, 60);
flH = high.fm;  PlH = high.SSE;
mlH = ~isnan(flH) & ~isnan(PlH);
m0_lH = trapz(flH(mlH), PlH(mlH));   Hs_check_lH = 4*sqrt(m0_lH);
fprintf('Storm peak hour starting %s (Hs~%.2f m):\n', ...
    string(high.time), high.Hs);
fprintf('  Legacy Hs from SSE         : %.3f m\n', Hs_check_lH);
fprintf('  MTM Hs from averaged S_eta : %.3f m  (%d segments averaged)\n', ...
    Hs_check_oH, nUsed_oH);

fig3 = figure('Color','w','Position',[100 100 1100 800]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

nexttile; semilogy(fl, Pl, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.2); hold on;
          semilogy(fo, Po, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.2);
xlim([0 0.30]); ylim([1e-4 max([Pl; Po])*2]);
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)'); grid on;
legend('Legacy','Multi-taper','Location','northeast');
title(sprintf('Median segment: %s\n(legacy H_s=%.2f, multi-taper H_s=%.2f m, %d-seg avg)', ...
    datestr(rep.time,'mmm dd yyyy HH:MM'), Hs_check_l, Hs_check_o, nUsed_o));

nexttile; plot(fl, Pl, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.2); hold on;
          plot(fo, Po, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.2);
xlim([0.04 0.16]);
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)'); grid on;
title('Swell band, linear scale');

nexttile; semilogy(flH, PlH, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.2); hold on;
          semilogy(foH, PoH, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.2);
xlim([0 0.30]); ylim([1e-4 max([PlH; PoH])*2]);
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)'); grid on;
title(sprintf('Storm peak: %s\n(legacy H_s=%.2f, multi-taper H_s=%.2f m, %d-seg avg)', ...
    datestr(high.time,'mmm dd yyyy HH:MM'), Hs_check_lH, Hs_check_oH, nUsed_oH));

nexttile; plot(flH, PlH, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.2); hold on;
          plot(foH, PoH, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.2);
xlim([0.04 0.16]);
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)'); grid on;
title('Swell band, linear scale');

sgtitle('Ruby2D MOP582\_6m: representative spectra','FontWeight','bold');
saveas(fig3, fullfile(outDir, 'ruby2d_582_6m_spectra.png'));
fprintf('Saved %s\n', fullfile(outDir, 'ruby2d_582_6m_spectra.png'));

%% Save numeric summary
results = struct( ...
    'nMatched', nMatch, ...
    'Hs', sHs, 'Tp', sTp, 'Dp', sDp, 'Spread', sSp, ...
    'paired', struct('time', t, 'Hs_a', Hs_l, 'Hs_o', Hs_o, ...
                     'Tp_a', Tp_l, 'Tp_o', Tp_o, ...
                     'Dp_a', Dp_l, 'Dp_o', Dp_o, ...
                     'Sp_a', Sp_l, 'Sp_o', Sp_o, ...
                     'zS_a', zS_l, 'zS_o', zS_o));
save(fullfile(outDir, 'ruby2d_582_6m_compare.mat'), 'results');
fprintf('\nSaved numeric summary -> %s\n', ...
    fullfile(outDir, 'ruby2d_582_6m_compare.mat'));

fprintf('\nDone.\n');

%% local helpers
function plotScatter(x, y, lim, lbl, s)
    plot(lim, lim, 'k--'); hold on;
    plot(x, y, '.', 'MarkerSize', 4, 'Color', [0.20 0.40 0.70]);
    xlim(lim); ylim(lim); axis square; grid on;
    xlabel(['Legacy  ' lbl]); ylabel(['Multi-taper  ' lbl]);
    title(sprintf('bias %+.2f, RMS %.2f, R^2 %.2f', s.bias, s.rms, s.r2));
end

function [f, Pavg, Hs_avg, nUsed] = avgOurSpectrum(L2, legStart, winMin)
    % Average our valid 17-min S_eta segments whose midpoint falls inside
    % the legacy [legStart, legStart + winMin] window.
    f = L2.f;
    win = [legStart, legStart + minutes(winMin)];
    inWin = L2.segValid & L2.time >= win(1) & L2.time <= win(2);
    nUsed = sum(inWin);
    Pavg  = mean(L2.S_eta(:, inWin), 2, 'omitnan');
    m0    = trapz(f, Pavg);
    Hs_avg = 4 * sqrt(m0);
end
