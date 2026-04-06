% INVESTIGATE_SIO_AMPLIFICATION  Diagnose why SIO Pier shows 2-5x spectral
% peak amplification relative to MOP, far exceeding other sites.
%
% Compares SIO vs Torrey Pines spectral characteristics side by side:
%   1. Mean spectra overlay (PUV and MOP) for SIO vs TP
%   2. Spectral ratio by frequency for SIO vs TP
%   3. MOP spectral resolution check — does MOP D0511 have different
%      frequency spacing than D0580/D0586?
%   4. Shore-normal angle effect — SIO is 283° vs TP 264°

startup_puv
toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
if ~exist('read_MOPline2', 'file'), addpath(toolboxPath); end

g = 9.81;

%% Load representative instruments: SIO25D (best SIO dataset) and TBR23 MOP580_7m
fprintf('Loading L2 data...\n');
sio = load('outputs/L2/SIO25D/SIO_6m_L2.mat'); L2_sio = sio.L2;
tbr = load('outputs/L2/TBR23/MOP580_7m_L2.mat'); L2_tbr = tbr.L2;

%% Load MOP data for each
fprintf('Loading MOP data for SIO (D0511)...\n');
validSio = L2_sio.segValid;
tS1 = min(L2_sio.time(validSio)); tS2 = max(L2_sio.time(validSio));
if isempty(tS1.TimeZone), tS1.TimeZone = 'UTC'; tS2.TimeZone = 'UTC'; end
MOP_sio = read_MOPline2('D0511', tS1, tS2);

fprintf('Loading MOP data for TP (D0580)...\n');
validTbr = L2_tbr.segValid;
tT1 = min(L2_tbr.time(validTbr)); tT2 = max(L2_tbr.time(validTbr));
if isempty(tT1.TimeZone), tT1.TimeZone = 'UTC'; tT2.TimeZone = 'UTC'; end
MOP_tbr = read_MOPline2('D0580', tT1, tT2);

%% Compare MOP frequency grids
fprintf('\n=== MOP Frequency Grid Comparison ===\n');
freq_sio = double(MOP_sio.frequency(:));
freq_tbr = double(MOP_tbr.frequency(:));
fbw_sio = double(MOP_sio.fbw(:));
fbw_tbr = double(MOP_tbr.fbw(:));

fprintf('  D0511 (SIO):  %d freq bins, range [%.4f, %.4f] Hz\n', ...
    length(freq_sio), freq_sio(1), freq_sio(end));
fprintf('  D0580 (TP):   %d freq bins, range [%.4f, %.4f] Hz\n', ...
    length(freq_tbr), freq_tbr(1), freq_tbr(end));

