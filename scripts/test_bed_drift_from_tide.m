% TEST_BED_DRIFT_FROM_TIDE  Can the bed change be MEASURED instead of assumed?
%
%   A fixed doffp is wrong whenever the bed moves during a deployment, and we
%   have no morphology surveys to interpolate against. But we may not need one:
%   the instrument measures its own depth, and NOAA measures what the sea
%   surface actually did. The residual
%
%       resid(t) = depth_measured(t) - waterlevel_NOAA(t)
%                = -(doffp(t) - doffp_fixed) + setup + noise
%
%   carries the bed change directly. If the bed erodes, the sensor sits higher
%   above it, true depth grows, and because we hold doffp fixed the residual
%   FALLS by the same amount. Sign is negative.
%
%   THE REFERENCE MATTERS. L3.tidal.depth_pred uses the NOAA *prediction*, i.e.
%   astronomical tide only. Its residual therefore still contains storm surge
%   and seasonal/steric sea level, which in San Diego run 10-15 cm -- the same
%   size as the bed changes we are trying to detect, so the prediction cannot
%   separate the two. This script uses the *observed* hourly water level
%   instead, which removes both, and prints the two side by side so the size of
%   the confound is visible.
%
%   RUBY22 is the test case: three instruments, one deployment, one tide
%   reference, and field notes giving both endpoints.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv
addpath(fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox'));
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';

REC = { 'RUBY22','MOP578_10m', 0.79, 0.91, 'notes: scour, 12 cm'
        'RUBY22','MOP579_6m',  0.69, 0.70, 'notes: flat, 1 cm'
        'RUBY22','MOP582_30m', 0.80, 0.83, '30 m: bed should NOT move' };

for i = 1:size(REC,1)
    dep = REC{i,1}; lab = REC{i,2}; dd = REC{i,3}; dr = REC{i,4};
    fprintf('\n=== %s / %s  (%s) ===\n', dep, lab, REC{i,5});

    f2 = fullfile(root,'L2',dep,[lab '_L2.mat']);
    f3 = fullfile(root,'L3',dep,[lab '_L3.mat']);
    if ~isfile(f2) || ~isfile(f3), fprintf('  missing L2/L3\n'); continue, end
    L2 = getfield(load(f2,'L2'),'L2'); %#ok<GFLD>
    L3 = getfield(load(f3,'L3'),'L3'); %#ok<GFLD>

    d = L2.depth(:); sv = logical(L2.segValid(:)); t = L2.time(:);
    pr = NaN(size(d));
    if isfield(L3,'tidal') && isfield(L3.tidal,'depth_pred')
        pr = L3.tidal.depth_pred(:);
    end
    m = sv & isfinite(d);
    % relax: only require a valid depth, so short records survive
    if sum(m) < 100, fprintf('  SKIP: only %d valid depths\n', sum(m)); continue, end
    tv = t(m); dv = d(m);
    fprintf('  %d valid segments, %s to %s (%.0f days)\n', sum(m), ...
        string(tv(1),'dd-MMM-yyyy'), string(tv(end),'dd-MMM-yyyy'), days(tv(end)-tv(1)));

    % ---- observed NOAA water level, Scripps Pier ----
    obs = NaN(size(dv));
    try
        dn1 = datenum(tv(1)) - 1; dn2 = datenum(tv(end)) + 1;
        ot = {}; oh = []; cur = dn1;
        while cur < dn2
            e = min(cur + 30, dn2);
            [a,b] = getztide2(cur, e, 'gmt', 'msl', 'hourly_height');
            ot = [ot; a]; oh = [oh; double(b)]; %#ok<AGROW>
            cur = e;
        end
        [ot,iU] = unique(ot); oh = oh(iU);
        % requested time_zone=gmt, so the strings are already UTC -- do not tag
        % them, or they cannot be compared against the untagged PUV clock.
        odt = datetime(ot,'InputFormat','yyyy-MM-dd HH:mm');
        tvn = tv; if ~isempty(tvn.TimeZone), tvn.TimeZone = ''; end
        obs = interp1(odt, oh, tvn, 'linear', NaN);
        fprintf('  NOAA observed water level: %d hourly records\n', numel(oh));
    catch ME
        fprintf(2,'  NOAA observed download failed: %s\n', ME.message);
    end

    track = @(r) local_track(r);
    fprintf('  residual vs NOAA PREDICTION (astronomical only):\n');
    if any(isfinite(pr))
        rp = (dv - pr(m))*100; rp = rp - median(rp,'omitnan'); track(rp);
    else
        fprintf('    unavailable\n');
    end
    fprintf('  residual vs NOAA OBSERVED  (surge + steric removed):\n');
    if any(isfinite(obs))
        ro = (dv - obs)*100; ro = ro - median(ro,'omitnan'); track(ro);
        fprintf('    expected endpoint change from notes: %+.1f cm\n', -(dr-dd)*100);
    else
        fprintf('    unavailable\n');
    end
end

fprintf(['\nIf OBSERVED is markedly quieter than PREDICTION, the difference is ' ...
         'non-tidal\nsea level -- and only the OBSERVED residual can be read ' ...
         'as bed change.\n']);

function local_track(r)
    n = numel(r); if n < 20, fprintf('    too short\n'); return, end
    edges = round(linspace(1, n+1, 11)); dec = nan(1,10);
    fprintf('    ');
    for q = 1:10
        dec(q) = median(r(edges(q):edges(q+1)-1),'omitnan');
        fprintf('%+6.1f', dec(q));
    end
    hi = interp1(edges(1:10), dec, (1:n)','linear','extrap');
    fprintf('\n    end-start %+.1f cm | range %.1f cm | scatter %.1f cm\n', ...
        dec(end)-dec(1), max(dec)-min(dec), std(r-hi,'omitnan'));
end
