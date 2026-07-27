% AUDIT_ZTEST_RECORDS  Record-level pressure/velocity (Z) check across the catalog.
%
%   For every registered record, reduces the per-segment Z diagnostic to one
%   number (median over valid segments) and flags records outside the published
%   0.5 < Z < 2 retention window. See shared/ztest_record_flag.m for the
%   rationale; this script and PUV_L2_spectral use that same helper, so the
%   pipeline and the audit cannot drift apart.
%
%   Works on L2 files as they are on disk -- it does NOT require an L2 rebuild.
%   Records built before 2026-07-27 have no `L2.qc_record` field; for those the
%   verdict is computed here from the stored per-segment `ztest_SS`.
%
%   It also re-checks the signature of the Z formula bug fixed 2026-06-05
%   (predicted pressure had (gk/omega)^2*cosh^2 instead of (omega/gk)^2, giving
%   a monotonic depth dependence: median Z 0.33 at 5 m rising to 2.8 at 15 m).
%   A catalog-level r(Z, depth) near zero is the regression guard. NOTE that
%   this correlation must be computed with flagged records EXCLUDED: a single
%   dead record at depth (RUBY22/MOP582_30m, Z~1e-4 at 30.6 m) drags r from
%   -0.02 to -0.78 on its own and looks exactly like a depth trend.
%
%   Run from PUV_Pipeline/:
%     >> run validation/audit_ztest_records

startup_puv;

root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
reg  = deployment_registry(); names = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');

fprintf('\n%-9s %-13s %8s %8s %7s %7s  %s\n', ...
    'deploy','label','medZ_SS','medZ_IG','nSeg','depth','status');
fprintf('%s\n', repmat('-', 1, 78));

flagged = {}; insufficient = {};
zAll = []; dAll = []; nRec = 0;

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        rec = [cfg.name '/' lab];
        S = load(fullfile(fl(k).folder, fl(k).name), 'L2'); L2 = S.L2;
        nRec = nRec + 1;

        % Prefer the stored verdict when the record was built with one.
        if isfield(L2, 'qc_record') && isfield(L2.qc_record, 'ztest_SS')
            qSS = L2.qc_record.ztest_SS;
        else
            qSS = ztest_record_flag(L2.ztest_SS, L2.segValid);
        end
        qIG = ztest_record_flag(L2.ztest_IG, L2.segValid);

        medDepth = median(L2.depth(L2.segValid), 'omitnan');
        fprintf('%-9s %-13s %8.4f %8.4f %7d %7.1f  %s\n', ...
            cfg.name, lab, qSS.median, qIG.median, qSS.n, medDepth, qSS.status);

        switch qSS.status
            case 'FLAG'
                flagged{end+1} = sprintf('%s -- %s', rec, qSS.reason); %#ok<SAGROW>
            case 'insufficient'
                insufficient{end+1} = sprintf('%s -- %s', rec, qSS.reason); %#ok<SAGROW>
            otherwise
                zAll(end+1) = qSS.median;   %#ok<SAGROW>
                dAll(end+1) = medDepth;     %#ok<SAGROW>
        end
    end
end

fprintf('\n%d records inspected\n', nRec);

fprintf('\nFLAGGED (%d):\n', numel(flagged));
for i = 1:numel(flagged), fprintf('  %s\n', flagged{i}); end
if isempty(flagged), fprintf('  none\n'); end

fprintf('\nInsufficient data for a verdict (%d) -- not a failure:\n', numel(insufficient));
for i = 1:numel(insufficient), fprintf('  %s\n', insufficient{i}); end
if isempty(insufficient), fprintf('  none\n'); end

if numel(zAll) > 2
    fprintf('\nPassing records (n=%d):\n', numel(zAll));
    fprintf('  median of per-record median Z : %.4f\n', median(zAll));
    fprintf('  IQR                           : %.4f - %.4f\n', ...
        prctile(zAll, 25), prctile(zAll, 75));
    fprintf('  range                         : %.4f - %.4f\n', min(zAll), max(zAll));
    r = corr(zAll(:), dAll(:), 'rows', 'complete');
    fprintf('  r(median Z, depth)            : %+.3f', r);
    if abs(r) < 0.3
        fprintf('   OK -- no depth dependence (2026-06-05 formula bug stays fixed)\n');
    else
        fprintf(2, '   *** CHECK: depth dependence has reappeared ***\n');
    end
end
fprintf('\n');
