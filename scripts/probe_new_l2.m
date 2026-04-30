% probe_new_l2.m - inspect the new pipeline's L2 struct for Ruby2D
% Author: Holden Leslie-Bole, 2026
cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

f = 'outputs/L2/Ruby2D/Ruby2D_582_6m_L2.mat';
m = matfile(f);
mInfo = whos(m);
fprintf('=== matfile vars ===\n');
for i = 1:numel(mInfo)
    fprintf('  %s [%s] %s\n', mInfo(i).name, mat2str(mInfo(i).size), mInfo(i).class);
end

L2 = m.L2;
flds = fieldnames(L2);
fprintf('\n=== L2 fields ===\n');
for i = 1:numel(flds)
    v = L2.(flds{i});
    sz = size(v);
    cl = class(v);
    if isnumeric(v) || islogical(v) || isdatetime(v)
        fprintf('  %-22s [%s] %s\n', flds{i}, mat2str(sz), cl);
    elseif isstruct(v)
        fprintf('  %-22s [%s] struct\n', flds{i}, mat2str(sz));
        if numel(v) == 1
            sub = fieldnames(v);
            for j = 1:min(numel(sub), 40)
                sv = v.(sub{j});
                fprintf('    .%-18s [%s] %s\n', sub{j}, mat2str(size(sv)), class(sv));
            end
        end
    else
        fprintf('  %-22s [%s] %s\n', flds{i}, mat2str(sz), cl);
    end
end
