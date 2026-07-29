% Diagnose the heading bug. For each instrument:
%   - Read the configured heading
%   - Read the median compass heading from the L1 raw data (.sen col 11)
%   - Compare. If they differ by ~180 deg, that's the smoking gun.
%
% Also load L1 .mat to verify what heading was actually used.

startup_puv;
cases = { ...
    'TBR23',  'MOP580_5m', 'broken'; ...
    'TBR23',  'MOP580_7m', 'clean'; ...
    'TBR23',  'MOP586_5m', 'clean'; ...
    'TBR23',  'MOP586_7m', 'clean'; ...
    'TOR24S', 'MOP586_5m', 'clean'; ...
    'TOR24S', 'MOP586_7m', 'broken'; ...
    'TOR24S', 'MOP586_10m', 'clean'; ...
    'TOR24S', 'MOP580_7m', 'clean'; ...
};
for c = 1:size(cases,1)
    dep = cases{c,1}; instr = cases{c,2}; note = cases{c,3};
    l1p = fullfile('outputs','L1',dep,[instr '_processed.mat']);
    if ~isfile(l1p), continue, end
    l1 = load(l1p,'PUV'); PUV = l1.PUV;

    cfgFn = str2func([dep '_config']);
    cfg = cfgFn();
    found = -1;
    for k = 1:numel(cfg.instruments)
        if strcmp(cfg.instruments(k).label, instr)
            found = k; break
        end
    end
    if found < 0, fprintf('%s/%s: not in config\n', dep, instr); continue; end
    cfgHeading = cfg.instruments(found).heading;

    fprintf('%-7s/%-12s [%s]  cfg.heading=%7.2f  L1 sensor_used=%7.2f  mag_decl=%7.2f\n', ...
        dep, instr, note, cfgHeading, PUV.rotation.sensor, PUV.rotation.mag);
end
