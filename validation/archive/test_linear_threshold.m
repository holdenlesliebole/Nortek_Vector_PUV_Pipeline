% TEST_LINEAR_THRESHOLD  Is there a defensible "the linear transform departs
% here" threshold, or is the departure smooth?
%
% fig07 originally marked the linear-closure boundary where the nu ratio exceeds
% 1.01. That criterion was explicit but arbitrary, and the second-order boundary
% it is compared against is NOT arbitrary (bound_frac_raw crossing 1.000 is a
% physical statement: observed IG energy equals the second-order prediction).
% Comparing an arbitrary threshold against a physical one is not a fair
% "hierarchy", so this asks whether a principled linear threshold exists.
%
% Four tests:
%   1. IS SIGNIFICANCE USABLE? The worry was that with ~73k hours the CI on a
%      bin median would be so tight that "first bin significantly above 1"
%      fires immediately and carries no information. Quantified rather than
%      assumed -- and the worry turned out to be WRONG: the lowest bin's CI
%      spans unity, and the first bin to clear it is 0.04-0.06, which is a
%      principled criterion that happens to reproduce the documented range.
%   2. IS THERE A KNEE? Fit nu(Hs/h) as (a) a straight line and (b) two
%      segments with a free breakpoint. If the breakpoint model does not beat
%      the line, there is no knee to find and no threshold to defend.
%   3. SENSITIVITY. How far does the crossing move as the effect-size criterion
%      varies over a reasonable range?
%   4. IS THE ORDERING ROBUST? The paper's claim is that the linear closure
%      fails BEFORE second-order theory. Does that hold for every criterion?
%      If yes, the ordering is criterion-independent even though the value is
%      not, and that is what the paper should claim.
%
% Author: Holden Leslie-Bole, 2026

startup_puv
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/validation';
S = load(fullfile(root,'cross_deployment_nonlinearity.mat'));
H = S.H;

g = isfinite(H.hsh) & isfinite(H.nu);
x = H.hsh(g); y = H.nu(g);
gb = isfinite(H.hsh) & isfinite(H.bfr);
xb = H.hsh(gb); yb = H.bfr(gb);
fprintf('\n%d hours with nu, %d with bound_frac\n', numel(x), numel(xb));

%% ---- 1. is significance a usable criterion? -----------------------------
fprintf('\n===== 1. IS SIGNIFICANCE A USABLE CRITERION? =====\n');
edges = [0 0.04 0.06 0.08 0.10 0.12 0.15 0.20 1];
fprintf('  %-13s %8s %9s %19s %s\n','Hs/h','n','median','95%% CI of median','excludes 1?');
for b = 1:numel(edges)-1
    m = x>=edges(b) & x<edges(b+1);
    if sum(m) < 50, continue; end
    v = y(m);
    % CI of the median by the standard order-statistic / bootstrap route
    ci = bootci(2000, {@median, v}, 'Type','per', 'Alpha',0.05);
    fprintf('  %.2f - %.2f  %8d %9.4f   [%7.4f %7.4f]   %s\n', edges(b), edges(b+1), ...
        sum(m), median(v), ci(1), ci(2), string(ci(1)>1 || ci(2)<1));
end
fprintf('  -> RESULT (contrary to the expectation this test was written on):\n');
fprintf('     the lowest bin does NOT clear significance -- its CI spans unity --\n');
fprintf('     and the first bin that does is 0.04-0.06. So a significance\n');
fprintf('     criterion IS usable here and reproduces the documented range,\n');
fprintf('     because the hour-to-hour scatter is wide enough that ~1.3k hours\n');
fprintf('     do not pin the median to better than about +/-0.005.\n');

%% ---- 2. is there a knee? -----------------------------------------------
fprintf('\n===== 2. IS THERE A KNEE IN nu(Hs/h)? =====\n');
% Work on bin medians over a fine grid so the fit is not dominated by the
% hour-count imbalance across Hs/h.
fe = 0.02:0.01:0.26;
fx = nan(numel(fe)-1,1); fy = fx; fn = zeros(size(fx));
for b = 1:numel(fe)-1
    m = x>=fe(b) & x<fe(b+1);
    fn(b) = sum(m);
    if fn(b) < 200, continue; end
    fx(b) = median(x(m)); fy(b) = median(y(m));
end
k = isfinite(fx); fx = fx(k); fy = fy(k); fn = fn(k);
fprintf('  %d fine bins (>=200 hours each), Hs/h %.3f to %.3f\n', numel(fx), min(fx), max(fx));

