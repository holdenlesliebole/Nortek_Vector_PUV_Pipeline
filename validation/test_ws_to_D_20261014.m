%TEST_WS_TO_D_20261014  Closure tests for ws_to_D, the inverse of settling_velocity.
%
%   Run:  test_ws_to_D_20261014
%
%   Test 1 is independent of the code: the ws for 246 um under the default
%   (natural_nominal, 20/1.1) was hand-derived as 0.0278283 m/s in
%   test_sediment_modules_20260813, and inverting it must give back 246 um.
%   Tests 2-3 are round trips (forward then inverse) across sizes and shapes.
%   Test 4 checks the inverse is sensitive to the C1/C2 choice, so a caller who
%   passes the wrong shape gets a visibly different D rather than the same one.
%
% Author: Holden Leslie-Bole, 2026-10-14

addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'shared'));
ok = true; npass = 0; ntest = 0;
chk = @(c,msg) fprintf('%-66s %s\n', msg, char(9989*c + 10060*~c));

% 1. hand-derived value: ws = 0.0278283 m/s (quartz, rho 1025, nu 1e-6) -> 246 um
D1 = ws_to_D(0.0278283, 2650, 1025, 1e-6);
c = abs(D1*1e6 - 246) < 0.01; ok = ok & c; npass = npass + c; ntest = ntest + 1;
chk(c, sprintf('hand value: ws 0.0278283 m/s -> D = %.3f um (246)', D1*1e6));

% 2. round trip, default shape, 63 um to 2 mm (vector, shape preserved)
Din = [63 125 250 500 1000 2000]*1e-6;
Dout = ws_to_D(settling_velocity(Din, 2650, 998.2, 1.0e-6), 2650, 998.2, 1.0e-6);
err = max(abs(Dout./Din - 1));
c = isequal(size(Dout), size(Din)) && err < 1e-8; ok = ok & c; npass = npass + c; ntest = ntest + 1;
chk(c, sprintf('round trip 63-2000 um, default shape (max rel err %.1e)', err));

% 3. round trip under every shape option
shapes = {'natural_nominal','natural_sieve','angular','sphere'}; c = true;
for k = 1:numel(shapes)
    w = settling_velocity(Din, 2650, 998.2, 1.0e-6, 'shape', shapes{k});
    c = c && max(abs(ws_to_D(w, 2650, 998.2, 1.0e-6, 'shape', shapes{k})./Din - 1)) < 1e-8;
end
ok = ok & c; npass = npass + c; ntest = ntest + 1;
chk(c, 'round trip under all four shape options');

% 4. same ws, sieve vs nominal constants: D must differ (by > 3% at 250 um)
w = settling_velocity(250e-6, 2650, 998.2, 1.0e-6, 'shape', 'natural_nominal');
Ds = ws_to_D(w, 2650, 998.2, 1.0e-6, 'shape', 'natural_sieve');
c = abs(Ds/250e-6 - 1) > 0.03; ok = ok & c; npass = npass + c; ntest = ntest + 1;
chk(c, sprintf('shape matters: nominal ws read as sieve gives %.1f um, not 250', Ds*1e6));

% 5. invalid input -> NaN, not an error
c = all(isnan(ws_to_D([0 -0.01 NaN], 2650, 998.2, 1e-6))); ok = ok & c; npass = npass + c; ntest = ntest + 1;
chk(c, 'ws <= 0 or NaN returns NaN');

fprintf('\n%d/%d pass\n', npass, ntest);
if ok, fprintf('ALL PASS\n'); else, fprintf('FAILURES PRESENT\n'); end
