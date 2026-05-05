function inventory_check()
% INVENTORY_CHECK  Compare deployment_registry vs L2 outputs on disk vs
% Phase 2 summary. Identify any gaps — instruments that should have been
% processed but weren't, or deployments missing from the registry.
% Author: Holden Leslie-Bole, 2026

thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
L2dir = fullfile(pipelineRoot,'outputs','L2');

reg = deployment_registry();
deployments = sort(keys(reg));

% Phase 2 summary
S = load(fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate','phase2_summary.mat'));
ph2 = S.summary;
ph2set = strings(numel(ph2.label),1);
for k = 1:numel(ph2.label), ph2set(k) = sprintf('%s/%s', ph2.deployment{k}, ph2.label{k}); end

fprintf('\n%-12s  %-14s  %-8s  %-8s  %-8s\n','deployment','label','inReg','onDisk','inPh2');
fprintf('%s\n', repmat('-',1,60));

n_reg = 0; n_disk = 0; n_ph2 = 0;
gaps_disk_missing = {};
gaps_ph2_missing = {};

for iD = 1:numel(deployments)
    dep = deployments{iD};
    try
        configFn = reg(dep);
        cfg = configFn();
        cfgLabels = {cfg.instruments.label};
    catch
        cfgLabels = {};
    end

    % Files on disk
    files = dir(fullfile(L2dir, dep, '*_L2.mat'));
    files = files(~contains({files.name},'.bak'));
    diskLabels = cellfun(@(s) regexprep(s,'_L2\.mat$',''), {files.name},'UniformOutput',false);

    allLabels = unique([cfgLabels(:); diskLabels(:)]);
    if isempty(allLabels), continue; end
    for iL = 1:numel(allLabels)
        lab = allLabels{iL};
        inReg  = any(strcmp(cfgLabels, lab));
        onDisk = any(strcmp(diskLabels, lab));
        key = sprintf('%s/%s', dep, lab);
        inPh2  = any(strcmp(ph2set, key));
        n_reg  = n_reg  + inReg;
        n_disk = n_disk + onDisk;
        n_ph2  = n_ph2  + inPh2;
        if inReg && ~onDisk, gaps_disk_missing{end+1} = key; end %#ok<AGROW>
        if onDisk && ~inPh2, gaps_ph2_missing{end+1}  = key; end %#ok<AGROW>
        fprintf('%-12s  %-14s  %-8s  %-8s  %-8s\n', dep, lab, ...
            tickmark(inReg), tickmark(onDisk), tickmark(inPh2));
    end
end

fprintf('\nTotals:  registry=%d   on disk=%d   in Phase 2=%d\n', n_reg, n_disk, n_ph2);

if ~isempty(gaps_disk_missing)
    fprintf('\nIn registry but NOT on disk (need to process):\n');
    for k = 1:numel(gaps_disk_missing), fprintf('  %s\n', gaps_disk_missing{k}); end
end
if ~isempty(gaps_ph2_missing)
    fprintf('\nOn disk but NOT in Phase 2 summary (rerun Phase 2):\n');
    for k = 1:numel(gaps_ph2_missing), fprintf('  %s\n', gaps_ph2_missing{k}); end
end
end

function s = tickmark(b)
if b, s = 'YES'; else, s = ' .'; end
end
