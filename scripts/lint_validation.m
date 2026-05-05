% LINT_VALIDATION  Run checkcode across all validation/ scripts and
% report any with non-empty lint messages.
% Author: Holden Leslie-Bole, 2026

files = dir('validation/*.m');
fprintf('Linting %d validation scripts...\n', numel(files));
nIssues = 0;
for k = 1:numel(files)
    fp = fullfile(files(k).folder, files(k).name);
    msg = checkcode(fp, '-string');
    if ~isempty(strtrim(msg))
        nIssues = nIssues + 1;
        fprintf('\n--- %s ---\n%s\n', files(k).name, msg);
    end
end
fprintf('\nDone: %d/%d files have lint warnings.\n', nIssues, numel(files));
