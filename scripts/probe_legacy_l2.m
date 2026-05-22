% probe_legacy_l2.m - inspect the legacy L2 mat file structure
% Author: Holden Leslie-Bole, 2026
cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root

l2file = 'raw_cache/Ruby2D/Torrey_Ruby2D_582_6m_PUV_process.mat';

fprintf('=== whos -file ===\n');
info = whos('-file', l2file);
for i = 1:numel(info)
    sz_mb = info(i).bytes / 1e6;
    fprintf('  %-20s [%s] %s  (%.1f MB)\n', ...
        info(i).name, mat2str(info(i).size), info(i).class, sz_mb);
end

% Use matfile (lazy load) to inspect without loading full thing
m = matfile(l2file);
mInfo = whos(m);
fprintf('\n=== matfile vars ===\n');
for i = 1:numel(mInfo)
    fprintf('  %s [%s] %s\n', mInfo(i).name, mat2str(mInfo(i).size), mInfo(i).class);
end

% Load just the first variable to inspect structure
if ~isempty(mInfo)
    vn = mInfo(1).name;
    fprintf('\nLoading %s...\n', vn);
    A = m.(vn);
    if isstruct(A)
        flds = fieldnames(A);
        fprintf('  Fields:\n');
        for i = 1:numel(flds)
            v = A.(flds{i});
            if isstruct(v)
                fprintf('    %s [struct]\n', flds{i});
                sub = fieldnames(v);
                for j = 1:min(numel(sub), 25)
                    sv = v.(sub{j});
                    if isnumeric(sv) || islogical(sv)
                        fprintf('      .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
                    elseif isdatetime(sv)
                        fprintf('      .%s [%s] datetime\n', sub{j}, mat2str(size(sv)));
                    else
                        fprintf('      .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
                    end
                end
            elseif isnumeric(v)
                fprintf('    %s [%s] %s\n', flds{i}, mat2str(size(v)), class(v));
            elseif isdatetime(v)
                fprintf('    %s [%s] datetime\n', flds{i}, mat2str(size(v)));
            else
                fprintf('    %s [%s] %s\n', flds{i}, mat2str(size(v)), class(v));
            end
        end
    end
end
