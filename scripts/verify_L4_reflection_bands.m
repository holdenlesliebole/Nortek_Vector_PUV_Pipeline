% VERIFY_L4_REFLECTION_BANDS  Scientific sanity checks on the refreshed
% L4.ref.byBand outputs before any reefbreak sync.
%
% Checks per instrument:
%   1. Back-compat regression — byBand.IG.R2 == old flat R2_IG to <1e-9
%   2. Per-band R2 medians (expect: roughly IG ~ swell ~ sea ordering, but
%      not strictly — spread leakage can lift swell/sea above unity)
%   3. sigma_theta within [0, pi/2] rad and energy-weighted
%   4. Hs/h and saturation_flag fraction
%   5. Ef sign + Ef_net consistency
%
% Prints a per-instrument table + cross-deployment summary.

startup_puv

root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline';
deps = dir(fullfile(root, 'outputs', 'L4'));
deps = deps([deps.isdir] & ~startsWith({deps.name}, '.'));

files = struct('path', {}, 'name', {}, 'dep', {});
for d = 1:numel(deps)
    f = dir(fullfile(deps(d).folder, deps(d).name, '*_L4.mat'));
    for k = 1:numel(f)
        files(end+1).path = fullfile(f(k).folder, f(k).name); %#ok<AGROW>
        files(end).name = f(k).name;
        files(end).dep  = deps(d).name;
    end
end

fprintf('\n=== L4 reflection-bands verification (%d files) ===\n', numel(files));
fprintf('%-30s | %-7s | R2: IG / swell / sea  | sat%%  | Hs/h med | sigma swell (deg) | Ef_IG med (W/m)\n', 'instrument');
fprintf('%s\n', repmat('-', 1, 130));

nOk = 0; nNan = 0; nFail = 0; nNoByBand = 0;
agg = struct('IG_R2',[], 'sw_R2',[], 'se_R2',[], 'sat',[], 'Hsh',[], ...
             'sig_sw_deg',[], 'Ef_IG',[], 'dep',{{}}, 'instr',{{}});

for i = 1:numel(files)
    fp = files(i).path;
    label = sprintf('%s/%s', files(i).dep, regexprep(files(i).name,'_L4.mat',''));
    try
        m = matfile(fp);
        L4 = m.L4;
        if ~isfield(L4, 'ref'), nFail = nFail + 1; fprintf('%-30s | NO L4.ref\n', label); continue; end
        if ~isfield(L4.ref, 'byBand')
            nNoByBand = nNoByBand + 1;
            fprintf('%-30s | NO byBand (refresh skipped this one)\n', label);
            continue
        end
        ref = L4.ref;

        % 1. Back-compat regression
        backcompat_ok = true;
        if isfield(ref, 'R2_IG')
            d = ref.R2_IG - ref.byBand.IG.R2;
            d = d(~isnan(d));
            if ~isempty(d) && max(abs(d)) > 1e-9
                backcompat_ok = false;
                fprintf('%-30s | BACKCOMPAT FAIL: max|R2_IG - byBand.IG.R2| = %.3g\n', label, max(abs(d)));
            end
        end

        r_ig    = median(ref.byBand.IG.R2,    'omitnan');
        r_sw    = median(ref.byBand.swell.R2, 'omitnan');
        r_se    = median(ref.byBand.sea.R2,   'omitnan');
        satFrac = 100*mean(ref.saturation_flag, 'omitnan');
        hsh_med = median(ref.Hs_over_h, 'omitnan');
        sig_sw  = median(ref.byBand.swell.sigma_theta, 'omitnan') * 180/pi;
        ef_med  = median(ref.byBand.IG.Ef_in - ref.byBand.IG.Ef_out, 'omitnan');

        flag = '';
        if all(isnan([r_ig r_sw r_se])), flag = ' [all-NaN]'; nNan = nNan + 1; end
        if ~backcompat_ok, flag = [flag ' [BACKCOMPAT]']; end %#ok<AGROW>
        fprintf('%-30s |%8s | %5.2f / %5.2f / %5.2f  | %5.1f | %7.3f | %15.1f   | %10.3f%s\n', ...
            label, '', r_ig, r_sw, r_se, satFrac, hsh_med, sig_sw, ef_med, flag);

        if backcompat_ok && ~all(isnan([r_ig r_sw r_se]))
            nOk = nOk + 1;
            agg.IG_R2(end+1) = r_ig;
            agg.sw_R2(end+1) = r_sw;
            agg.se_R2(end+1) = r_se;
            agg.sat(end+1)   = satFrac;
            agg.Hsh(end+1)   = hsh_med;
            agg.sig_sw_deg(end+1) = sig_sw;
            agg.Ef_IG(end+1) = ef_med;
            agg.dep{end+1}   = files(i).dep;
            agg.instr{end+1} = regexprep(files(i).name,'_L4.mat','');
        end
    catch ME
        fprintf('%-30s | LOAD FAIL: %s\n', label, ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\n=== Cross-deployment summary (n=%d valid) ===\n', nOk);
fprintf('  R2_IG    : median=%.3f, range=[%.3f, %.3f]\n',    median(agg.IG_R2), min(agg.IG_R2), max(agg.IG_R2));
fprintf('  R2_swell : median=%.3f, range=[%.3f, %.3f]\n',    median(agg.sw_R2), min(agg.sw_R2), max(agg.sw_R2));
fprintf('  R2_sea   : median=%.3f, range=[%.3f, %.3f]\n',    median(agg.se_R2), min(agg.se_R2), max(agg.se_R2));
fprintf('  sat %%    : median=%.1f, range=[%.1f, %.1f]\n',   median(agg.sat),   min(agg.sat),   max(agg.sat));
fprintf('  Hs/h med : median=%.3f, range=[%.3f, %.3f]\n',    median(agg.Hsh),   min(agg.Hsh),   max(agg.Hsh));
fprintf('  sig_swell: median=%.1f deg, range=[%.1f, %.1f]\n', median(agg.sig_sw_deg), min(agg.sig_sw_deg), max(agg.sig_sw_deg));
fprintf('  Ef_IG net: median=%.3f W/m, range=[%.3f, %.3f]\n', median(agg.Ef_IG), min(agg.Ef_IG), max(agg.Ef_IG));

fprintf('\nTotals: %d OK, %d all-NaN (expected: CAT), %d no-byBand, %d failed\n', ...
    nOk, nNan, nNoByBand, nFail);

% Flags for review
fprintf('\n=== Outliers to inspect ===\n');
if ~isempty(agg.IG_R2)
    [vmax, imax] = max(agg.IG_R2);
    fprintf('  Highest IG R2: %s/%s = %.3f (sat=%.0f%%, Hs/h=%.3f)\n', ...
        agg.dep{imax}, agg.instr{imax}, vmax, agg.sat(imax), agg.Hsh(imax));
    [vmin, imin] = min(agg.IG_R2);
    fprintf('  Lowest  IG R2: %s/%s = %.3f (sat=%.0f%%, Hs/h=%.3f)\n', ...
        agg.dep{imin}, agg.instr{imin}, vmin, agg.sat(imin), agg.Hsh(imin));
    [vsmax, ismax] = max(agg.sat);
    fprintf('  Most saturated: %s/%s sat=%.0f%% (Hs/h=%.3f)\n', ...
        agg.dep{ismax}, agg.instr{ismax}, vsmax, agg.Hsh(ismax));
end
