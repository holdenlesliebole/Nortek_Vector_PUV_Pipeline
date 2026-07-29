startup_puv
reg = deployment_registry();
nm = {'RUBY22','LPL23','LPL24','LPL25A','LPL25B','SIO24A','SIO25B','SIO25C', ...
      'SIO25D','SIO25E','TOR24S','TOR24W','TOR25S','TBR23','TOR23W','SOL23'};
for i = 1:numel(nm)
    try
        f = reg(nm{i}); c = f(); s = '';
        for k = 1:numel(c.instruments)
            s = [s sprintf(' %s[%.5f %.5f]', c.instruments(k).label, ...
                 c.instruments(k).latlon(1), c.instruments(k).latlon(2))]; %#ok<AGROW>
        end
        fprintf('RES OK   %-8s%s\n', nm{i}, s);
    catch ME
        fprintf('RES FAIL %-8s %s\n', nm{i}, ME.message);
    end
end
