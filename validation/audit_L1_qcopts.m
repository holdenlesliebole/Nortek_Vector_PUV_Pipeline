% AUDIT_L1_QCOPTS  Does each L1 on disk match what its config would produce now?
%
%   For every registered instrument, compares the per-channel QC options
%   stored in its L1 (PUV.qc.opts) against l1_qc_opts(cfg), the struct
%   PUV_raw_process would build from the config today. Any difference means
%   a rebuild through PUV_L1_run_all / PUV_L1_driver would silently change
%   the record.
%
%   Why this exists: rerun_all_deployments_2026_07_11 and
%   rerun_parameterized_configs_2026_07_11 injected cfg.qcOpts.Tvalid = [9 26]
%   whenever a config left it unset, and the canonical L1 was built that way.
%   Twelve config files did not set it, so every ordinary rebuild used the
%   PUV_raw_process default [-2 40] instead. Rebuilding LPL24/LPL_8m from its
%   config on 2026-10-07 kept 9,927 extra post-recovery temperature samples
%   (~26 degC). The configs now set it on the line; this audit keeps them
%   honest.
%
%   Reported per record:
%     ok        stored opts equal the config's effective opts (isequaln, per field)
%     DIFFERS   at least one field differs or exists on only one side
%     NO OPTS   the L1 predates PUV.qc.opts (channel decoupling, 2026-07-09);
%               what it was built with cannot be read back from the file
%     no L1     nothing on disk (an instrument that never produced output)
%   A config that throws is a FAILURE here, not a skip.
%
%   Loads every L1 in full (~21 GB, several minutes). To check a subset, set
%   onlyDeps = {'SOL24','LPL24'} in the workspace before running.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv

reg   = deployment_registry();
names = sort(keys(reg));
if exist('onlyDeps','var') && ~isempty(onlyDeps)
    names = intersect(names, onlyDeps);
end
outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

nOk = 0; differs = {}; noOpts = {}; noL1 = {}; bad = {};
seen = containers.Map('KeyType','char','ValueType','logical');

fprintf('\n=== L1 qc.opts vs config: %d registry entries ===\n', numel(names));
for i = 1:numel(names)
    try
        f = reg(names{i}); c = f();
    catch ME
        bad(end+1,:) = {names{i}, ME.message}; %#ok<SAGROW>
        continue
    end
    if isKey(seen, c.name), continue, end      % aliases (TOR23S -> TBR23)
    seen(c.name) = true;
    want = l1_qc_opts(c);
    for j = 1:numel(c.instruments)
        rec = [c.name '/' c.instruments(j).label];
        fn  = fullfile(outRoot, 'L1', c.name, [c.instruments(j).label '_processed.mat']);
        if ~isfile(fn), noL1{end+1} = rec; continue, end %#ok<SAGROW>
        S = load(fn, 'PUV');
        if ~isfield(S.PUV,'qc') || ~isfield(S.PUV.qc,'opts')
            noOpts{end+1} = rec; continue %#ok<SAGROW>
        end
        d = opts_diff(S.PUV.qc.opts, want);
        if isempty(d)
            nOk = nOk + 1;
        else
            differs(end+1,:) = {rec, d}; %#ok<SAGROW>
        end
    end
end

nChecked = nOk + size(differs,1);
fprintf('%d/%d L1 records match their config\n', nOk, nChecked);
if ~isempty(differs)
    fprintf(2, '\n%d L1 RECORDS DIFFER FROM WHAT THEIR CONFIG NOW PRODUCES\n', size(differs,1));
    fprintf(2, '(field: stored on disk -> config now):\n');
    for i = 1:size(differs,1), fprintf(2, '  %-22s %s\n', differs{i,1}, differs{i,2}); end
end
if ~isempty(noOpts)
    fprintf('\n%d L1 records store no qc.opts (pre-2026-07-09 build; unverifiable):\n', numel(noOpts));
    fprintf('  %s\n', noOpts{:});
end
if ~isempty(noL1)
    fprintf('\n%d configured instruments have no L1 on disk:\n', numel(noL1));
    fprintf('  %s\n', noL1{:});
end
if ~isempty(bad)
    fprintf(2, '\n%d ENTRIES FAIL TO BUILD (not audited):\n', size(bad,1));
    for i = 1:size(bad,1), fprintf(2, '  %-10s %s\n', bad{i,1}, bad{i,2}); end
end

function s = opts_diff(have, want)
% One string listing every field that differs; '' if none.
    f = union(fieldnames(have), fieldnames(want), 'stable');
    parts = {};
    for k = 1:numel(f)
        inH = isfield(have, f{k});  inW = isfield(want, f{k});
        if inH && inW && isequaln(have.(f{k}), want.(f{k})), continue, end
        a = '(absent)'; b = '(absent)';
        if inH, a = mat2str(have.(f{k})); end
        if inW, b = mat2str(want.(f{k})); end
        parts{end+1} = sprintf('%s: %s -> %s', f{k}, a, b); %#ok<AGROW>
    end
    s = strjoin(parts, '; ');
end
