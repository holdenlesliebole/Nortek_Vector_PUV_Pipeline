% CHECK_LATLON_VS_BATHY  Independent test of the corrected coordinates.
%
%   An earlier version of this script scored coordinate sets by how CONSTANT
%   the implied slope was. That is the wrong null: a real profile is concave
%   (Dean, h ~ A x^(2/3)), so a planar-beach test rewards evenly spaced
%   positions -- which is exactly the artefact a hand-drawn approximation has.
%
%   This version uses an origin-independent form of the Dean profile. If
%   h = A x^(2/3) then x ~ h^(3/2), so between any two instruments
%
%       separation / ( h_j^1.5 - h_i^1.5 )  =  constant
%
%   No shoreline origin is needed, and the constant is the same for every
%   segment of a real transect. Whichever coordinate set holds that ratio
%   steadier is the one consistent with the measured bathymetry.
%
%   TOR23W is the control: its surveyed coordinates were verified digit for
%   digit against DeploymentNotes2023-2024.xls, so whatever score IT earns is
%   what a known-good coordinate set looks like here.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';

LAB = {'MOP586_5m','MOP586_7m','MOP586_10m','MOP586_15m'};
ROUND = [32.930 -117.264; 32.930 -117.265; 32.930 -117.266; 32.930 -117.270];
SURV  = [32.93056 -117.26319; 32.93048 -117.26420
         32.93035 -117.26572; 32.93005 -117.26950];

DEPS = {'TOR23W','TOR24S','TOR24W','TOR25S'};

for dd = 1:numel(DEPS)
    dep = DEPS{dd};
    d = nan(4,1);
    for i = 1:4
        f = fullfile(root,'L2',dep,[LAB{i} '_L2.mat']);
        if ~isfile(f), continue, end
        L2 = getfield(load(f,'L2'),'L2'); %#ok<GFLD>
        v = logical(L2.segValid(:)) & isfinite(L2.depth(:));
        if any(v), d(i) = median(L2.depth(v)); end
    end
    have = find(isfinite(d));
    if numel(have) < 3
        fprintf('\n=== %s: only %d instruments with depth -- skipped\n', dep, numel(have));
        continue
    end

    tag = '';
    if strcmp(dep,'TOR23W'), tag = '   [CONTROL: coordinates already verified]'; end
    fprintf('\n=== %s ===%s\n', dep, tag);
    fprintf('  depths:');
    for i = have', fprintf(' %s=%.2f', LAB{i}, d(i)); end
    fprintf('\n');

    for variant = 1:2
        if variant == 1, C = ROUND; nm = 'ROUNDED  ';
        else,            C = SURV;  nm = 'SURVEYED '; end
        if strcmp(dep,'TOR23W') && variant == 1
            nm = 'ROUNDED  (hypothetical -- TOR23W never used these)';
        end
        r = [];
        for k = 1:numel(have)-1
            i = have(k); j = have(k+1);
            mlat = deg2rad((C(i,1)+C(j,1))/2);
            L = hypot((C(j,2)-C(i,2))*111320*cos(mlat), (C(j,1)-C(i,1))*110904);
            r(end+1) = L / (d(j)^1.5 - d(i)^1.5); %#ok<SAGROW>
        end
        fprintf('  %-52s ratios:', nm);
        fprintf(' %6.2f', r);
        fprintf('   spread %.2f\n', max(r)/min(r));
    end
end

fprintf(['\nRatios should be equal across segments for a real Dean profile.\n' ...
         'Compare each deployment against the TOR23W control.\n']);
