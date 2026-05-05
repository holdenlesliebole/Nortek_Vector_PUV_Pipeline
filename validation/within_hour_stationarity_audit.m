function audit = within_hour_stationarity_audit(deployment, instruments, opts)
% WITHIN_HOUR_STATIONARITY_AUDIT  Quantify sub-hour variability in PUV
% bulk parameters using existing 17-min L2 outputs.
%
%   audit = within_hour_stationarity_audit('TBR23', {'MOP586_5m','MOP586_7m'})
%   audit = within_hour_stationarity_audit('TBR23', {'MOP586_5m'}, opts)
%
% Purpose
%   We are considering moving PUV segmentation from 17-min to 1-hour to
%   match MOP cadence. Before reprocessing, check whether the ocean is actually
%   stationary on the 1-hour scale at TBR23 depths. Each clock hour
%   already contains ~3-4 of the 17-min L2 segments, so within-hour
%   coefficient of variation (CV = std/mean) of bulk parameters is a
%   direct estimate of how much state evolves inside an hour.
%
% Variables audited (per hour, where N>=3 valid 17-min segments fall in):
%   Hs, Hs_SS, Hs_IG, Tp, Tm02, meanDir (circular), depth, skewness,
%   asymmetry. Also reports two ways to roll Hs up to 1 hour:
%     Hs_lin    = mean(Hs_17)       (linear average, biased low by Jensen)
%     Hs_energy = sqrt(mean(Hs.^2)) (energy average, the physically correct one)
%
% Stratifications
%   - Sea state by hourly mean Hs: calm <0.7m, mixed 0.7-1.5m, storm >=1.5m
%   - Tidal rate by |dh/dt|:       slack <0.05 m/hr, mid 0.05-0.2, fast >=0.2
%
% Outputs
%   audit          - struct, one entry per instrument with hourly stats
%   Printed report - medians and 90th-percentile CVs, per stratification
%   Figures saved  - outputs/validation/within_hour_audit/<deployment>/
%
% INPUTS
%   deployment  - string, e.g. 'TBR23'
%   instruments - cell array of instrument labels, e.g. {'MOP586_5m'}
%   opts        - (optional) struct:
%       .L2dir   - L2 root (default outputs/L2)
%       .figDir  - figure root (default outputs/validation/within_hour_audit)
%       .minN    - minimum sub-hour segments per hour to include (default 3)
%       .saveFig - logical, save figures (default true)
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),   opts.L2dir   = fullfile(pipelineRoot, 'outputs', 'L2'); end
if ~isfield(opts, 'figDir'),  opts.figDir  = fullfile(pipelineRoot, 'outputs', 'validation', 'within_hour_audit'); end
if ~isfield(opts, 'minN'),    opts.minN    = 3;   end
if ~isfield(opts, 'saveFig'), opts.saveFig = true; end

if ischar(instruments) || isstring(instruments), instruments = cellstr(instruments); end

figDirDep = fullfile(opts.figDir, deployment);
if opts.saveFig && ~exist(figDirDep, 'dir'), mkdir(figDirDep); end

% Variables we will audit (field name + display name + units + circular flag)
specs = {
    'Hs',       'H_s',           'm',    false
    'Hs_SS',    'H_{s,SS}',      'm',    false
    'Hs_IG',    'H_{s,IG}',      'm',    false
    'Tp',       'T_p',           's',    false
    'Tm02',     'T_{m02}',       's',    false
    'meanDir',  'mean dir',      'deg',  true
    'depth',    'h',             'm',    false
    'uMean',    'uMean (X-sh)',  'm/s',  false
    'vMean',    'vMean (alongsh)','m/s', false
};
% Velocity moments live in L2.vmom.*
vmomSpecs = {
    'skewness',  'Sk',  '-', false
    'asymmetry', 'As',  '-', false
};

audit = struct();