fprintf('\n  D0511 bandwidth at swell peak (0.05-0.10 Hz):\n');
iSwell_sio = freq_sio >= 0.05 & freq_sio <= 0.10;
iSwell_tbr = freq_tbr >= 0.05 & freq_tbr <= 0.10;
fprintf('    Frequencies: %s\n', mat2str(freq_sio(iSwell_sio)', 4));
fprintf('    Bandwidths:  %s\n', mat2str(fbw_sio(iSwell_sio)', 4));
fprintf('  D0580 bandwidth at swell peak (0.05-0.10 Hz):\n');
fprintf('    Frequencies: %s\n', mat2str(freq_tbr(iSwell_tbr)', 4));
fprintf('    Bandwidths:  %s\n', mat2str(fbw_tbr(iSwell_tbr)', 4));

%% Check if MOP freq resolution is coarser for SIO
fprintf('\n  Mean bandwidth in SS band:\n');
iSS_sio = freq_sio >= 0.04 & freq_sio <= 0.25;
iSS_tbr = freq_tbr >= 0.04 & freq_tbr <= 0.25;
fprintf('    D0511 (SIO):  %.5f Hz  (%d bins in SS band)\n', ...
    mean(fbw_sio(iSS_sio)), sum(iSS_sio));
fprintf('    D0580 (TP):   %.5f Hz  (%d bins in SS band)\n', ...
    mean(fbw_tbr(iSS_tbr)), sum(iSS_tbr));

%% Compute mean spectra
f_puv = L2_sio.f;  % same for both

% Mean PUV spectra
meanS_sio = mean(L2_sio.S_eta(:, validSio), 2, 'omitnan');
meanS_tbr = mean(L2_tbr.S_eta(:, validTbr), 2, 'omitnan');

% Mean MOP spectra (shoaled to PUV depth)
h_sio = median(L2_sio.depth(validSio), 'omitnan');
h_tbr = median(L2_tbr.depth(validTbr), 'omitnan');
h_mop_sio = double(MOP_sio.depth);
h_mop_tbr = double(MOP_tbr.depth);

% Shoal MOP to PUV depth
omega_sio = 2*pi*freq_sio;
omega_tbr = 2*pi*freq_tbr;
k_mop_sio = get_wavenumber(omega_sio, h_mop_sio);
k_puv_sio = get_wavenumber(omega_sio, h_sio);
cg_mop_sio = get_cg(k_mop_sio, h_mop_sio);
cg_puv_sio = get_cg(k_puv_sio, h_sio);
sf_sio = cg_mop_sio(:) ./ cg_puv_sio(:);

k_mop_tbr = get_wavenumber(omega_tbr, h_mop_tbr);
k_puv_tbr = get_wavenumber(omega_tbr, h_tbr);
cg_mop_tbr = get_cg(k_mop_tbr, h_mop_tbr);
cg_puv_tbr = get_cg(k_puv_tbr, h_tbr);
sf_tbr = cg_mop_tbr(:) ./ cg_puv_tbr(:);

spec_shoaled_sio = MOP_sio.spec1D .* sf_sio';
spec_shoaled_tbr = MOP_tbr.spec1D .* sf_tbr';

meanMOP_sio = mean(spec_shoaled_sio, 1, 'omitnan')';
meanMOP_tbr = mean(spec_shoaled_tbr, 1, 'omitnan')';

% Interpolate MOP to PUV freq grid
meanMOP_sio_interp = interp1(freq_sio, meanMOP_sio, f_puv, 'linear', 0);
meanMOP_tbr_interp = interp1(freq_tbr, meanMOP_tbr, f_puv, 'linear', 0);

%% Print key comparisons
fprintf('\n=== Spectral Comparison: SIO vs Torrey Pines ===\n');
fprintf('  SIO (D0511): depth=%.1fm, shore-normal=%.0f°\n', h_sio, L2_sio.shorenormal);
fprintf('  TP  (D0580): depth=%.1fm, shore-normal=%.0f°\n', h_tbr, L2_tbr.shorenormal);

iSS = f_puv >= 0.04 & f_puv <= 0.25;
ratio_sio = meanS_sio ./ meanMOP_sio_interp;
ratio_tbr = meanS_tbr ./ meanMOP_tbr_interp;
ratio_sio(meanMOP_sio_interp <= 0) = NaN;
ratio_tbr(meanMOP_tbr_interp <= 0) = NaN;

fprintf('\n  Mean spectral ratio in SS band:\n');
fprintf('    SIO: %.3f\n', mean(ratio_sio(iSS), 'omitnan'));
fprintf('    TP:  %.3f\n', mean(ratio_tbr(iSS), 'omitnan'));

fprintf('\n  Peak spectral density:\n');
fprintf('    SIO PUV: %.4f m^2/Hz,  MOP: %.4f m^2/Hz,  ratio: %.2f\n', ...
    max(meanS_sio(iSS)), max(meanMOP_sio_interp(iSS)), ...
    max(meanS_sio(iSS))/max(meanMOP_sio_interp(iSS)));
fprintf('    TP  PUV: %.4f m^2/Hz,  MOP: %.4f m^2/Hz,  ratio: %.2f\n', ...
    max(meanS_tbr(iSS)), max(meanMOP_tbr_interp(iSS)), ...
    max(meanS_tbr(iSS))/max(meanMOP_tbr_interp(iSS)));

%% Check MOP spectral shape more carefully
% The key question: is MOP D0511 providing spectra that are intrinsically
% different from D0580? If MOP has coarser frequency resolution at D0511,
% the peak would be artificially lower.
fprintf('\n=== MOP Peak Spectral Density at 10m (before shoaling) ===\n');
meanMOP_raw_sio = mean(MOP_sio.spec1D, 1, 'omitnan')';
meanMOP_raw_tbr = mean(MOP_tbr.spec1D, 1, 'omitnan')';

[pk_sio, iPk_sio] = max(meanMOP_raw_sio(iSS_sio));
[pk_tbr, iPk_tbr] = max(meanMOP_raw_tbr(iSS_tbr));
fSS_sio = freq_sio(iSS_sio);
fSS_tbr = freq_tbr(iSS_tbr);

fprintf('  D0511 (SIO): peak = %.4f m^2/Hz at f = %.4f Hz\n', pk_sio, fSS_sio(iPk_sio));
fprintf('  D0580 (TP):  peak = %.4f m^2/Hz at f = %.4f Hz\n', pk_tbr, fSS_tbr(iPk_tbr));
fprintf('  Ratio (SIO/TP): %.3f\n', pk_sio/pk_tbr);

% Total energy comparison
m0_sio = sum(meanMOP_raw_sio(iSS_sio) .* fbw_sio(iSS_sio));
m0_tbr = sum(meanMOP_raw_tbr(iSS_tbr) .* fbw_tbr(iSS_tbr));
fprintf('\n  MOP total energy (m0) in SS band:\n');
fprintf('    D0511 (SIO): %.4f m^2  →  Hs = %.2f m\n', m0_sio, 4*sqrt(m0_sio));
fprintf('    D0580 (TP):  %.4f m^2  →  Hs = %.2f m\n', m0_tbr, 4*sqrt(m0_tbr));

%% ======================== FIGURES ========================

fig1 = figure('Position', [50 50 1400 800], 'Color', 'w');

% Panel 1: Mean spectra comparison
subplot(2,2,1)
plot(f_puv, meanS_sio, 'b-', 'LineWidth', 2, 'DisplayName', 'SIO PUV'); hold on
plot(f_puv, meanMOP_sio_interp, 'b--', 'LineWidth', 1.5, 'DisplayName', 'SIO MOP shoaled');
plot(f_puv, meanS_tbr, 'r-', 'LineWidth', 2, 'DisplayName', 'TP PUV');
plot(f_puv, meanMOP_tbr_interp, 'r--', 'LineWidth', 1.5, 'DisplayName', 'TP MOP shoaled');
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)');
title('Mean spectra: SIO vs Torrey Pines');
legend('Location', 'northeast'); xlim([0.03 0.25]); grid on;

% Panel 2: Spectral ratio comparison
subplot(2,2,2)
plot(f_puv, ratio_sio, 'b-', 'LineWidth', 2, 'DisplayName', ...
    sprintf('SIO (h=%.1fm)', h_sio)); hold on
plot(f_puv, ratio_tbr, 'r-', 'LineWidth', 2, 'DisplayName', ...
    sprintf('TP (h=%.1fm)', h_tbr));
yline(1, 'k--', 'HandleVisibility', 'off');
xlabel('Frequency (Hz)'); ylabel('PUV / MOP ratio');
title('Spectral ratio: SIO vs Torrey Pines');
legend('Location', 'northeast'); xlim([0.03 0.25]); ylim([0 5]); grid on;

% Panel 3: MOP raw spectra at 10m (before shoaling)
subplot(2,2,3)
plot(freq_sio, meanMOP_raw_sio, 'b-', 'LineWidth', 2, 'DisplayName', 'D0511 (SIO)'); hold on
plot(freq_tbr, meanMOP_raw_tbr, 'r-', 'LineWidth', 2, 'DisplayName', 'D0580 (TP)');
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)');
title('MOP spectra at 10m (before shoaling)');
legend('Location', 'northeast'); xlim([0.03 0.25]); grid on;

% Panel 4: MOP frequency bandwidth comparison
subplot(2,2,4)
stem(freq_sio(iSS_sio), fbw_sio(iSS_sio), 'b-', 'LineWidth', 1.5, ...
    'DisplayName', 'D0511 (SIO)'); hold on
stem(freq_tbr(iSS_tbr), fbw_tbr(iSS_tbr), 'r-', 'LineWidth', 1.5, ...
    'DisplayName', 'D0580 (TP)');
xlabel('Frequency (Hz)'); ylabel('Bandwidth (Hz)');
title('MOP frequency bin widths');
legend('Location', 'northeast'); xlim([0.03 0.25]); grid on;

sgtitle('SIO Pier Amplification Investigation', 'FontWeight', 'bold', 'FontSize', 14);

diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
exportgraphics(fig1, fullfile(diagDir, 'SIO_amplification_investigation.png'), 'Resolution', 200);
fprintf('\nFigure saved.\n');
