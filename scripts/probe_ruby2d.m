% probe_ruby2d.m — inspect Ruby2D L1 and L2 mat file structure
% Author: Holden Leslie-Bole, 2026
cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');

l1file = '/Volumes/group/Ruby2D/PUV/Level1_QC/Torrey_Ruby2D_582_6m_processed.mat';
l2file = '/Volumes/group/Ruby2D/PUV/Level2_QC/Torrey_Ruby2D_582_6m_PUV_process.mat';

fprintf('=== L1 file ===\n');
fprintf('Path: %s\n', l1file);
info = whos('-file', l1file);
for i = 1:numel(info)
    fprintf('  %s [%s] %s\n', info(i).name, mat2str(info(i).size), info(i).class);
end

fprintf('\n=== L1 contents (first level) ===\n');
S = load(l1file);
flds = fieldnames(S);
for i = 1:numel(flds)
    v = S.(flds{i});
    if isstruct(v)
        fprintf('  %s [struct]\n', flds{i});
        sub = fieldnames(v);
        for j = 1:min(numel(sub), 20)
            sv = v.(sub{j});
            if isnumeric(sv)
                fprintf('    .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
            elseif isdatetime(sv)
                fprintf('    .%s [%s] datetime\n', sub{j}, mat2str(size(sv)));
            else
                fprintf('    .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
            end
        end
    else
        fprintf('  %s [%s] %s\n', flds{i}, mat2str(size(v)), class(v));
    end
end

fprintf('\n=== L2 file ===\n');
fprintf('Path: %s\n', l2file);
info2 = whos('-file', l2file);
for i = 1:numel(info2)
    fprintf('  %s [%s] %s\n', info2(i).name, mat2str(info2(i).size), info2(i).class);
end

fprintf('\n=== L2 contents (first level) ===\n');
S2 = load(l2file);
flds2 = fieldnames(S2);
for i = 1:numel(flds2)
    v = S2.(flds2{i});
    if isstruct(v)
        fprintf('  %s [struct]\n', flds2{i});
        sub = fieldnames(v);
        for j = 1:min(numel(sub), 30)
            sv = v.(sub{j});
            if isnumeric(sv)
                fprintf('    .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
            else
                fprintf('    .%s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
            end
        end
    else
        fprintf('  %s [%s] %s\n', flds2{i}, mat2str(size(v)), class(v));
    end
end
