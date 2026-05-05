function results = test3_tidal_modulation(deployment, labels, opts)
% TEST3_TIDAL_MODULATION  Test whether segment-mean cross-shore velocity
% modulates systematically with tidal phase, conditional on Hs.
%
%   results = test3_tidal_modulation('TBR23', {'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'})
%
% Logic
%   A constant instrumental offset has zero tidal modulation. Any reproducible
%   modulation in uMean as a function of tidal phase, exceeding the empirical
%   noise envelope, is signal — and quantitatively so if it scales with Hs².
%
% Method
%   1. Load L2. Use detrended depth as the tidal proxy (interpolated to a
%      regular hourly grid).
%   2. Compute tidal phase from the analytic signal of band-passed depth
%      (preserves M2/S2 tides, removes deployment-mean and storm-surge
%      anomalies).
%   3. Wrap to [-pi, pi]. Define phase 0 = high tide (max depth), ±pi = low.
%   4. Bin uMean by tidal phase (16 bins).
%   5. Stratify by Hs: low (Hs<0.6 m), mid (0.6-1.0), high (>=1.0).
%   6. Within each Hs bin, compute mean and bootstrap 95% CI per phase bin.
%   7. Plot conditional uMean(phase | Hs); report modulation amplitude.
%
% A constant bias gives flat lines at all Hs. Real wave-driven modulation
% should grow in amplitude with Hs.
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),  opts.L2dir  = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts, 'figDir'), opts.figDir = fullfile(pipelineRoot,'outputs','validation','mean_flow', deployment); end
if ~isfield(opts, 'nPhase'), opts.nPhase = 16; end
if ~isfield(opts, 'nBoot'),  opts.nBoot  = 500; end

if ~exist(opts.figDir, 'dir'), mkdir(opts.figDir); end
if ischar(labels) || isstring(labels), labels = cellstr(labels); end

nI = numel(labels);
results = struct();

fig = figure('Visible','off','Position',[100 100 1500 950]);
HsBins = {  [0.0 0.6], 'low (Hs<0.6 m)';
            [0.6 1.0], 'mid (0.6-1.0 m)';
            [1.0 inf], 'high (Hs>=1.0 m)' };
nHs = size(HsBins, 1);
phaseEdges = linspace(-pi, pi, opts.nPhase + 1);
phaseCtr   = (phaseEdges(1:end-1) + phaseEdges(2:end)) / 2;

