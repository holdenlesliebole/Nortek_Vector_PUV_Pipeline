% RUN_RETENTION_SWEEP  P(PUV hour survives QC | model Hs), every record.
%
% Rule 7 (AnalysisDeliberationGuardrails): missing data is a variable, and
% here the missingness is caused by the forcing -- the conditioning axis is
% the MODEL Hs, which exists for every hour regardless of whether the PUV
% survived it. compare_derived_quantities computes this per record but the
% consequences sweep strips it; this standalone sweep saves it for the
% appendix retention figure (A2, todo #39) and for fig02's caveat.
%
% Per record: hourly model Hs from THREDDS, matched to the L2 segment grid
% (30-min tolerance); valid = L2.segValid at the matched hour. Saved:
% per-record retention in fixed Hs bins, rho(valid, Hs) point-biserial,
% and the pooled (Hs, valid, record-index) arrays.
%
% Output: outputs/validation/retention_sweep.mat.  THREDDS per record.
% Run from PUV_Pipeline/:  >> run validation/run_retention_sweep
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0 = tic;

EDGES = [0 0.5 1.0 1.5 2.0 2.5 3.0 6.0];

reg   = deployment_registry();
names = sort(keys(reg));
seen  = containers.Map('KeyType','char','ValueType','logical');

REC = struct('rec', {}, 'station', {}, 'nModelHr', {}, 'nValid', {}, ...
    'retBin', {}, 'nBin', {}, 'rho', {}, 'p', {}, 'excluded', {});
pooled = struct('Hs', [], 'valid', [], 'rec', []);

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        rec = [cfg.name '/' lab];
        S2 = load(fullfile(fl(k).folder, fl(k).name), 'L2'); L2 = S2.L2;

        station = '';
        if isfield(L2,'refStation') && ~isempty(L2.refStation),     station = L2.refStation;
        elseif isfield(L2,'mopStation') && ~isempty(L2.mopStation), station = L2.mopStation;
        end
        if isempty(station), fprintf('[skip] %s: no station\n', rec); continue; end

        v  = logical(L2.segValid(:));
        tL = L2.time(:); if isempty(tL.TimeZone), tL.TimeZone = 'UTC'; end
        try
            MOP = read_MOPline2(station, min(tL), max(tL));
        catch ME
            fprintf('[skip] %s: THREDDS: %s\n', rec, ME.message); continue
        end
        if isempty(MOP.time), fprintf('[skip] %s: no model data\n', rec); continue; end

        tM = MOP.time(:); if isempty(tM.TimeZone), tM.TimeZone = tL.TimeZone; end
        % model hour -> nearest L2 segment; unmatched model hours are hours
        % the PUV did not even record; retention is defined on the deployed
        % span, so restrict to model hours inside the L2 time range.
        in = tM >= min(tL) - minutes(30) & tM <= max(tL) + minutes(30);
        tM = tM(in);
        HsM = double(MOP.Hs(in)); HsM = HsM(:);
        iL  = interp1(tL, (1:numel(tL))', tM, 'nearest', 'extrap');
        ok  = abs(tL(iL) - tM) <= minutes(30);
        val = false(numel(tM),1);
        val(ok) = v(iL(ok));       % an unmatched model hour = not retained

        gg = isfinite(HsM);
        HsM = HsM(gg); val = val(gg);

        retBin = NaN(1, numel(EDGES)-1); nBin = zeros(1, numel(EDGES)-1);
        for b = 1:numel(EDGES)-1
            m = HsM >= EDGES(b) & HsM < EDGES(b+1);
            nBin(b) = sum(m);
            if nBin(b) >= 10, retBin(b) = mean(val(m)); end
        end
        [rho, p] = corr(double(val), HsM, 'type', 'Spearman');

        REC(end+1) = struct('rec', rec, 'station', station, ...
            'nModelHr', numel(HsM), 'nValid', sum(val), ...
            'retBin', retBin, 'nBin', nBin, 'rho', rho, 'p', p, ...
            'excluded', excluded_records(cfg.name, lab)); %#ok<SAGROW>
        pooled.Hs    = [pooled.Hs;    HsM];
        pooled.valid = [pooled.valid; val];
        pooled.rec   = [pooled.rec;   repmat(numel(REC), numel(HsM), 1)];

        fprintf('%-22s n=%5d  kept %4.0f%%  rho(valid,Hs)=%+5.2f (p=%.2g)\n', ...
            rec, numel(HsM), 100*mean(val), rho, p);
    end
end

use = ~[REC.excluded];
fprintf('\n================ RETENTION SWEEP (n = %d) ================\n', sum(use));
fprintf('median rho(valid, model Hs) = %+.3f; records with rho < -0.1: %d of %d\n', ...
    median([REC(use).rho], 'omitnan'), sum([REC(use).rho] < -0.1), sum(use));
retPool = NaN(1, numel(EDGES)-1);
for b = 1:numel(EDGES)-1
    m = pooled.Hs >= EDGES(b) & pooled.Hs < EDGES(b+1);
    if sum(m) >= 50, retPool(b) = mean(pooled.valid(m)); end
end
fprintf('pooled retention by Hs bin: %s\n', mat2str(round(100*retPool)));

meta = struct('created', datetime('now'), 'edges', EDGES, ...
    'elapsed_min', toc(t0)/60, 'note', ...
    'P(PUV valid | model Hs) per record; Rule 7 appendix figure A2 input.');
save(fullfile(root, 'validation', 'retention_sweep.mat'), 'REC', 'pooled', 'meta');
fprintf('saved outputs/validation/retention_sweep.mat (%.1f min)\n', meta.elapsed_min);
