function results = test4_reynolds_consistency(deployment, labels, opts)
% TEST4_REYNOLDS_CONSISTENCY  Test whether the Reynolds-stress estimate
% <u'w'> tracks the same wave-momentum balance as uMean.
%
%   results = test4_reynolds_consistency('TBR23',{'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'})
%
% Logic
%   The cross-shore wave-momentum balance (depth-averaged steady) reads
%       d<S_xx>/dx + rho g h d eta_bar/dx + rho <u'w'>|_bed = 0
%   <u'w'> integrates wave-driven momentum flux into the bed and balances the
%   radiation-stress gradient that drives setup/setdown and the undertow. It
%   is computed from the same Vector velocity record as uMean but uses
%   *fluctuating* covariance, not the segment mean. If both quantities are
%   real and physical, they should
%       (a) both scale with Hs^2 (wave forcing),
%       (b) correlate in time at common timestamps within an instrument.
%   For a constant uMean offset to be an instrumental artifact, the
%   *fluctuating* <u'w'> would have to be coincidentally biased in the same
%   way — implausible because they use independent processing paths.
%
% Outputs
%   - Hs^2 scaling fit for <u'w'> per instrument (compare slopes/intercepts).
%   - Time correlation between uMean and <u'w'> per instrument.
%   - Side-by-side scatter and stats panel.
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),  opts.L2dir  = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts, 'figDir'), opts.figDir = fullfile(pipelineRoot,'outputs','validation','mean_flow', deployment); end
if ~isfield(opts, 'HsMin'),  opts.HsMin  = 0.2; end

if ~exist(opts.figDir, 'dir'), mkdir(opts.figDir); end
if ischar(labels) || isstring(labels), labels = cellstr(labels); end

nI = numel(labels);
results = struct();

fig = figure('Visible','off','Position',[100 100 1500 850]);
for iI = 1:nI
    label = labels{iI};
    L2file = fullfile(opts.L2dir, deployment, [label '_L2.mat']);
    if ~isfile(L2file), continue; end
    S = load(L2file); L2 = S.L2;

    valid = L2.segValid(:) & ~isnan(L2.uMean(:)) & ~isnan(L2.Hs(:)) & ...
            ~isnan(L2.reynolds.uw(:)) & L2.Hs(:) >= opts.HsMin;
    if sum(valid) < 30
        warning('test4:tooFewSegments', ...
            '%s: only %d segments with Hs >= %.2f m — skipping fit (likely deep-water instrument).', ...
            label, sum(valid), opts.HsMin);
        continue
    end

    Hs    = L2.Hs(valid);
    uMean = L2.uMean(valid);
    uw    = L2.reynolds.uw(valid);
    h_med = median(L2.depth(valid));

    % Hs^2 scaling fit for <u'w'>
    X = [Hs.^2, ones(size(Hs))];
    [b_uw, bint_uw] = regress(uw, X);
    yhat_uw = X * b_uw;
    R2_uw = 1 - sum((uw - yhat_uw).^2) / sum((uw - mean(uw)).^2);

    % Time correlation between uMean and <u'w'>
    Rmat = corrcoef(uMean, uw);
    R_uM_uw = Rmat(1, 2);

    % Stash
    results.(matlab.lang.makeValidName(label)) = struct( ...
        'h_med', h_med, 'N', sum(valid), ...
        'alpha_uw', b_uw(1), 'alpha_uw_CI', bint_uw(1, :), ...
        'beta_uw',  b_uw(2), 'beta_uw_CI',  bint_uw(2, :), ...
        'R2_uw_Hs2', R2_uw, ...
        'R_uMean_uw', R_uM_uw);

    % Top row: <u'w'> vs Hs^2 with fit
    subplot(2, nI, iI);
    scatter(Hs.^2, uw, 6, 'filled', 'MarkerFaceAlpha', 0.20); hold on;
    xPlot = linspace(0, max(Hs)^2, 50);
    plot(xPlot, b_uw(1)*xPlot + b_uw(2), 'r-', 'LineWidth', 1.5);
    yline(0, 'k:');
    xlabel('H_s^2 (m^2)'); ylabel('<u''w''> (m^2/s^2)');
    title(tex_label(label));
    text(0.04, 0.95, sprintf('\\alpha = %+.4f\n\\beta = %+.4f\nR^2 = %.3f', ...
        b_uw(1), b_uw(2), R2_uw), ...
        'Units','normalized','VerticalAlignment','top', 'FontSize', 9, ...
        'BackgroundColor',[1 1 1 0.85],'EdgeColor','k','Margin',3);
    grid on;

    % Bottom row: uMean vs <u'w'> scatter
    subplot(2, nI, nI + iI);
    scatter(uw, uMean, 6, 'filled', 'MarkerFaceAlpha', 0.20); hold on;
    xline(0, 'k:'); yline(0, 'k:');
    xlabel('<u''w''> (m^2/s^2)'); ylabel('uMean (m/s)');
    title(sprintf('R = %.3f,  N=%d', R_uM_uw, sum(valid)));
    grid on;

    fprintf('\n--- %s ---\n', label);
    fprintf('  <u''w''> = α Hs^2 + β :  α=%+.5f [%+.5f,%+.5f]  β=%+.5f [%+.5f,%+.5f]  R^2=%.3f\n', ...
        b_uw(1), bint_uw(1,1), bint_uw(1,2), b_uw(2), bint_uw(2,1), bint_uw(2,2), R2_uw);
    fprintf('  Time correlation R(uMean, <u''w''>) = %+.3f   (N=%d)\n', R_uM_uw, sum(valid));
end

sgtitle(sprintf('%s — Test 4: Reynolds stress vs H_s^2, and vs uMean', deployment));
exportgraphics(fig, fullfile(opts.figDir, 'test4_reynolds_consistency.png'), 'Resolution', 200);
close(fig);
fprintf('\nFigure saved: %s\n', fullfile(opts.figDir, 'test4_reynolds_consistency.png'));
end
