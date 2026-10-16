function prov = read_prov(matPath, opts)
% READ_PROV  Provenance of an output file: its sidecar, else its embedded block.
%
%   prov = read_prov(matPath)
%   prov = read_prov(matPath, opts)
%
% Returns [] if the file has neither. opts.sidecarRoot (with opts.outRoot)
% reads sidecars from a parallel tree instead of beside the .mat, which lets a
% backfill or a push dry run be exercised without writing into outputs/.
% The embedded block is read only when there is no sidecar, and carries no
% file_sha256 (a file cannot contain its own hash).
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 2, opts = struct(); end
    prov = [];
    sc = sidecar_path(matPath, opts);
    if isfile(sc)
        prov = jsondecode(fileread(sc));
        return
    end
    if ~isfile(matPath), return, end
    try
        vars = whos('-file', matPath);
        top = vars(1).name;
        m = matfile(matPath);
        S = m.(top);
        if isstruct(S) && isfield(S, 'prov'), prov = S.prov; end
    catch
    end
end
