% DUMP_CONFIG_LATLON  Write deployment,label,lat,lon for every registered
% record to a CSV, so the stored LATLON can be patched from the configs rather
% than from hand-typed numbers.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv
out = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research-PUV-Pipeline/ea0c0e32-c069-491b-9b57-401726da413a/scratchpad/config_latlon.csv';
reg = deployment_registry(); names = sort(keys(reg));
fid = fopen(out,'w'); fprintf(fid,'deployment,label,lat,lon\n');
seen = containers.Map('KeyType','char','ValueType','logical'); n = 0;
for i = 1:numel(names)
    try, f = reg(names{i}); c = f(); catch, continue, end
    if isKey(seen,c.name), continue, end
    seen(c.name) = true;
    for k = 1:numel(c.instruments)
        in = c.instruments(k);
        if ~isfield(in,'latlon') || numel(in.latlon) < 2, continue, end
        fprintf(fid,'%s,%s,%.6f,%.6f\n', c.name, in.label, in.latlon(1), in.latlon(2));
        n = n + 1;
    end
end
fclose(fid);
fprintf('RES wrote %d rows to %s\n', n, out);
