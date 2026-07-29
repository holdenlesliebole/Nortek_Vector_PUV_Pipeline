% RUN_BULK_VALIDATION_SWEEP  Catalog-wide bulk comparison, PUV vs shoaled MOP.
%
%   run_bulk_validation_sweep
%
% compare_PUV_MOP already computes everything needed per record (R^2, RMSE,
% bias, Willmott skill, N for Hs / Tm / Ef, plus the paired hourly series).
% run_PUV_MOP_validation.m only ever ran it on one hardcoded deployment. This
% walks the whole registry and saves the result so the paper figure can be built
% offline.
%
% SAVES BOTH the per-record statistics AND the paired series. The per-record
% statistics are the honest summary -- records contribute very unequally, and a
% pooled cloud is dominated by the long ones -- but the pooled scatter is what
% shows a reader that the agreement is real rather than an average of
% compensating errors. The figure shows both.
%
% Note the variables: Hs, Tm (Tm02) and Ef. compare_PUV_MOP does not return peak
% period or direction, so those are not available here.
%
% Output: outputs/validation/cross_deployment_bulk.mat
% Author: Holden Leslie-Bole, 2026

startup_puv

outDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
reg   = deployment_registry();
names = sort(keys(reg));

ROWS = struct([]); SKIP = struct([]); POOL = struct('Hs_puv',[],'Hs_mop',[], ...
    'Tm_puv',[],'Tm_mop',[],'Ef_puv',[],'Ef_mop',[],'rec',[]);
seen = containers.Map('KeyType','char','ValueType','logical');
t0 = tic; nAtt = 0;

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen,cfg.name), continue; end
    seen(cfg.name) = true;

    for k = 1:numel(cfg.instruments)
        lab = cfg.instruments(k).label;
        f2  = fullfile(cfg.outputDir,'L2',cfg.name,[lab '_L2.mat']);
        if ~isfile(f2), continue; end
        nAtt = nAtt + 1;
        fprintf('  %-9s %-13s ', cfg.name, lab);
        try
            w = load(f2,'L2'); L2 = w.L2;
            if sum(L2.segValid) < 20
                SKIP(end+1).deployment = cfg.name; SKIP(end).label = lab; %#ok<SAGROW>
                SKIP(end).status = sprintf('only %d valid segments', sum(L2.segValid));
                fprintf('skip (%d valid segs)\n', sum(L2.segValid)); continue
            end
            R = compare_PUV_MOP(L2);
        catch ME
            SKIP(end+1).deployment = cfg.name; SKIP(end).label = lab; %#ok<SAGROW>
            SKIP(end).status = ME.message;
            fprintf('FAIL: %s\n', ME.message); continue
        end
        close all

        i = numel(ROWS) + 1;
        ROWS(i).deployment = cfg.name;
        ROWS(i).label      = lab;
        ROWS(i).h_median   = median(L2.depth(L2.segValid),'omitnan');
        for v = {'Hs','Tm','Ef'}
            vn = v{1};
            if isfield(R.stats, vn)
                ROWS(i).([vn '_R2'])    = R.stats.(vn).R2;
                ROWS(i).([vn '_RMSE'])  = R.stats.(vn).RMSE;
                ROWS(i).([vn '_bias'])  = R.stats.(vn).bias;
                ROWS(i).([vn '_skill']) = R.stats.(vn).skill;
                ROWS(i).([vn '_N'])     = R.stats.(vn).N;
            end
        end
        % pooled paired series, tagged by record so the figure can weight or
        % subset by record rather than treating 65k hours as independent
        n = numel(R.Hs_puv);
        POOL.Hs_puv = [POOL.Hs_puv; R.Hs_puv(:)];
        POOL.Hs_mop = [POOL.Hs_mop; R.Hs_mop(:)];
        POOL.Tm_puv = [POOL.Tm_puv; R.Tm_puv(:)];
        POOL.Tm_mop = [POOL.Tm_mop; R.Tm_mop(:)];
        POOL.Ef_puv = [POOL.Ef_puv; R.Ef_puv(:)];
        POOL.Ef_mop = [POOL.Ef_mop; R.Ef_mop(:)];
        POOL.rec    = [POOL.rec;    repmat(i,n,1)];

        fprintf('Hs R2 %.2f bias %+.3f | Tm R2 %.2f | Ef R2 %.2f  (n=%d)\n', ...
            ROWS(i).Hs_R2, ROWS(i).Hs_bias, ROWS(i).Tm_R2, ROWS(i).Ef_R2, ROWS(i).Hs_N);
    end
end

elapsed = toc(t0);
meta = struct('created', datestr(now,'yyyy-mm-dd HH:MM:SS'), ...
              'nAttempted', nAtt, 'nSucceeded', numel(ROWS), ...
              'elapsed_min', elapsed/60, ...
              'note','Bulk PUV vs shoaled MOP. Variables Hs, Tm02, Ef.'); %#ok<TNOW1,DATST>
save(fullfile(outDir,'cross_deployment_bulk.mat'),'ROWS','SKIP','POOL','meta');
fprintf('\nSaved: %s  (%d records, %.1f min)\n', ...
    fullfile(outDir,'cross_deployment_bulk.mat'), numel(ROWS), elapsed/60);

if ~isempty(ROWS)
    pr = @(n,v) fprintf('  %-14s %7.3f  [IQR %6.3f - %6.3f]  n=%d\n', n, ...
        median(v,'omitnan'), prctile(v,25), prctile(v,75), sum(isfinite(v)));
    fprintf('\n--- Cross-catalog bulk skill ---\n');
    for v = {'Hs','Tm','Ef'}
        vn = v{1};
        pr([vn ' R^2'],    [ROWS.([vn '_R2'])]');
        pr([vn ' skill'],  [ROWS.([vn '_skill'])]');
        pr([vn ' bias'],   [ROWS.([vn '_bias'])]');
    end
    fprintf('  pooled hours: %d\n', numel(POOL.Hs_puv));
end
if ~isempty(SKIP)
    fprintf('\n--- Skipped: %d ---\n', numel(SKIP));
    for i = 1:numel(SKIP)
        fprintf('  %-9s %-14s %s\n', SKIP(i).deployment, SKIP(i).label, SKIP(i).status);
    end
end
