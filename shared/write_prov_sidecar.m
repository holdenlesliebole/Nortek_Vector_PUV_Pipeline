function sc = write_prov_sidecar(matPath, prov, opts)
% WRITE_PROV_SIDECAR  Write <matPath>.prov.json for an already-saved file.
%
%   sc = write_prov_sidecar(matPath, prov)
%   sc = write_prov_sidecar(matPath, prov, opts)
%
% Call AFTER the .mat is saved: the sidecar records file_sha256, the SHA-256 of
% the saved bytes, which an embedded block cannot contain. A sidecar whose
% file_sha256 differs from its .mat describes some other file, and
% copy_to_server refuses it ("modified outside the pipeline").
% Written to a temporary name and renamed, so a kill never leaves a partial
% sidecar. opts.sidecarRoot / opts.outRoot redirect it (see read_prov).
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 3, opts = struct(); end
    if ~isfile(matPath), error('write_prov_sidecar:noFile', 'no such file %s', matPath); end
    prov.file_sha256 = file_sha256(matPath);
    d = dir(matPath); prov.file_bytes = d.bytes;
    sc = sidecar_path(matPath, opts);
    if ~isfolder(fileparts(sc)), mkdir(fileparts(sc)); end
    tmp = [sc '.part'];
    fid = fopen(tmp, 'w');
    if fid < 0, error('write_prov_sidecar:open', 'cannot write %s', tmp); end
    % ConvertInfAndNaN false: the default writes Inf/NaN as null, which decodes to
    % [] and would no longer compare equal (e.g. qc.opts.maxJump = Inf)
    fwrite(fid, jsonencode(prov, 'PrettyPrint', true, 'ConvertInfAndNaN', false), 'char'); fclose(fid);
    movefile(tmp, sc);
end