for iI = 1:nI
    label = labels{iI};
    L2file = fullfile(opts.L2dir, deployment, [label '_L2.mat']);
    if ~isfile(L2file), warning('test3:noFile','Missing %s', L2file); continue; end
    S = load(L2file); L2 = S.L2;

    valid = L2.segValid(:) & ~isnan(L2.uMean(:)) & ~isnan(L2.Hs(:)) & ~isnan(L2.depth(:));
    if sum(valid) < 100, continue; end

    t  = L2.time(valid);
    h  = L2.depth(valid);
    u  = L2.uMean(valid);
    Hs = L2.Hs(valid);

    % Tidal phase: bandpass depth around tidal frequencies.
    % Use a 4th-order zero-phase Butterworth: 1/30 hr (~0.033 cph) to 1 hr.
    % Need uniform sampling — interp to 17-min grid first.
    dt_grid = minutes(17);
    t_uniform = (min(t):dt_grid:max(t))';
    h_unif = interp1(t, h, t_uniform, 'linear', 'extrap');
    fs_h = 1 / seconds(dt_grid);  % samples per second

    h_dt = detrend(h_unif);  % remove linear drift
    [b, a] = butter(4, [1/(30*3600), 1/(3*3600)] / (fs_h/2), 'bandpass');
    h_band = filtfilt(b, a, h_dt);

    % Hilbert: phase = angle of analytic signal.
    % Convention: high tide (max depth) → phase 0; low tide → ±pi.
    z = hilbert(h_band);
    phase_unif = angle(z);
    % Hilbert defines phase such that phase=0 at peaks of cos. Verify by
    % aligning: at index of max h_band, phase should be near 0.
    [~, iMax] = max(h_band);
    phase_offset = phase_unif(iMax);
    phase_unif = wrapToPi(phase_unif - phase_offset);

    phase_seg = interp1(t_uniform, unwrap(phase_unif), t, 'linear', 'extrap');
    phase_seg = wrapToPi(phase_seg);

    % Bin per Hs strata
    inst = struct();
    inst.label = label;
    inst.phaseCtr = phaseCtr;

    subplot(nI, nHs, (iI-1)*nHs + 1 - 1 + 1);  % leftmost — placeholder

    for iH = 1:nHs
        bnd = HsBins{iH, 1};  hsLab = HsBins{iH, 2};
        in = Hs >= bnd(1) & Hs < bnd(2);
        u_h  = u(in);
        ph_h = phase_seg(in);

        meanU = nan(opts.nPhase, 1);
        loCI  = nan(opts.nPhase, 1);
        hiCI  = nan(opts.nPhase, 1);
        nBin  = zeros(opts.nPhase, 1);
        for k = 1:opts.nPhase
            inB = ph_h >= phaseEdges(k) & ph_h < phaseEdges(k+1);
            nBin(k) = sum(inB);
            if nBin(k) >= 5
                vals = u_h(inB);
                meanU(k) = mean(vals);
                bootStat = bootstrp(opts.nBoot, @mean, vals);
                ci = prctile(bootStat, [2.5 97.5]);
                loCI(k) = ci(1);  hiCI(k) = ci(2);
            end
        end

        modAmp = max(meanU) - min(meanU);  % peak-to-peak modulation in this Hs strata
        inst.bin(iH).bnd     = bnd;
        inst.bin(iH).hsLab   = hsLab;
        inst.bin(iH).meanU   = meanU;
        inst.bin(iH).loCI    = loCI;
        inst.bin(iH).hiCI    = hiCI;
        inst.bin(iH).nBin    = nBin;
        inst.bin(iH).modAmp  = modAmp;

        subplot(nI, nHs, (iI-1)*nHs + iH);
        ax = gca;
        % Shade CI
        keep = ~isnan(meanU);
        if any(keep)
            patch(ax, [phaseCtr(keep), fliplr(phaseCtr(keep))], ...
                  [loCI(keep)', fliplr(hiCI(keep)')], ...
                  [0.3 0.5 0.85], 'FaceAlpha', 0.30, 'EdgeColor', 'none');
            hold(ax, 'on');
            plot(ax, phaseCtr, meanU, 'k-', 'LineWidth', 1.4);
            plot(ax, phaseCtr, meanU, 'ko', 'MarkerFaceColor','w','MarkerSize',4);
        end
        yline(ax, 0, 'k:');
        xline(ax, 0, 'k:');  % high tide
        xline(ax, -pi, 'k:'); xline(ax, pi, 'k:');  % low tide
        xlim(ax, [-pi pi]);
        xticks(ax, [-pi -pi/2 0 pi/2 pi]);
        xticklabels(ax, {'low','rise','high','fall','low'});
        ylabel(ax, 'uMean (m/s)');
        if iI == 1
            title(ax, sprintf('%s    amp=%.3f m/s   N=%d', hsLab, modAmp, sum(in)));
        else
            title(ax, sprintf('amp=%.3f m/s   N=%d', modAmp, sum(in)));
        end
        if iI == nI
            xlabel(ax, 'tidal phase');
        end
        grid(ax, 'on');

        % Row label at the left edge of the first column
        if iH == 1
            posAx = get(ax, 'Position');
            annotation(fig, 'textbox', ...
                [0.005, posAx(2) + posAx(4)/2 - 0.03, 0.06, 0.06], ...
                'String', tex_label(label), ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                'EdgeColor', 'none', 'Interpreter', 'tex');
        end
    end

    results.(matlab.lang.makeValidName(label)) = inst;
    fprintf('\n--- %s ---\n', label);
    for iH = 1:nHs
        fprintf('  %-20s  modulation amp = %.4f m/s  (N = %d)\n', ...
            inst.bin(iH).hsLab, inst.bin(iH).modAmp, sum(inst.bin(iH).nBin));
    end
end

sgtitle(sprintf('%s — Test 3: uMean vs tidal phase, stratified by H_s', deployment));
exportgraphics(fig, fullfile(opts.figDir, 'test3_tidal_modulation.png'), 'Resolution', 200);
close(fig);
fprintf('\nFigure saved: %s\n', fullfile(opts.figDir, 'test3_tidal_modulation.png'));
end
