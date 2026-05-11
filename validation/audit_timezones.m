% AUDIT_TIMEZONES  Per-deployment clock-timezone audit against NOAA tide gauge.
%
%   Loops over every deployment in deployment_registry, picks the
%   representative instrument (most valid L2 segments), and cross-
%   correlates a 14-day window of L2 segment-mean depth against the
%   NOAA Scripps Pier tide-gauge prediction (station 9410230, UTC).
%
%   For each deployment the optimal cross-correlation lag is reported:
%     |lag| < 1 hr            -> UTC (PASS)
%     6.5 hr < lag < 8.5 hr   -> PDT/PST (FAIL: clock set to local time)
%     anything else           -> CHECK (manual review)
%
%   Output: console table + outputs/_logs/timezone_audit_<YYYYMMDD>.txt
%   plus outputs/_logs/timezone_audit_<YYYYMMDD>.csv
%
%   NOTES
%   - Uses L2 (not L3) so the audit is independent of t_tide success.
%   - Scripps Pier (9410230) is used for all deployments. The Catalina
%     deployments (~120 km offshore) have ~minutes of M2 phase offset
%     from Scripps, which is negligible compared to the ~7 hr lag
%     expected for a PDT clock — the UTC/local distinction is robust.
%   - 14-day window picks the centermost interval of each deployment to
%     avoid leading/trailing-edge QC dropouts.
%   - Requires getztide2.m on the MATLAB path (toolbox/).
% Author: Holden Leslie-Bole, 2026

%% ======================== SETUP ========================
startup_puv

toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
if ~exist('getztide2', 'file'), addpath(toolboxPath); end
if ~exist('getztide2', 'file')
    error('audit_timezones:missingDep', ...
        'getztide2.m not found on path (expected at %s).', toolboxPath);
end

logsDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', '_logs');
if ~exist(logsDir, 'dir'), mkdir(logsDir); end

windowDays = 14;

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' Timezone audit — %d deployments, %d-day window each\n', nDeploy, windowDays);
fprintf(' Reference: NOAA Scripps Pier (9410230), UTC\n');
fprintf('========================================\n');

%% ======================== PER-DEPLOYMENT AUDIT ========================
rows = cell(nDeploy, 1);

