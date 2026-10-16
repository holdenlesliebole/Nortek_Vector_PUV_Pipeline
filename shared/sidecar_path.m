function sc = sidecar_path(matPath, opts)
% SIDECAR_PATH  Where the provenance sidecar of an output file lives.
%
%   sc = sidecar_path(matPath)            -> <matPath>.prov.json
%   sc = sidecar_path(matPath, opts)      with opts.sidecarRoot and opts.outRoot:
%        <sidecarRoot>/<matPath relative to outRoot>.prov.json
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 2, opts = struct(); end
    if isfield(opts, 'sidecarRoot') && ~isempty(opts.sidecarRoot)
        if ~isfield(opts, 'outRoot') || ~startsWith(matPath, [opts.outRoot filesep])
            error('sidecar_path:root', 'with sidecarRoot, matPath must lie under opts.outRoot');
        end
        sc = fullfile(opts.sidecarRoot, [extractAfter(matPath, [opts.outRoot filesep]) '.prov.json']);
    else
        sc = [matPath '.prov.json'];
    end
end
