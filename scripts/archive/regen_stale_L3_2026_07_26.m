% REGEN_STALE_L3_2026_07_26  Rebuild L3 for records whose L2 is newer than L3.
%
%   The 2026-07-12 L3 regen covered the 31 instruments promoted from the
%   2026-07-11 archive rerun, but not the 2026-07-10 batch. That leaves 11
%   records whose L3 was built from a superseded L2:
%
%       TBR23   (all 4)    L2 07-10  vs  L3 05-25
%       TOR23W  (all 6)    L2 07-10  vs  L3 05-25
%       SIO24A  (1)        L2 06-05  vs  L3 05-25
%
%   The grids still align (checked: max depth drift 0.019 m, median 0), and the
%   underlying L2 change is small, so this is a provenance fix rather than a
%   correction. It is worth doing anyway because L3 carries the forcing bands,
%   Shields/Rouse and transport terms that downstream analysis consumes, and
%   TBR23 is Paper_1's data.
%
%   Staleness is detected by mtime rather than hardcoded, so the script stays
%   correct as the catalog changes. Old L3 files are backed up to
%   outputs/_pre_L3regen_backup_2026-07-26/, and the script prints a
%   before/after comparison of the headline fields so the size of the change is
%   visible rather than assumed.
%
%   Run from PUV_Pipeline/ (a few minutes):
%     >> run scripts/regen_stale_L3_2026_07_26

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_L3regen_backup_2026-07-26');

% Only touch registered deployments -- outputs/ can hold held-out exploratory
% runs (see the guard in scripts/copy_to_server.m).
reg = deployment_registry(); regKeys = keys(reg);
registered = containers.Map('KeyType','char','ValueType','logical');
for k = 1:numel(regKeys)
    try
        fn = reg(regKeys{k}); c = fn(); registered(c.name) = true;
    catch
        % a config that will not load cannot vouch for its outputs either
    end
end

l2Files = dir(fullfile(outRoot, 'L2', '*', '*_L2.mat'));
todo = {};
for k = 1:numel(l2Files)
    [~, dep] = fileparts(l2Files(k).folder);
    if ~isKey(registered, dep), continue, end
    lab    = erase(l2Files(k).name, '_L2.mat');
    l3Path = fullfile(outRoot, 'L3', dep, [lab '_L3.mat']);
    if ~isfile(l3Path), continue, end
    d3 = dir(l3Path);
    if d3.datenum < l2Files(k).datenum
        todo(end+1,:) = {dep, lab, fullfile(l2Files(k).folder, l2Files(k).name), l3Path}; %#ok<SAGROW>
    end
end

fprintf('\n=== L3 regen: %d stale record(s) ===\n', size(todo,1));
if isempty(todo), fprintf('Nothing to do.\n'); return, end

cmp = {'Hs_total','Hs_swell','Hs_ig','Ef_total','tau_b','shields','rouse'};
nOk = 0; nFail = 0;

for r = 1:size(todo,1)
    dep = todo{r,1}; lab = todo{r,2}; l2Path = todo{r,3}; l3Path = todo{r,4};
    fprintf('\n[%d/%d] %s/%s\n', r, size(todo,1), dep, lab);
    try
        old = load(l3Path, 'L3'); L3old = old.L3;

        rel = extractAfter(l3Path, [outRoot filesep]);
        dst = fullfile(bkRoot, rel);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        if ~isfile(dst), copyfile(l3Path, dst); end

        loaded = load(l2Path, 'L2'); L2 = loaded.L2;
        t0 = tic;
        L3 = PUV_L3_bands(L2);
        L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2);
        L3 = PUV_L3_currents(L3, L2);
        save(l3Path, 'L3', '-v7.3');

        % How much actually changed, on segments both versions call valid?
        fprintf('    rebuilt in %.0f s | nSeg %d -> %d\n', toc(t0), ...
            numel(L3old.time), numel(L3.time));
        if numel(L3old.time) == numel(L3.time)
            v = L3.segValid(:) & L3old.segValid(:);
            for c = 1:numel(cmp)
                f = cmp{c};
                if ~isfield(L3, f) || ~isfield(L3old, f), continue, end
                a = L3old.(f)(:); b = L3.(f)(:);
                m = v & ~isnan(a) & ~isnan(b);
                if ~any(m), continue, end
                fprintf('      %-10s max|d|=%.4g  median|d|=%.4g\n', ...
                    f, max(abs(a(m)-b(m))), median(abs(a(m)-b(m))));
            end
        else
            fprintf('      segment count changed -- compare by time, not index\n');
        end
        nOk = nOk + 1;
    catch ME
        fprintf('    FAIL: %s\n', ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\n=== Done: %d regenerated, %d failed ===\n', nOk, nFail);