for d = 1:nDeploy
    dName = deployNames{d};
    row.deployment  = dName;
    row.instrument  = '';
    row.t_start     = NaT;
    row.t_end       = NaT;
    row.n_valid     = 0;
    row.lag_hours   = NaN;
    row.R_at_lag    = NaN;
    row.R_zero      = NaN;
    row.status      = 'pending';
    row.note        = '';

    try
        configFn = registry(dName);
        cfg      = configFn();
    catch ME
        row.status = 'config_error';
        row.note   = ME.message;
        rows{d}    = row;
        fprintf('\n[%2d/%2d] %-10s  ERROR: %s\n', d, nDeploy, dName, ME.message);
        continue
    end

    l2Dir   = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l2Dir)
        row.status = 'no_L2_dir';
        rows{d}    = row;
        fprintf('\n[%2d/%2d] %-10s  SKIP: no L2 directory\n', d, nDeploy, dName);
        continue
    end
    l2Files = dir(fullfile(l2Dir, '*_L2.mat'));
    if isempty(l2Files)
        row.status = 'no_L2_files';
        rows{d}    = row;
        fprintf('\n[%2d/%2d] %-10s  SKIP: no L2 files\n', d, nDeploy, dName);
        continue
    end

    % Pick instrument with most valid segments
    nValidPer = zeros(numel(l2Files), 1);
    L2_cache  = cell(numel(l2Files), 1);
    for k = 1:numel(l2Files)
        try
            ldd = load(fullfile(l2Dir, l2Files(k).name), 'L2');
            L2_cache{k} = ldd.L2;
            if isfield(ldd.L2, 'segValid')
                nValidPer(k) = sum(ldd.L2.segValid);
            end
        catch
            nValidPer(k) = 0;
        end
    end
    [~, kBest] = max(nValidPer);
    L2 = L2_cache{kBest};
    row.instrument = regexprep(l2Files(kBest).name, '_L2\.mat$', '');
    row.n_valid    = nValidPer(kBest);

    if row.n_valid < 24
        row.status = 'too_few_segments';
        row.note   = sprintf('only %d valid segments', row.n_valid);
        rows{d}    = row;
        fprintf('\n[%2d/%2d] %-10s  SKIP: %s\n', d, nDeploy, dName, row.note);
        continue
    end

    % Pick 14-day window centered in deployment
    validIdx = find(L2.segValid);
    tValid   = L2.time(validIdx);
    midT     = tValid(round(numel(tValid)/2));
    wHalf    = days(windowDays/2);
    tWinStart = midT - wHalf;
    tWinEnd   = midT + wHalf;
    inWin     = tValid >= tWinStart & tValid <= tWinEnd;
    if sum(inWin) < 24
        % Fall back to whatever we have if 14-day window is too sparse
        inWin = true(size(tValid));
    end
    winIdx = validIdx(inWin);
    row.t_start = L2.time(winIdx(1));
    row.t_end   = L2.time(winIdx(end));

    %% Fetch NOAA prediction for the window
    fprintf('\n[%2d/%2d] %-10s  %s (%d valid segs, window %s -> %s)\n', ...
            d, nDeploy, dName, row.instrument, sum(inWin), ...
            datestr(row.t_start, 'yyyy-mm-dd'), datestr(row.t_end, 'yyyy-mm-dd'));

    try
        [pt, ph] = getztide2(datenum(row.t_start - days(1)), ...
                             datenum(row.t_end   + days(1)), ...
                             'gmt', 'msl', 'predictions');
    catch ME
        row.status = 'noaa_fetch_failed';
        row.note   = ME.message;
        rows{d}    = row;
        fprintf('  NOAA fetch failed: %s\n', ME.message);
        continue
    end

    if isempty(ph)
        row.status = 'noaa_empty';
        rows{d}    = row;
        fprintf('  NOAA returned empty result\n');
        continue
    end

    noaa_dt  = datetime(pt, 'InputFormat', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
    noaa_hgt = double(ph);
    [noaa_dt, iU] = unique(noaa_dt);
    noaa_hgt = noaa_hgt(iU);

    %% Cross-correlate L2.depth anomaly vs NOAA prediction
    puv_t     = L2.time(winIdx);
    puv_depth = L2.depth(winIdx);
    if isempty(puv_t.TimeZone), puv_t.TimeZone = 'UTC'; end
    puv_anom = puv_depth - mean(puv_depth, 'omitnan');

    noaa_at_puv = interp1(noaa_dt, noaa_hgt, puv_t, 'linear', NaN);

    good = ~isnan(puv_anom) & ~isnan(noaa_at_puv);
    if sum(good) < 24
        row.status = 'too_few_after_interp';
        row.note   = sprintf('only %d good samples', sum(good));
        rows{d}    = row;
        fprintf('  Skip: only %d good samples after interp\n', sum(good));
        continue
    end

    Rz = corrcoef(puv_anom(good), noaa_at_puv(good));
    row.R_zero = Rz(1, 2);

    dt_hr  = hours(median(diff(puv_t)));
    maxLag = round(12 / dt_hr);
    [xcf, lags] = xcorr(puv_anom(good) - mean(puv_anom(good)), ...
                        noaa_at_puv(good) - mean(noaa_at_puv(good)), ...
                        maxLag, 'coeff');
    [Rmax, iMax] = max(xcf);
    lagHr = lags(iMax) * dt_hr;
    row.lag_hours = lagHr;
    row.R_at_lag  = Rmax;

    if abs(lagHr) < 1
        row.status = 'UTC';
    elseif abs(lagHr - 7) < 1.5 || abs(lagHr - 8) < 1.5
        row.status = 'PDT_or_PST';
    elseif abs(lagHr + 7) < 1.5 || abs(lagHr + 8) < 1.5
        row.status = 'PDT_or_PST';
    else
        row.status = 'CHECK';
    end

    fprintf('  R_zero=%.3f, peak R=%.3f @ %+.1f hr  ->  %s\n', ...
            row.R_zero, row.R_at_lag, row.lag_hours, row.status);

    rows{d} = row;
end

%% ======================== SUMMARY ========================
fprintf('\n\n========================================\n');
fprintf(' Audit summary\n');
fprintf('========================================\n');
fprintf('  %-10s  %-20s  %-12s  %6s  %6s  %s\n', ...
        'Deploy', 'Instrument', 'Status', 'lag_hr', 'R', 'note');
fprintf('  %s\n', repmat('-', 1, 95));
for d = 1:nDeploy
    r = rows{d};
    if isempty(r), continue, end
    fprintf('  %-10s  %-20s  %-12s  %6.2f  %6.3f  %s\n', ...
        r.deployment, r.instrument, r.status, r.lag_hours, r.R_at_lag, r.note);
end

%% ======================== SAVE CSV ========================
stamp = datestr(now, 'yyyymmdd_HHMMSS');
csvPath = fullfile(logsDir, ['timezone_audit_' stamp '.csv']);

T = table('Size', [nDeploy, 9], ...
    'VariableTypes', {'string','string','datetime','datetime','double', ...
                      'double','double','double','string'}, ...
    'VariableNames', {'deployment','instrument','t_start','t_end','n_valid', ...
                      'lag_hours','R_at_lag','R_zero','status'});
for d = 1:nDeploy
    r = rows{d};
    if isempty(r), continue, end
    T.deployment(d)  = string(r.deployment);
    T.instrument(d)  = string(r.instrument);
    T.t_start(d)     = r.t_start;
    T.t_end(d)       = r.t_end;
    T.n_valid(d)     = r.n_valid;
    T.lag_hours(d)   = r.lag_hours;
    T.R_at_lag(d)    = r.R_at_lag;
    T.R_zero(d)      = r.R_zero;
    T.status(d)      = string(r.status);
end
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

%% ======================== FLAGGED INSTRUMENT LIST ========================
nFail = sum(strcmp(T.status, 'PDT_or_PST'));
nCheck = sum(strcmp(T.status, 'CHECK'));
nPass  = sum(strcmp(T.status, 'UTC'));
fprintf('\nResults: %d UTC / %d PDT-or-PST / %d CHECK / %d other.\n', ...
        nPass, nFail, nCheck, nDeploy - nPass - nFail - nCheck);
if nFail + nCheck > 0
    fprintf('Instruments needing review:\n');
    flagged = strcmp(T.status, 'PDT_or_PST') | strcmp(T.status, 'CHECK');
    disp(T(flagged, {'deployment','instrument','status','lag_hours','R_at_lag'}));
end
