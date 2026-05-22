% migrate_NN24_to_TOR23W_SOL23.m
% Author: Holden Leslie-Bole, 2026
% Migrate NN24 output files to TOR23W and SOL23 directory structure.
%
% This script:
%   1. Copies L1/L2/L3 .mat files from outputs/*/NN24/ to the new directories
%   2. Updates the deploymentName field inside each .mat file
%   3. Renames validation PNGs
%   4. Does NOT delete the NN24 directories (do that manually after verifying)

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root

outRoot = 'outputs';

% Mapping: instrument label -> new deployment name
torrey_labels = {'MOP580_5m', 'MOP580_7m', 'MOP586_5m', 'MOP586_7m', 'MOP586_10m', 'MOP586_15m'};
solana_labels = {'MOP651_5m', 'MOP651_7m', 'MOP654_7m'};

levels = {'L1', 'L2', 'L3'};
suffixes = {'_processed.mat', '_L2.mat', '_L3.mat'};

for lev = 1:3
    srcDir = fullfile(outRoot, levels{lev}, 'NN24');
    if ~isfolder(srcDir)
        fprintf('Skipping %s (not found)\n', srcDir);
        continue
    end

    % Create new directories
    torDir = fullfile(outRoot, levels{lev}, 'TOR23W');
    solDir = fullfile(outRoot, levels{lev}, 'SOL23');
    if ~exist(torDir, 'dir'), mkdir(torDir); end
    if ~exist(solDir, 'dir'), mkdir(solDir); end

    % Determine struct variable name and new deployment name for each file
    for lab = [torrey_labels solana_labels]
        label = lab{1};
        srcFile = fullfile(srcDir, [label suffixes{lev}]);
        if ~isfile(srcFile)
            fprintf('  Not found: %s\n', srcFile);
            continue
        end

        if ismember(label, torrey_labels)
            newDeploy = 'TOR23W';
            dstDir = torDir;
        else
            newDeploy = 'SOL23';
            dstDir = solDir;
        end

        dstFile = fullfile(dstDir, [label suffixes{lev}]);
        fprintf('  %s -> %s\n', srcFile, dstFile);

        % Copy file
        copyfile(srcFile, dstFile);

        % Update deploymentName inside the .mat file
        if lev == 1
            varName = 'PUV';
        elseif lev == 2
            varName = 'L2';
        else
            varName = 'L3';
        end

        try
            S = load(dstFile, varName);
            data = S.(varName);
            if isfield(data, 'deploymentName')
                oldName = data.deploymentName;
                data.deploymentName = newDeploy;
                S.(varName) = data;
                save(dstFile, '-struct', 'S', '-v7.3');
                fprintf('    Updated deploymentName: %s -> %s\n', oldName, newDeploy);
            end
        catch ME
            warning('Failed to update %s: %s', dstFile, ME.message);
        end
    end
end

%% Rename validation PNGs
valDir = fullfile(outRoot, 'validation');
if isfolder(valDir)
    pngs = dir(fullfile(valDir, 'NN24_*.png'));
    for p = 1:numel(pngs)
        oldPath = fullfile(valDir, pngs(p).name);

        % Determine which deployment this belongs to
        isTorrey = false;
        for t = 1:numel(torrey_labels)
            if contains(pngs(p).name, torrey_labels{t})
                isTorrey = true;
                break
            end
        end

        if isTorrey
            newName = strrep(pngs(p).name, 'NN24_', 'TOR23W_');
        else
            newName = strrep(pngs(p).name, 'NN24_', 'SOL23_');
        end

        newPath = fullfile(valDir, newName);
        copyfile(oldPath, newPath);
        fprintf('  %s -> %s\n', pngs(p).name, newName);
    end
end

fprintf('\nMigration complete.\n');
fprintf('After verifying, manually remove:\n');
fprintf('  rm -rf outputs/L1/NN24 outputs/L2/NN24 outputs/L3/NN24\n');
fprintf('  rm outputs/validation/NN24_*.png\n');