for iI = 1:numel(instruments)
    label = instruments{iI};
    L2file = fullfile(opts.L2dir, deployment, sprintf('%s_L2.mat', label));
    if ~isfile(L2file)
        warning('within_hour_stationarity_audit:noFile', 'Missing %s — skipping.', L2file);
        continue
    end
    fprintf('\n=== %s / %s ===\n', deployment, label);
    S = load(L2file);
    L2 = S.L2;

    valid = L2.segValid(:) & ~isnan(L2.Hs(:));
    if sum(valid) < 10
        warning('within_hour_stationarity_audit:tooFewSegs', '%s: only %d valid segs', label, sum(valid));
        continue
    end

    % Hour bin (clock hour containing the segment midpoint)
    hourBin = dateshift(L2.time(:), 'start', 'hour');
    [uH, ~, gIdx] = unique(hourBin(valid), 'sorted');

    % Pull validated arrays
    vIdx = find(valid);
    nH = numel(uH);

    % Pre-allocate per-hour outputs
    hourly = struct();
    hourly.time   = uH;
    hourly.N      = zeros(nH, 1);

    flatVars = [specs; vmomSpecs];
    for iV = 1:size(flatVars, 1)
        nm = flatVars{iV, 1};
        hourly.(nm).mean = nan(nH, 1);
        hourly.(nm).std  = nan(nH, 1);
        hourly.(nm).cv   = nan(nH, 1);
        hourly.(nm).range = nan(nH, 1);  % max-min within hour
    end
    hourly.Hs_lin    = nan(nH, 1);
    hourly.Hs_energy = nan(nH, 1);
    hourly.dhdt      = nan(nH, 1);  % m/hr, |first - last| inside the hour

    for h = 1:nH
        members = vIdx(gIdx == h);
        if numel(members) < opts.minN, continue; end
        hourly.N(h) = numel(members);

        % Bulk + spectral fields
        for iV = 1:size(specs, 1)
            nm = specs{iV, 1};
            isCirc = specs{iV, 4};
            x = L2.(nm)(members);
            x = x(~isnan(x));
            if numel(x) < opts.minN, continue; end
            if isCirc
                th = deg2rad(x);
                C = mean(cos(th));  Sn = mean(sin(th));
                Rbar = sqrt(C^2 + Sn^2);
                hourly.(nm).mean(h) = mod(rad2deg(atan2(Sn, C)), 360);
                hourly.(nm).std(h)  = rad2deg(sqrt(max(-2*log(max(Rbar,eps)), 0)));
                hourly.(nm).cv(h)   = hourly.(nm).std(h) / 360;  % normalize by full circle
                hourly.(nm).range(h) = circ_range_deg(x);
            else
                hourly.(nm).mean(h) = mean(x);
                hourly.(nm).std(h)  = std(x);
                if hourly.(nm).mean(h) ~= 0
                    hourly.(nm).cv(h) = hourly.(nm).std(h) / abs(hourly.(nm).mean(h));
                end
                hourly.(nm).range(h) = max(x) - min(x);
            end
        end

        % vmom fields
        for iV = 1:size(vmomSpecs, 1)
            nm = vmomSpecs{iV, 1};
            x = L2.vmom.(nm)(members);
            x = x(~isnan(x));
            if numel(x) < opts.minN, continue; end
            hourly.(nm).mean(h) = mean(x);
            hourly.(nm).std(h)  = std(x);
            % Sk/As cross zero — CV is unstable. Report std/|mean| but cap.
            if abs(hourly.(nm).mean(h)) > 0.05
                hourly.(nm).cv(h) = hourly.(nm).std(h) / abs(hourly.(nm).mean(h));
            end
            hourly.(nm).range(h) = max(x) - min(x);
        end

        % Hs roll-up: linear vs energy-conserving
        Hs_in = L2.Hs(members); Hs_in = Hs_in(~isnan(Hs_in));
        if numel(Hs_in) >= opts.minN
            hourly.Hs_lin(h)    = mean(Hs_in);
            hourly.Hs_energy(h) = sqrt(mean(Hs_in.^2));
        end

        % Tidal rate: depth change across the hour
        dseg = L2.depth(members);
        tseg = L2.time(members);
        dseg = dseg(~isnan(dseg));
        tseg = tseg(~isnan(L2.depth(members)));
        if numel(dseg) >= 2
            dt_hr = hours(tseg(end) - tseg(1));
            if dt_hr > 0
                hourly.dhdt(h) = abs(dseg(end) - dseg(1)) / dt_hr;
            end
        end
    end

    % Filter to populated hours
    keep = hourly.N >= opts.minN;
    fn = fieldnames(hourly);
    for k = 1:numel(fn)
        v = hourly.(fn{k});
        if isstruct(v)
            sub = fieldnames(v);
            for j = 1:numel(sub), v.(sub{j}) = v.(sub{j})(keep); end
            hourly.(fn{k}) = v;
        else
            hourly.(fn{k}) = v(keep);
        end
    end

    % Stratifications
    Hs_h = hourly.Hs.mean;
    dhdt = hourly.dhdt;

    seaState = strings(numel(Hs_h), 1);
    seaState(:) = "calm";
    seaState(Hs_h >= 0.7 & Hs_h < 1.5) = "mixed";
    seaState(Hs_h >= 1.5)              = "storm";

    tideRate = strings(numel(dhdt), 1);
    tideRate(:) = "slack";
    tideRate(dhdt >= 0.05 & dhdt < 0.2) = "mid";
    tideRate(dhdt >= 0.2)               = "fast";

    hourly.seaState = seaState;
    hourly.tideRate = tideRate;

    audit.(label) = hourly;

    % ---- Printed report ----
    print_report(label, hourly, flatVars);

    % ---- Figures ----
    if opts.saveFig
        make_figures(label, hourly, figDirDep);
    end
end

end  % main


% ============================================================
function print_report(label, h, flatVars)
fprintf('\n--- %s within-hour CV report  (n_hours = %d) ---\n', label, numel(h.N));
fprintf('  Hs roll-up bias: median(Hs_energy - Hs_lin) = %+.4f m\n', ...
    median(h.Hs_energy - h.Hs_lin, 'omitnan'));
