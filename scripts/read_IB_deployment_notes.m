% READ_IB_DEPLOYMENT_NOTES  Pull metadata for the 2018-2019 Imperial Beach
% PUV deployments out of Brian Woodward's Excel deployment-notes file.
% Author: Holden Leslie-Bole, 2026

xlsFile = '/Volumes/group/DeploymentNotes/DeploymentNotes2018-2019.xls';

%% List sheet names
[~, sheets] = xlsfinfo(xlsFile);
fprintf('=== Sheets in %s ===\n', xlsFile);
for k = 1:numel(sheets)
    fprintf('  %d: %s\n', k, sheets{k});
end

%% Read each sheet and look for IB
for k = 1:numel(sheets)
    s = sheets{k};
    [~, ~, raw] = xlsread(xlsFile, s);
    % Convert to string and search for IB or Imperial
    rawStr = cellfun(@(x) num2str(x), raw, 'UniformOutput', false);
    isIB = false(size(rawStr));
    for i = 1:numel(rawStr)
        v = rawStr{i};
        if contains(lower(v), 'ib') || contains(lower(v), 'imperial')
            isIB(i) = true;
        end
    end
    if any(isIB(:))
        fprintf('\n=== Sheet "%s" — found IB references ===\n', s);
        % Print rows that contain IB
        [rowsIB, ~] = find(isIB);
        rowsIB = unique(rowsIB);
        for r = 1:numel(rowsIB)
            row = raw(rowsIB(r), :);
            row = row(~cellfun(@(x) isnumeric(x) && isnan(x), row));  % strip NaN
            cellStr = cellfun(@(x) num2str(x), row, 'UniformOutput', false);
            fprintf('  row %d: %s\n', rowsIB(r), strjoin(cellStr, ' | '));
        end
    end
end
