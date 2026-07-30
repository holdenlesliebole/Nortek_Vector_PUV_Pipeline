% ASSEMBLE_CHUNKED_BETA  Merge the #62 shard outputs and summarize beta(Hs/h).
%
% Run after all run_chunked_beta_catalog shards finish:
%   >> run validation/assemble_chunked_beta
%
% Merges outputs/validation/chunked_beta_shard_*.mat ->
% chunked_beta_catalog.mat and prints:
%   - per-chunk beta(Hs/h) binned on the paper's Hs/h edges (the
%     bound-fraction counterpart of the threshold hierarchy);
%   - per-record chunk-median beta vs the record-level (storm-weighted)
%     beta from bispectral_beta.mat -- the size of the nonstationarity
%     bias found on COR16B (findings_cor16b_2026-07-30.md), now catalog-wide.
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

fl = dir(fullfile(root, 'validation', 'chunked_beta_shard_*.mat'));
assert(~isempty(fl), 'no shard files found');
OUT = [];
for k = 1:numel(fl)
    S = load(fullfile(fl(k).folder, fl(k).name));
    OUT = [OUT, S.OUT]; %#ok<AGROW>
    fprintf('%s: %d chunk rows\n', fl(k).name, numel(S.OUT));
end
nRec = numel(unique({OUT.rec}));
fprintf('merged: %d chunks over %d records\n', numel(OUT), nRec);

% keep only closed chunks and non-excluded records
ok = [OUT.closure] < 1e-6;
excl = false(size(OUT));
for i = 1:numel(OUT)
    tok = strsplit(OUT(i).rec, '/');
    excl(i) = excluded_records(tok{1}, tok{2});
end
C = OUT(ok & ~excl);
fprintf('usable: %d chunks (%d closure-flagged, %d excluded-record)\n', ...
    numel(C), sum(~ok), sum(excl));

% beta(Hs/h), chunk-level
edges = [0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
hsh = [C.hsh_med]; b = [C.beta_net];
fprintf('\nbeta_net(Hs/h), chunk-level medians:\n');
for j = 1:numel(edges)-1
    m = hsh >= edges(j) & hsh < edges(j+1);
    if sum(m) < 8, continue; end
    fprintf('  %.2f-%.2f: median %.4f  IQR [%.4f %.4f]  (n=%d)\n', ...
        edges(j), edges(j+1), median(b(m)), quantile(b(m),0.25), quantile(b(m),0.75), sum(m));
end

% nonstationarity bias, catalog-wide
B = load(fullfile(root, 'validation', 'bispectral_beta.mat'));
recs = unique({C.rec});
cmp = NaN(numel(recs), 2);
for i = 1:numel(recs)
    m = strcmp({C.rec}, recs{i});
    j = find(strcmp({B.R.rec}, recs{i}), 1);
    if isempty(j), continue; end
    cmp(i,:) = [median([C(m).beta_net]), B.R(j).beta_ss_net];
end
g = all(isfinite(cmp), 2);
fprintf('\nrecord-level (storm-weighted) vs chunk-median beta: median ratio %.3f, IQR [%.3f %.3f]\n', ...
    median(cmp(g,2)./cmp(g,1)), quantile(cmp(g,2)./cmp(g,1),0.25), quantile(cmp(g,2)./cmp(g,1),0.75));
fprintf('records where record-level exceeds the chunk MAX (the COR16B signature): %d of %d\n', ...
    sum(arrayfun(@(i) g(i) && cmp(i,2) > max([C(strcmp({C.rec},recs{i})).beta_net]), 1:numel(recs))), sum(g));

meta = struct('created', datetime('now'), 'nChunks', numel(C), 'nRecords', nRec, ...
    'note', 'Merged #62 shards; chunk-level beta removes the amplitude^3 storm weighting.');
save(fullfile(root, 'validation', 'chunked_beta_catalog.mat'), 'OUT', 'C', 'meta');
fprintf('\nsaved outputs/validation/chunked_beta_catalog.mat\n');
