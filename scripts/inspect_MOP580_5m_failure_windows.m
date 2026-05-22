% Side-by-side daily validity rate for all 4 TBR23 PUVs.
% If MOP580_5m's failure windows are unique, that's instrument-specific
% biofouling/burial. If they're shared with the other PUVs, it's
% environmental (storm-related sampling error).

startup_puv;
projRoot = fileparts(fileparts(mfilename('fullpath')));

instrs = {'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'};
T = struct();
for i = 1:numel(instrs)
    l2p = fullfile(projRoot,'outputs','L2','TBR23',[instrs{i} '_L2.mat']);
    l2 = load(l2p,'L2'); L2 = l2.L2;
    T.(instrs{i}) = struct('time',L2.time,'valid',L2.segValid);
end

% Common date axis: union of all days
allDays = unique(floor(datenum([T.MOP580_5m.time; T.MOP580_7m.time; T.MOP586_5m.time; T.MOP586_7m.time])));

fprintf('Date         | MOP580_5m | MOP580_7m | MOP586_5m | MOP586_7m\n');
fprintf('             | (fixed)   | (clean)   | (clean)   | (clean)\n');
fprintf('-------------|-----------|-----------|-----------|------------\n');

for d = 1:numel(allDays)
    dy = allDays(d);
    rates = NaN(1,4);
    for i = 1:numel(instrs)
        days = floor(datenum(T.(instrs{i}).time));
        m = days == dy;
        if any(m)
            rates(i) = 100 * sum(T.(instrs{i}).valid(m)) / sum(m);
        end
    end
    % flag pattern markers
    pat = '';
    if rates(1) < 30 && all(rates(2:4) > 70), pat = '  <-- 5m unique fail'; end
    if rates(1) < 30 && any(rates(2:4) < 30), pat = '  <-- shared fail'; end
    fprintf('%s   | %s | %s | %s | %s%s\n', ...
        datestr(dy,'yyyy-mm-dd'), ...
        rate_str(rates(1)), rate_str(rates(2)), rate_str(rates(3)), rate_str(rates(4)), pat);
end

function s = rate_str(r)
    if isnan(r), s = '    -    '; else, s = sprintf('  %3.0f%%  ', r); end
end
