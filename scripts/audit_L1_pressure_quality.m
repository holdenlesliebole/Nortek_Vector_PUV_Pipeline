% AUDIT_L1_PRESSURE_QUALITY  Sweep all L1 outputs to find:
%   (A) Records with pMed wildly inconsistent with depth_nominal
%       — either silent QC inversion, or just a deep-water instrument.
%   (B) Records with very low %valid (<20%) — possibly garbage retained.
%   (C) Records with high %valid (>80%) but suspicious P statistics.
%
% This is a fast offline audit — does NOT re-run the pipeline.
% It just reads the saved L1 .mat files and the config to compare.
% Author: Holden Leslie-Bole, 2026

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

L1root = 'outputs/L1';
deps = dir(L1root);
deps = deps([deps.isdir] & ~startsWith({deps.name},'.') & ~strcmp({deps.name},'diagnostics'));
registry = deployment_registry();

fprintf('| %-12s | %-18s | %5s | %7s | %7s | %7s | %7s | %s\n', ...
    'deployment','instrument','depth','n_total','n_valid','pMed','pMax','flag');
fprintf('| %-12s | %-18s | %5s | %7s | %7s | %7s | %7s | %s\n', ...
    repmat('-',1,12), repmat('-',1,18), '----', '------', '------', '----', '----', '----');

flagged = struct('label',{},'reason',{});

for d = 1:numel(deps)
    dep = deps(d).name;
    if isKey(registry, dep)
        cfgFn = registry(dep);
        cfg = cfgFn();
    else
        cfgFn = sprintf('%s_config', dep);
        try
            cfg = feval(cfgFn);
        catch
            fprintf('| %-12s | (no config found, skipping)\n', dep);
            continue
        end
    end
    matFiles = dir(fullfile(L1root, dep, '*_processed.mat'));
    for f = 1:numel(matFiles)
        label = strrep(matFiles(f).name, '_processed.mat','');
        % Look up depth_nominal from config
        depth_nom = NaN;
        if isfield(cfg,'instruments')
            for k = 1:numel(cfg.instruments)
                if strcmp(cfg.instruments(k).label, label)
                    if isfield(cfg.instruments(k),'depth_nominal')
                        depth_nom = cfg.instruments(k).depth_nominal;
                    end
                    break
                end
            end
        end
        try
            S = load(fullfile(L1root, dep, matFiles(f).name), 'PUV');
            P = S.PUV.P;
            pV = P(~isnan(P));
            n_total = numel(P);
            n_valid = numel(pV);
            if n_valid > 0
                pMed = median(pV);
                pMax = max(pV);
            else
                pMed = NaN; pMax = NaN;
            end
        catch ME
            fprintf('| %-12s | %-18s | LOAD FAILED: %s\n', dep, label, ME.message);
            continue
        end
        % Decide flags
        flag = '';
        if n_valid < 0.05 * n_total
            flag = [flag '<5%valid '];
            flagged(end+1) = struct('label',sprintf('%s/%s',dep,label),'reason',sprintf('%.1f%% valid', 100*n_valid/n_total)); %#ok<AGROW>
        end
        if ~isnan(depth_nom) && ~isnan(pMed)
            if pMed > 3 * depth_nom + 5
                flag = [flag 'pMed>>depth '];
                flagged(end+1) = struct('label',sprintf('%s/%s',dep,label),'reason',sprintf('pMed=%.1f >> depth_nom=%.1f', pMed, depth_nom)); %#ok<AGROW>
            elseif pMed < 0.3 * depth_nom
                flag = [flag 'pMed<<depth '];
                flagged(end+1) = struct('label',sprintf('%s/%s',dep,label),'reason',sprintf('pMed=%.1f << depth_nom=%.1f', pMed, depth_nom)); %#ok<AGROW>
            end
        end
        if ~isnan(pMax) && pMax > 200
            flag = [flag 'pMax>200 '];
            flagged(end+1) = struct('label',sprintf('%s/%s',dep,label),'reason',sprintf('pMax=%.1f (saturation?)', pMax)); %#ok<AGROW>
        end
        fprintf('| %-12s | %-18s | %5.1f | %7.0f | %7.0f | %7.2f | %7.1f | %s\n', ...
            dep, label, depth_nom, n_total, n_valid, pMed, pMax, flag);
    end
end

fprintf('\n=== FLAGGED RECORDS ===\n');
if isempty(flagged)
    fprintf('No records flagged.\n');
else
    for k = 1:numel(flagged)
        fprintf('  %s — %s\n', flagged(k).label, flagged(k).reason);
    end
end
