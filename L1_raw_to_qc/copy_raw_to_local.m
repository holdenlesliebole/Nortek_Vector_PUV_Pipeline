function cfg = copy_raw_to_local(cfg, localRoot)
% COPY_RAW_TO_LOCAL  Copy raw deployment files from server to local disk.
%
%   cfg = copy_raw_to_local(cfg)
%   cfg = copy_raw_to_local(cfg, localRoot)
%
%   Copies all raw files for every instrument in the deployment config from
%   the lab server (cfg.rawDataRoot) to a local directory. Returns an
%   updated cfg with cfg.localDataRoot set, so subsequent calls to
%   PUV_raw_process read from the fast local copy.
%
%   Files already present locally are skipped (safe to re-run).
%
%   INPUTS
%     cfg        - deployment config struct (from e.g. TBR23_config)
%     localRoot  - (optional) root directory for local cache.
%                  Default: ~/Documents/Scripps/Research/PUV_Pipeline/raw_cache
%
%   OUTPUT
%     cfg        - same config with cfg.localDataRoot set to localRoot
%
%   USAGE
%     cfg = TBR23_config();
%     cfg = copy_raw_to_local(cfg);   % copy files, update cfg
%     PUV_L1_driver  % now reads from local disk

    if nargin < 2
        localRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'raw_cache');
    end

    cfg.localDataRoot = fullfile(localRoot, cfg.name);

    fprintf('\n=== Copying raw files for %s ===\n', cfg.name);
    fprintf('  Source : %s\n', cfg.rawDataRoot);
    fprintf('  Dest   : %s\n', cfg.localDataRoot);

    totalBytes = 0;
    totalCopied = 0;
    tStart = tic;

    for k = 1:numel(cfg.instruments)
        instr = cfg.instruments(k);

        % Source and destination directories for this instrument
        if ~isempty(instr.rawSubfolder)
            srcDir  = fullfile(cfg.rawDataRoot,   instr.rawSubfolder);
            destDir = fullfile(cfg.localDataRoot, instr.rawSubfolder);
        else
            srcDir  = cfg.rawDataRoot;
            destDir = cfg.localDataRoot;
        end

        if ~isfolder(srcDir)
            warning('copy_raw_to_local:srcNotFound', ...
                'Source directory not found, skipping %s:\n  %s', instr.label, srcDir);
            continue
        end

        if ~exist(destDir, 'dir'), mkdir(destDir); end

        % Copy all raw files (.dat, .sen, .hdr, .VEC, .pck, .ssl, .vhd, .log, .dep)
        allFiles = dir(srcDir);
        allFiles = allFiles(~[allFiles.isdir]);

        fprintf('\n  [%d/%d] %s — %d files\n', k, numel(cfg.instruments), instr.label, numel(allFiles));

        for f = 1:numel(allFiles)
            srcFile  = fullfile(srcDir,  allFiles(f).name);
            destFile = fullfile(destDir, allFiles(f).name);
            fileMB   = allFiles(f).bytes / 1e6;

            if isfile(destFile)
                % Skip if already present and same size
                d = dir(destFile);
                if d.bytes == allFiles(f).bytes
                    fprintf('    skip  %-40s (%.0f MB, already present)\n', ...
                        allFiles(f).name, fileMB);
                    continue
                end
            end

            fprintf('    copy  %-40s (%.0f MB) ...', allFiles(f).name, fileMB);
            t1 = tic;
            copyfile(srcFile, destFile);
            fprintf(' %.1fs\n', toc(t1));

            totalBytes  = totalBytes  + allFiles(f).bytes;
            totalCopied = totalCopied + 1;
        end
    end

    fprintf('\nDone. Copied %d files (%.1f GB) in %.1f min.\n', ...
        totalCopied, totalBytes/1e9, toc(tStart)/60);
    fprintf('cfg.localDataRoot set to:\n  %s\n', cfg.localDataRoot);
end
