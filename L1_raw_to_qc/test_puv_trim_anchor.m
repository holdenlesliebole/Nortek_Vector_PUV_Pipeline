function test_puv_trim_anchor()
%TEST_PUV_TRIM_ANCHOR  Unit test for the channel-aware leading-NaN trim anchor (F5).
%
% Run:  >> test_puv_trim_anchor
%
% 2026-07-10.
fprintf('\n=== test_puv_trim_anchor ===\n');
ok = true;
N = 1000;

% Case A: normal -- leading pressure NaN (pre-submersion), then in-water. Anchor = first
% valid pressure sample, exactly the historical behaviour.
DAT = zeros(N,15);
DAT(1:200,15) = NaN;  DAT(201:end,15) = 9.4;
DAT(:,3) = 0.1; DAT(:,4) = 0.05;
ok = rep('A  normal: anchor on first valid pressure', puv_trim_anchor(DAT) == 201, puv_trim_anchor(DAT)) && ok;

% Case B: whole-deployment dead pressure, healthy Doppler. Old code THREW here, discarding
% good velocity. Anchor must fall back to the first valid velocity sample.
DAT = zeros(N,15);
DAT(:,15) = NaN;                          % pressure dead everywhere
DAT(1:150,3) = NaN; DAT(1:150,4) = NaN;   % leading pre-submersion velocity NaN
DAT(151:end,3) = 0.1; DAT(151:end,4) = 0.05;
ok = rep('B  dead pressure: anchor falls back to velocity', puv_trim_anchor(DAT) == 151, puv_trim_anchor(DAT)) && ok;

% Case C: both channels dead everywhere -> error (nothing to keep).
DAT = nan(N,15);
threw = false;
try, puv_trim_anchor(DAT); catch, threw = true; end
ok = rep('C  both dead: errors rather than returning garbage', threw, double(threw)) && ok;

fprintf('\n%s\n', repmat('-',1,50));
if ok, fprintf('ALL PASS\n'); else, error('test_puv_trim_anchor:FAIL','assertion failed'); end
end

function ok = rep(name, cond, val)
ok = logical(cond);
if ok, s='PASS'; else, s='FAIL'; end
fprintf('  [%s] %-46s %g\n', s, name, double(val));
end
