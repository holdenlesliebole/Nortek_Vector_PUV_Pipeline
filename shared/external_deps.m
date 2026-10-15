function D = external_deps(level)
% EXTERNAL_DEPS  Out-of-repo files a pipeline level needs, as resolved on the
% MATLAB path right now, with their SHA-256.
%
%   D = external_deps('L3')    struct array: .name .path .sha256 (.path '' and
%                              .sha256 'missing' when not found)
%   D = external_deps()        all levels' entries
%
% The list is static and comes from a matlab.codetools.requiredFilesAndProducts
% scan of each level's entry functions (2026-10-09): L1, L2, L4 and L4_xspec
% need nothing outside this repository; L3 needs the 11 files below (12 until
% 2026-10-15, when getztide2 was replaced by shared/noaa_tide_predictions so the
% NOAA station can be set per deployment; stamps made before then still list
% getztide2, and check_prov keeps comparing it while it is on the path).
%   - t_tide v1 (Pawlowicz, Beardsley & Lentz 2002), used directly by
%     PUV_L3_currents for the tidal fit: t_tide, t_predic, t_astron, t_getconsts,
%     t_vuf and its data files t_constituents.mat, t_equilib.dat, tide3.dat.
%     NOT redistributed here (its licence is informal). See README.md,
%     "External dependencies", for the version and where to get it. Lab copy:
%     Research/toolbox/t_tide_v1.3/ (moved 2026-10-12 from
%     "summer 2021 Maldives research/old code/t_tide_v1/", bytes unchanged,
%     so stamps made at the old path still pass check_prov, which compares
%     SHA-256 only).
%   - Research/toolbox: read_MOPline2 (CDIP MOP reader, used by PUV_L3_storms
%     through cdip_station_reference), which in turn needs get_k and xyRotate.
% build_provenance stamps this list for the level; check_prov SOFT-refuses a
% file whose recorded hash for any of these differs from the file found now.
% Re-run the scan when an entry function gains a dependency.
%
% Author: Holden Leslie-Bole, 2026

    L.L3 = {'t_tide.m','t_predic.m','t_astron.m','t_getconsts.m','t_vuf.m', ...
            't_constituents.mat','t_equilib.dat','tide3.dat', ...
            'read_MOPline2.m','get_k.m','xyRotate.m'};
    if nargin < 1
        names = unique([L.L3]);
    elseif isfield(L, level)
        names = L.(level);
    else
        names = {};
    end
    D = struct('name', {}, 'path', {}, 'sha256', {});
    for k = 1:numel(names)
        p = which(names{k});
        if isempty(p) || ~isfile(p)
            D(end+1) = struct('name', names{k}, 'path', '', 'sha256', 'missing'); %#ok<AGROW>
        else
            D(end+1) = struct('name', names{k}, 'path', p, 'sha256', file_sha256(p)); %#ok<AGROW>
        end
    end
end
