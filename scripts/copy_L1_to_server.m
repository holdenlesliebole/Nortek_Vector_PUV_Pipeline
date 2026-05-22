% copy_L1_to_server.m
%   One-shot sync of L1 (*_processed.mat) outputs to reefbreak.
%   Mirrors the L2/L3/L4 sync logic from copy_to_server.m but only
%   touches Level1_QC subfolders, so it is safe to run concurrently
%   with an in-progress L4 batch (which writes only Level4_QC).
%   Byte-size skip keeps re-runs cheap.
%
%   Run from PUV_Pipeline/:
%     >> run scripts/copy_L1_to_server
% Author: Holden Leslie-Bole, 2026

src_root  = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';
dest_root = '/Volumes/group/PUV_data/Vector/Processed_HLB';

if ~isfolder(fileparts(dest_root))
    error('Server not mounted: %s', fileparts(dest_root));
end
if ~exist(dest_root, 'dir'); mkdir(dest_root); end

L1_files = dir(fullfile(src_root, 'L1', '*', '*_processed.mat'));
fprintf('Found %d L1 files\n', numel(L1_files));

nOk = 0; nSkip = 0; nFail = 0; tAll = tic;

for k = 1:numel(L1_files)
    d = L1_files(k);
    deployment = regexp(d.folder, [filesep '([^' filesep ']+)$'], 'tokens', 'once');
    deployment = deployment{1};

    src_path = fullfile(d.folder, d.name);
    dest_dir = fullfile(dest_root, deployment, 'Level1_QC');
    if ~exist(dest_dir, 'dir'); mkdir(dest_dir); end
    dest_path = fullfile(dest_dir, d.name);

    fprintf('[%2d/%2d] %s/Level1_QC/%s ... ', k, numel(L1_files), deployment, d.name);

    if isfile(dest_path)
        destInfo = dir(dest_path);
        if destInfo.bytes == d.bytes
            fprintf('skip (%.1f MB, already synced)\n', d.bytes/1e6);
            nSkip = nSkip + 1;
            continue
        end
    end

    try
        t0 = tic;
        copyfile(src_path, dest_path);
        fprintf('%.1fs (%.1f MB)\n', toc(t0), d.bytes/1e6);
        nOk = nOk + 1;
    catch ME
        fprintf('FAIL: %s\n', ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\nDone in %.1f min. %d copied, %d skipped, %d failed.\n', ...
    toc(tAll)/60, nOk, nSkip, nFail);
