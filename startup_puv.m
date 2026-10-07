% startup_puv.m
% Run this at the start of any PUV pipeline session.
% Adds all subdirectories of PUV_Pipeline to the MATLAB path, except those that
% hold other copies of the code or data rather than the code itself:
%   .claude/  agent worktrees -- full checkouts that sort first in genpath and
%             would SHADOW this checkout's functions and configs
%   .git/     repository internals
%   outputs/  processed data (a symlink); also holds analysis scripts
%   raw_cache/ local copies of raw instrument files
% Author: Holden Leslie-Bole, 2026

root = fileparts(mfilename('fullpath'));
dirs = strsplit(genpath(root), pathsep);
skip = fullfile(root, {'.claude', '.git', 'outputs', 'raw_cache'});
keep = true(size(dirs));
for s = 1:numel(skip)
    keep = keep & ~strcmp(dirs, skip{s}) & ~startsWith(dirs, [skip{s} filesep]);
end
dirs = dirs(keep & ~cellfun(@isempty, dirs));
addpath(strjoin(dirs, pathsep));
fprintf('PUV Pipeline paths added. Root: %s\n', root);