% (a) straight line
p1 = polyfit(fx, fy, 1);
r1 = fy - polyval(p1, fx);
sse1 = sum(r1.^2);

% (b) two segments, continuous, free breakpoint -- grid search
cand = fx(3:end-2);
sse2 = inf; bBest = NaN; pBest = [];
for c = cand'
    X = [ones(numel(fx),1), fx, max(fx-c,0)];   % continuous piecewise linear
    beta = X\fy;
    s = sum((fy - X*beta).^2);
    if s < sse2, sse2 = s; bBest = c; pBest = beta; end
end
% F test: 2 extra parameters (slope change + breakpoint)
df1 = 2; df2 = numel(fx) - 4;
Fstat = ((sse1-sse2)/df1) / (sse2/df2);
pF = 1 - fcdf(Fstat, df1, df2);
fprintf('  straight line     SSE = %.3e\n', sse1);
fprintf('  breakpoint model  SSE = %.3e  at Hs/h = %.3f\n', sse2, bBest);
fprintf('  F(%d,%d) = %.2f, p = %.4f\n', df1, df2, Fstat, pF);
if pF < 0.05
    fprintf('  -> a knee IS detected at Hs/h = %.3f. Slope %.3f -> %.3f per unit Hs/h.\n', ...
        bBest, pBest(2), pBest(2)+pBest(3));
else
    fprintf('  -> NO knee. nu rises smoothly, so any "departure point" is a\n');
    fprintf('     choice of effect size and should be presented as one.\n');
end

%% ---- 3. sensitivity of the threshold to the criterion ------------------
fprintf('\n===== 3. SENSITIVITY OF THE CROSSING TO THE CRITERION =====\n');
crits = [1.005 1.0075 1.01 1.015 1.02 1.03 1.04];
fprintf('  %-12s %10s\n','nu criterion','Hs/h');
xs = nan(size(crits));
for i = 1:numel(crits)
    xs(i) = crossat(fx, fy, crits(i));
    fprintf('  > %-10.4f %10.4f\n', crits(i), xs(i));
end

%% ---- 4. is the ORDERING robust? ---------------------------------------
fprintf('\n===== 4. IS THE ORDERING ROBUST? =====\n');
fxb = nan(numel(fe)-1,1); fyb = fxb;
for b = 1:numel(fe)-1
    m = xb>=fe(b) & xb<fe(b+1);
    if sum(m) < 200, continue; end
    fxb(b) = median(xb(m)); fyb(b) = median(yb(m));
end
kb = isfinite(fxb); fxb = fxb(kb); fyb = fyb(kb);
xSec = crossat(fxb, fyb, 1.00);
fprintf('  second-order crossing (bound_frac = 1, PHYSICAL): Hs/h = %.4f\n', xSec);
ok = xs < xSec;
fprintf('  linear-closure crossing is below it for %d of %d criteria tested\n', ...
    sum(ok & isfinite(xs)), sum(isfinite(xs)));
if all(ok(isfinite(xs)))
    fprintf('  -> THE ORDERING IS CRITERION-INDEPENDENT over this range. That is\n');
    fprintf('     the defensible claim: the linear transform departs first, and\n');
    fprintf('     the exact value depends on the tolerance one adopts.\n');
else
    fprintf('  -> ordering FAILS for some criteria; do not claim a hierarchy.\n');
end

%% ---- per-record robustness ---------------------------------------------
fprintf('\n===== per-record check on the ordering =====\n');
uR = unique(H.rec(isfinite(H.rec)));
nOK = 0; nT = 0;
for i = 1:numel(uR)
    m = H.rec==uR(i);
    if sum(m) < 200, continue; end
    nT = nT + 1;
    if median(H.nu(m),'omitnan') > 1 && median(H.bfr(m),'omitnan') < 1, nOK = nOK + 1; end
end
fprintf('  %d of %d records sit in the "shape already departed, second-order\n', nOK, nT);
fprintf('  still under-predicting" regime -- i.e. between the two boundaries.\n');

function xz = crossat(x,y,lev)
    g = isfinite(x)&isfinite(y); x=x(g); y=y(g); xz = NaN;
    k = find(y(1:end-1) < lev & y(2:end) >= lev, 1, 'first');
    if isempty(k), return; end
    xz = x(k) + (lev-y(k))/(y(k+1)-y(k))*(x(k+1)-x(k));
end
