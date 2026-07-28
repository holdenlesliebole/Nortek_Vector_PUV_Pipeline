% AUDIT_REGISTRY_LOADS  Every registered deployment must build its config.
%
%   Every batch driver and audit in this repo walks `deployment_registry()`
%   inside a `try ... catch, continue` so that one broken deployment cannot
%   abort a multi-hour run. The cost is that a config which *throws* is
%   indistinguishable from one that does not exist: the record silently drops
%   out of the drivers, the audits and copy_to_server, while its outputs sit on
%   disk looking complete.
%
%   That is not hypothetical. TOR18A was left out of TorreyOffshore_config's
%   clockOffsetMap on 2026-07-27; the containers.Map threw, and TOR18A
%   disappeared from the clock-fix rerun, from audit_L4_coverage (which
%   reported 64 records against 65 L4 files on disk) and from the
%   revision-risk sweep, for a day.
%
%   Run this after touching any config. It is the one audit that does NOT
%   swallow errors.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv

reg   = deployment_registry();
names = sort(keys(reg));
bad   = {};
nInst = 0;

fprintf('\n=== registry load check: %d entries ===\n', numel(names));
for i = 1:numel(names)
    try
        f = reg(names{i});
        c = f();
        if ~isfield(c,'instruments') || isempty(c.instruments)
            bad(end+1,:) = {names{i}, 'config has no instruments'}; %#ok<SAGROW>
            continue
        end
        nInst = nInst + numel(c.instruments);
    catch ME
        bad(end+1,:) = {names{i}, ME.message}; %#ok<SAGROW>
    end
end

if isempty(bad)
    fprintf('all %d entries build cleanly (%d instrument definitions)\n', ...
        numel(names), nInst);
else
    fprintf(2, '\n%d ENTRIES FAIL TO BUILD -- these are invisible to every\n', size(bad,1));
    fprintf(2, 'registry-driven driver and audit in the repo:\n\n');
    for i = 1:size(bad,1)
        fprintf(2, '  %-10s %s\n', bad{i,1}, bad{i,2});
    end
    fprintf(2, '\n');
end

% Second half: outputs on disk that no registry entry claims.
outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
d = dir(fullfile(outRoot,'L4','*','*_L4.mat'));
have = cell(numel(d),1);
for i = 1:numel(d)
    [~, dep] = fileparts(d(i).folder);
    have{i} = [dep '/' erase(d(i).name, '_L4.mat')];
end
want = {};
seen = containers.Map('KeyType','char','ValueType','logical');
for i = 1:numel(names)
    try, f = reg(names{i}); c = f(); catch, continue, end
    if isKey(seen, c.name), continue, end
    seen(c.name) = true;
    for j = 1:numel(c.instruments)
        want{end+1} = [c.name '/' c.instruments(j).label]; %#ok<SAGROW>
    end
end
orphan = setdiff(have, want);
fprintf('\nL4 on disk: %d | claimed by registry: %d\n', numel(have), numel(want));
if isempty(orphan)
    fprintf('no orphaned outputs\n');
else
    fprintf(2, 'ORPHANED OUTPUTS (on disk, unclaimed -- usually a config that throws):\n');
    for i = 1:numel(orphan), fprintf(2, '  %s\n', orphan{i}); end
end
