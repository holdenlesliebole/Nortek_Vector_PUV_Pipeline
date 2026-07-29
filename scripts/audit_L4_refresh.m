% Audit which L4 files have the refreshed schema (bispectra + u_ig_bound + reflection_free)
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline';
deps = dir(fullfile(root, 'outputs', 'L4'));
deps = deps([deps.isdir] & ~startsWith({deps.name}, '.'));
files = [];
for d = 1:numel(deps)
    f = dir(fullfile(deps(d).folder, deps(d).name, '*_L4.mat'));
    if isempty(files), files = f; else, files = [files; f]; end %#ok<AGROW>
end
nDone = 0; nMissing = 0;
missingList = {};
for k = 1:numel(files)
    m = matfile(fullfile(files(k).folder, files(k).name));
    L4 = m.L4;
    hasBisp  = isfield(L4, 'bispectra');
    hasBwU   = isfield(L4, 'boundwave') && isfield(L4.boundwave, 'u_ig_bound');
    hasRefr  = isfield(L4, 'reflection_free');
    complete = hasBisp && hasBwU && hasRefr;
    dep = regexp(files(k).folder, [filesep '([^' filesep ']+)$'], 'tokens', 'once');
    label = sprintf('%s/%s', dep{1}, regexprep(files(k).name,'_L4.mat',''));
    if complete
        nDone = nDone + 1;
    else
        nMissing = nMissing + 1;
        missingList{end+1} = label; %#ok<SAGROW>
        fprintf('  INCOMPLETE: %-30s  bisp=%d bw_u=%d refree=%d\n', label, hasBisp, hasBwU, hasRefr);
    end
end
fprintf('\n%d/%d files fully refreshed. %d need re-processing.\n', nDone, numel(files), nMissing);