fprintf('\n  Variable      median CV    p90 CV    median range\n');
fprintf('  ----------    ---------    ------    ------------\n');
for iV = 1:size(flatVars, 1)
    nm = flatVars{iV, 1};
    disp_nm = flatVars{iV, 2};
    units = flatVars{iV, 3};
    cv = h.(nm).cv;
    rg = h.(nm).range;
    fprintf('  %-12s  %8.3f    %6.3f    %6.3f %s\n', disp_nm, ...
        median(cv, 'omitnan'), prctile(cv, 90), median(rg, 'omitnan'), units);
end

% Stratified medians for Hs CV
fprintf('\n  Hs CV stratified:\n');
states = ["calm", "mixed", "storm"];
for s = states
    m = h.seaState == s;
    if any(m)
        fprintf('    %-6s (N=%4d)  median CV(Hs) = %.3f, p90 = %.3f\n', ...
            s, sum(m), median(h.Hs.cv(m), 'omitnan'), prctile(h.Hs.cv(m), 90));
    end
end
rates = ["slack", "mid", "fast"];
fprintf('\n  Hs CV by tidal rate:\n');
for r = rates
    m = h.tideRate == r;
    if any(m)
        fprintf('    %-6s (N=%4d)  median CV(Hs) = %.3f, p90 = %.3f\n', ...
            r, sum(m), median(h.Hs.cv(m), 'omitnan'), prctile(h.Hs.cv(m), 90));
    end
end
end


% ============================================================
function make_figures(label, h, figDir)
% Histograms of CV
f1 = figure('Visible','off','Position',[100 100 1300 800]);
plotVars = {'Hs','Hs_SS','Hs_IG','Tp','Tm02','depth','uMean','vMean','skewness','asymmetry'};
for k = 1:numel(plotVars)
    nm = plotVars{k};
    if ~isfield(h, nm), continue; end
    subplot(3, 4, k);
    cv = h.(nm).cv;
    cv = cv(~isnan(cv));
    if isempty(cv), continue; end
    histogram(cv, linspace(0, prctile(cv, 99), 30));
    xline(median(cv), 'r-', 'LineWidth', 1.2);
    title(sprintf('%s   med=%.3f', nm, median(cv)), 'Interpreter','none');
    xlabel('within-hour CV'); ylabel('hours');
    grid on;
end
sgtitle(sprintf('%s — within-hour coefficient of variation', label), 'Interpreter','none');
saveas(f1, fullfile(figDir, sprintf('%s_cv_histograms.png', label)));
close(f1);

% Scatter: CV(Hs) vs |dh/dt| and vs mean Hs
f2 = figure('Visible','off','Position',[100 100 1100 400]);
subplot(1,3,1);
scatter(h.dhdt, h.Hs.cv, 14, 'filled', 'MarkerFaceAlpha', 0.4);
xlabel('|dh/dt| (m/hr)'); ylabel('CV(H_s) within hour');
title('Stationarity vs tidal rate'); grid on;

subplot(1,3,2);
scatter(h.Hs.mean, h.Hs.cv, 14, 'filled', 'MarkerFaceAlpha', 0.4);
xlabel('mean H_s (m)'); ylabel('CV(H_s) within hour');
title('Stationarity vs sea state'); grid on;

subplot(1,3,3);
scatter(h.Hs_lin, h.Hs_energy - h.Hs_lin, 14, 'filled', 'MarkerFaceAlpha', 0.4);
xlabel('H_s linear-avg (m)'); ylabel('H_{s,energy} - H_{s,lin} (m)');
title('Hs roll-up bias'); grid on; yline(0, 'k:');

sgtitle(sprintf('%s — stationarity drivers', label), 'Interpreter','none');
saveas(f2, fullfile(figDir, sprintf('%s_cv_drivers.png', label)));
close(f2);

% Timeseries: hourly Hs_energy with band of [min, max] of within-hour 17-min Hs
f3 = figure('Visible','off','Position',[100 100 1300 500]);
ax1 = subplot(2,1,1);
plot(h.time, h.Hs_energy, 'k-', 'LineWidth', 0.8); hold on;
hi = h.Hs.mean + h.Hs.std;
lo = max(h.Hs.mean - h.Hs.std, 0);
patch([h.time; flipud(h.time)], [lo; flipud(hi)], 'r', ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none');
ylabel('H_s (m)'); title(sprintf('%s — hourly H_s with within-hour ±1\\sigma band', label), 'Interpreter','none');
grid on;

ax2 = subplot(2,1,2);
plot(h.time, h.Hs.cv, 'b.', 'MarkerSize', 6); hold on;
yline(0.05, 'k--'); yline(0.10, 'r--');
ylabel('CV(H_s)'); xlabel('time'); grid on;
title('Within-hour CV(H_s) — dashed: 5% (good), 10% (concern)');
linkaxes([ax1, ax2], 'x');

saveas(f3, fullfile(figDir, sprintf('%s_timeseries.png', label)));
close(f3);

fprintf('  Figures saved to %s\n', figDir);
end


% ============================================================
function r = circ_range_deg(x_deg)
% Smallest arc covering all samples, returned in degrees.
th = mod(x_deg(:), 360);
th = sort(th);
gaps = [diff(th); 360 - (th(end) - th(1))];
r = 360 - max(gaps);
end
