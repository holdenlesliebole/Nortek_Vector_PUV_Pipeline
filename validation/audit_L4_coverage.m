% AUDIT_L4_COVERAGE  Per-record L4 sub-product presence and L4/L2 alignment.
%
%   Prints, for every L2 record in the registry, which L4 sub-products exist
%   and whether the L4 segment grid still matches the canonical L2 grid.
%
%   Alignment is checked on EVERY per-segment sub-product, not just the first
%   one present, and by TIME rather than by count -- equal counts do not prove
%   alignment, and a record whose L2 gained a leading segment is misaligned
%   from its very first segment. See shared/l4_l2_index_map.m.
%
%   Run from PUV_Pipeline/:
%     >> run validation/audit_L4_coverage

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
reg  = deployment_registry(); names = sort(keys(reg));
want = {'eta','ref','bispectra','boundwave','moments','reflection_free','pdf'};

fprintf('\n%-9s %-13s %6s', 'deploy', 'label', 'nL2');
fprintf(' %-8s', want{:});
fprintf('  %s\n', 'alignment');

seen      = containers.Map('KeyType','char','ValueType','logical');
missList  = {};
alignList = {};
nRec      = 0;

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        f4  = fullfile(root, 'L4', cfg.name, [lab '_L4.mat']);
        rec = [cfg.name '/' lab];
        if ~isfile(f4)
            fprintf('%-9s %-13s %6s  NO L4 FILE\n', cfg.name, lab, '-');
            missList{end+1} = [rec ' (no file)']; %#ok<SAGROW>
            continue
        end
        nRec = nRec + 1;

        S2 = load(fullfile(fl(k).folder, fl(k).name), 'L2'); L2 = S2.L2;
        S4 = load(f4, 'L4'); L4 = S4.L4;
        nL2 = numel(L2.time);

        fprintf('%-9s %-13s %6d', cfg.name, lab, nL2);
        for j = 1:numel(want)
            has = isfield(L4, want{j});
            fprintf(' %-8s', tern(has, 'y', '--'));
            if ~has
                missList{end+1} = [rec ' (' want{j} ')']; %#ok<SAGROW>
            end
        end

        % --- alignment, checked on every per-segment sub-product ---
        note = 'ok';
        try
            [~, info] = l4_l2_index_map(L2, L4);
            if ~info.identity
                note = sprintf('SHIFTED src=%s nL4=%d nL2=%d maxOffset=%d matched=%d', ...
                    info.source, info.nL4, info.nL2, info.maxOffset, info.nMatched);
                alignList{end+1} = [rec ' -- ' note]; %#ok<SAGROW>
            end
            % do the sub-products agree with each other?
            lens = NaN(1, numel(want));
            for j = 1:numel(want)
                s = want{j};
                if isfield(L4, s) && isfield(L4.(s), 'time')
                    lens(j) = numel(L4.(s).time);
                end
            end
            lens = lens(~isnan(lens));
            if numel(unique(lens)) > 1
                note = [note ' | INTERNALLY INCONSISTENT: ' mat2str(unique(lens))];
                alignList{end+1} = [rec ' -- internally inconsistent ' mat2str(unique(lens))]; %#ok<SAGROW>
            end
        catch ME
            note = ['align check failed: ' ME.message];
            alignList{end+1} = [rec ' -- ' note]; %#ok<SAGROW>
        end
        fprintf('  %s\n', note);
    end
end

fprintf('\n%d records inspected\n', nRec);
fprintf('\nmissing sub-products (%d):\n', numel(missList));
for i = 1:numel(missList), fprintf('  %s\n', missList{i}); end
fprintf('\nalignment problems (%d):\n', numel(alignList));
for i = 1:numel(alignList), fprintf('  %s\n', alignList{i}); end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
