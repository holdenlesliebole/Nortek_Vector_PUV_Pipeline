% RECHECK_FAILING_L1  Re-run L1 for the 6 instruments that previously
% failed with "No valid pressure data after QC", to see whether the new
% pMed-reference-window fix unblocks any of them.
%
% Targets:
%   SIO24B / SIO_6m
%   SIO24C / SIO_6m
%   SIO25A / SIO_6m
%   TOR24S / MOP586_15m
%   TOR24W / MOP586_5m
%   TOR25S / MOP586_5m
% Author: Holden Leslie-Bole, 2026

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

reg = deployment_registry();

targets = {
    'SIO24B',  'SIO_6m';
    'SIO24C',  'SIO_6m';
    'SIO25A',  'SIO_6m';
    'TOR24S',  'MOP586_15m';
    'TOR24W',  'MOP586_5m';
    'TOR25S',  'MOP586_5m';
};

results = cell(size(targets,1), 1);

for t = 1:size(targets,1)
    dep   = targets{t,1};
    label = targets{t,2};

    fprintf('\n========== %s / %s ==========\n', dep, label);

    cfgFn = reg(dep);
    cfg = cfgFn();

    % Find the matching instrument in cfg
    instr = [];
    for k = 1:numel(cfg.instruments)
        if strcmp(cfg.instruments(k).label, label)
            instr = cfg.instruments(k);
            break
        end
    end
    if isempty(instr)
        fprintf('  cfg has no instrument %s — skipping\n', label);
        results{t} = struct('dep',dep,'label',label,'status','no_cfg');
        continue
    end

    % Use local cache if available
    localCache = fullfile('raw_cache', cfg.name);
    if isfolder(localCache)
        cfg.localDataRoot = localCache;
    end

    try
        PUV = PUV_raw_process(instr, cfg);
        % If we got here, L1 succeeded
        outDir = fullfile('outputs','L1', cfg.name);
        if ~exist(outDir,'dir'), mkdir(outDir); end
        save(fullfile(outDir, [instr.label '_processed.mat']), 'PUV', '-v7.3');

        P = PUV.P; pV = P(~isnan(P));
        fprintf('  SUCCESS: %d/%d valid (%.1f%%), median=%.2f dBar (depth_nom=%.1f)\n', ...
            numel(pV), numel(P), 100*numel(pV)/numel(P), median(pV), instr.depth_nominal);

        results{t} = struct('dep',dep,'label',label,'status','recovered', ...
            'n_total',numel(P),'n_valid',numel(pV),'pMed',median(pV), ...
            'depth_nom',instr.depth_nominal);
    catch ME
        fprintf('  STILL FAILS: %s\n', ME.message);
        results{t} = struct('dep',dep,'label',label,'status','still_fails', ...
            'errId',ME.identifier,'errMsg',ME.message);
    end
end

%% Summary table
fprintf('\n========== SUMMARY ==========\n');
fprintf('%-10s %-15s %-15s %s\n','dep','label','status','detail');
fprintf('%-10s %-15s %-15s %s\n', repmat('-',1,10), repmat('-',1,15), repmat('-',1,15), repmat('-',1,30));
for t = 1:numel(results)
    r = results{t};
    if strcmp(r.status,'recovered')
        detail = sprintf('n_valid=%d, pMed=%.2f vs depth_nom=%.1f', ...
            r.n_valid, r.pMed, r.depth_nom);
    elseif strcmp(r.status,'still_fails')
        detail = r.errMsg;
    else
        detail = '';
    end
    fprintf('%-10s %-15s %-15s %s\n', r.dep, r.label, r.status, detail);
end
