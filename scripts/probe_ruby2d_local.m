% probe_ruby2d_local.m — inspect locally cached Ruby2D L1 file
% Author: Holden Leslie-Bole, 2026
cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root

l1file = 'raw_cache/Ruby2D/Torrey_Ruby2D_582_6m_processed.mat';

fprintf('=== whos -file (no load) ===\n');
info = whos('-file', l1file);
for i = 1:numel(info)
    sz_mb = info(i).bytes / 1e6;
    fprintf('  %-20s [%s] %s  (%.1f MB)\n', ...
        info(i).name, mat2str(info(i).size), info(i).class, sz_mb);
end

% Load just the metadata-like variables, skip the giant timeseries
fprintf('\n=== Loading top-level struct names only ===\n');
m = matfile(l1file);
mInfo = whos(m);
for i = 1:numel(mInfo)
    fprintf('  %s [%s] %s\n', mInfo(i).name, mat2str(mInfo(i).size), mInfo(i).class);
end

% Now load just one struct and inspect its fields without loading all data
fprintf('\n=== Top-level struct contents ===\n');
varName = mInfo(1).name;
fprintf('Loading variable: %s\n', varName);
S = m.(varName);
if isstruct(S)
    flds = fieldnames(S);
    for i = 1:numel(flds)
        v = S.(flds{i});
        if isstruct(v)
            fprintf('  %s [struct]\n', flds{i});
            sub = fieldnames(v);
            for j = 1:numel(sub)
                sv = v.(sub{j});
                if isnumeric(sv) || islogical(sv)
                    fprintf('    .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
                elseif isdatetime(sv)
                    fprintf('    .%s [%s] datetime\n', sub{j}, mat2str(size(sv)));
                elseif ischar(sv) || isstring(sv)
                    fprintf('    .%s = ''%s''\n', sub{j}, char(sv));
                else
                    fprintf('    .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
                end
            end
        elseif isnumeric(v) || islogical(v)
            fprintf('  %s [%s] %s\n', flds{i}, mat2str(size(v)), class(v));
        elseif isdatetime(v)
            fprintf('  %s [%s] datetime\n', flds{i}, mat2str(size(v)));
        else
            fprintf('  %s [%s] %s\n', flds{i}, mat2str(size(v)), class(v));
        end
    end
end
