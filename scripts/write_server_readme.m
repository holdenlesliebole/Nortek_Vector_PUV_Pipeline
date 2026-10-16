% write_server_readme.m
% Author: Holden Leslie-Bole, 2026
% Rewrite README.md at the root of the published catalog, and nothing else.
%
% copy_to_server.m writes the README on every push, but a push also makes a
% new catalog version, manifest and CHANGELOG section. Use this script when
% only the README text (scripts/server_readme_text.m) has changed. The
% catalog version and pipeline commit it names are read from the newest
% "## <version>  (<date>, pipeline commit <hash>)" heading of the server
% CHANGELOG.md, and the counts from the server manifest.csv, so the README
% describes the catalog that is actually there.
%
% Optional workspace variables:
%   destRoot   catalog root (default: the group-server Processed_HLB)
%   outFile    write here instead of <destRoot>/README.md (to preview)

if ~exist('destRoot', 'var') || isempty(destRoot)
    destRoot = '/Volumes/group/PUV_data/Vector/Processed_HLB';
end
if ~exist('outFile', 'var') || isempty(outFile)
    outFile = fullfile(destRoot, 'README.md');
end

M = readtable(fullfile(destRoot, 'manifest.csv'), 'TextType', 'string', 'Delimiter', ',');
cl = fileread(fullfile(destRoot, 'CHANGELOG.md'));
tok = regexp(cl, '## (\d{4}-\d{2}-\d{2}\.\d+)\s+\([^,]*, pipeline commit ([0-9a-f]+)\)', 'tokens', 'once');
if isempty(tok)
    error('write_server_readme:noVersion', 'no catalog version heading found in %s', ...
        fullfile(destRoot, 'CHANGELOG.md'));
end

txt = server_readme_text(numel(unique(M.deployment)), sum(M.level == "L4"), tok{1}, tok{2});
fid = fopen(outFile, 'w');
if fid < 0, error('write_server_readme:open', 'cannot write %s', outFile); end
fprintf(fid, '%s', txt); fclose(fid);
fprintf('Wrote %s (catalog %s, commit %s, %d deployments, %d records)\n', ...
    outFile, tok{1}, tok{2}, numel(unique(M.deployment)), sum(M.level == "L4"));
