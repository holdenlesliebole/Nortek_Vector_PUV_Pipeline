function prov = save_with_provenance(f, level, varName, S, parents, instr)
% SAVE_WITH_PROVENANCE  Stamp a level struct, save it, and write its sidecar.
%
%   prov = save_with_provenance(f, level, varName, S, parents)
%   prov = save_with_provenance(f, level, varName, S, parents, instr)
%
% f        output .mat path
% level    'L1' | 'L2' | 'L3' | 'L4' | 'L4_xspec' (see build_provenance)
% varName  variable name in the .mat: 'PUV', 'L2', 'L3', 'L4' or 'L4xs'
% S        the level struct (any old .prov field is replaced)
% parents  struct array (.level, .path) of the files this build loaded:
%          L2 <- L1; L3 <- L2; L4 <- L2; L4_xspec <- every member L4.
%          [] for L1.
% instr    the config instrument struct used for the build ([] for xspec)
%
% Order: the provenance is built BEFORE anything is written, so a build that
% cannot be stamped (code shadowed from another checkout, an external
% dependency missing) writes no file at all. Then the struct is saved with the
% embedded prov, reloaded and compared, and <f>.prov.json is written with the
% sha256 of the saved bytes (write_prov_sidecar).
%
% Used by the PUV_L*_driver and PUV_L*_run_all scripts so that their outputs
% carry the same stamp as scripts/rerun_heading_ws_2026_10_07.m (stamp_save),
% and therefore pass scripts/copy_to_server.m's provenance gate.
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 5 || isempty(parents), parents = struct('level', {}, 'path', {}); end
    if nargin < 6, instr = []; end
    if isfield(S, 'prov'), S = rmfield(S, 'prov'); end
    prov = build_provenance(level, S, parents, instr);
    S.prov = prov;
    tmpS.(varName) = S;
    save(f, '-struct', 'tmpS', '-v7.3');
    q = load(f, varName);
    if ~isequaln(q.(varName), S)
        error('save_with_provenance:reload', 'reloaded %s differs from the one saved: %s', varName, f);
    end
    write_prov_sidecar(f, prov);
end
