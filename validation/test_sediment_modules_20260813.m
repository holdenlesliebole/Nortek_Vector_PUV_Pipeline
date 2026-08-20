%TEST_SEDIMENT_MODULES_20260813  Regression tests for the sediment helpers.
%
%   Run:  test_sediment_modules_20260813
%
%   Covers PUV_Pipeline/shared/{settling_velocity, rouse_number, wave_current_stress}
%   after the 2026-08-13 sediment-module audit (see docs/audit.md).
%
%   THE TEST THAT MATTERS MOST is the first one. settling_velocity's default C2
%   is 1.0, the Ferguson & Church NATURAL-GRAIN value. It was 0.4 (smooth
%   spheres) until 2026-08-13, which was simply wrong for Torrey sand and
%   understated Bailard q_s by 16-26% at the measured grain sizes. ws feeds q_s
%   inversely, so if this assertion ever fails someone has changed the default
%   and every transport number has silently moved with it.
%
%   Test 11 guards the other historic failure: Paper_1/DataCodes/PUV holds a
%   duplicate settling_velocity that shadowed the canonical one on the saved
%   MATLAB path and was missing a sqrt (Stokes collapse, ws 46% high at 246 um).
%   It asserts every copy on the path returns the same value.
%
% Author: Holden Leslie-Bole, 2026-08-13

addpath('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/shared');
ok = true;
chk = @(c,msg) fprintf('%-58s %s\n', msg, char(9989*c + 10060*~c));

% 1. settling_velocity default MUST be unchanged (Paper 1 depends on it)
ws = settling_velocity(246e-6, 2650, 1025, 1e-6);
D=246e-6; R=2650/1025-1; gg=9.81; C1=18; C2=1.0; nu=1e-6;   % C2=1.0 = natural grains
ref = (R*gg*D^2)/(C1*nu + sqrt(0.75*C2*R*gg*D^3));
c1 = abs(ws - ref) < 1e-12; ok = ok & c1;
chk(c1, sprintf('settling_velocity default = natural grains (%.7f vs ref %.7f)', ws, ref));

% 2. legacy 4-arg call still works with vector input
wsv = settling_velocity([100 200 300]*1e-6, 2650, 1025, 1e-6);
c2 = numel(wsv)==3 && all(diff(wsv)>0); ok = ok & c2;
chk(c2, 'settling_velocity vector input, monotonic in D');

% 3. explicit 'sphere' option recovers the old (wrong) value, ~18% higher
wsph = settling_velocity(246e-6, 2650, 1025, 1e-6, 'shape','sphere');
c3 = abs(wsph/ws - 1.1846) < 0.01; ok = ok & c3;
chk(c3, sprintf('C2 option: sphere/natural = %.3f (legacy was %.5f)', wsph/ws, wsph));

% 4. rouse_number legacy 3-arg call unchanged
P = rouse_number(0.036, 1.0, 1025);
c4 = abs(P - 0.036/(0.41*sqrt(1/1025))) < 1e-12; ok = ok & c4;
chk(c4, sprintf('rouse_number legacy scalar call (%.4f)', P));

% 5. per-fraction broadcasting -> [nFrac x nTime]
Pm = rouse_number([0.03;0.02;0.01], [0.5 1.0 2.0], 1025);
c5 = isequal(size(Pm),[3 3]) && all(diff(Pm(:,1))<0) && all(diff(Pm(1,:))<0); ok = ok & c5;
chk(c5, 'rouse_number broadcasts to [nFrac x nTime], both monotone');

% 6. regime classification
[~, reg] = rouse_number([0.5 1.0 2.0 5.0 10.0]*0.41*sqrt(1/1025), 1.0, 1025);
c6 = isequal(reg, {'wash load','full suspension','graded suspension','saltation','no suspension'});
ok = ok & c6; chk(c6, 'regime labels at P = 0.5/1/2/5/10');

% 7. wave_current_stress: no current -> no mean stress (the key physical check)
[tm, tx] = wave_current_stress(0, 5);
c7 = tm==0 && abs(tx-5)<1e-12; ok = ok & c7;
chk(c7, 'wave_current_stress: tau_c=0 -> tau_m=0, tau_max=tau_w');

% 8. no waves -> pure current
[tm2, tx2] = wave_current_stress(2, 0);
c8 = abs(tm2-2)<1e-12 && abs(tx2-2)<1e-12; ok = ok & c8;
chk(c8, 'wave_current_stress: tau_w=0 -> tau_m=tau_max=tau_c');

% 9. tau_m always between tau_c and tau_max, and enhanced over tau_c
[tm3, tx3] = wave_current_stress(0.1, 3);
c9 = tm3 > 0.1 && tm3 < tx3; ok = ok & c9;
chk(c9, sprintf('wave_current_stress: tau_c < tau_m < tau_max (%.3f)', tm3));

% 10. vector input preserves shape
[tmv, ~] = wave_current_stress([0.1 0.2 0.3], [1 2 3]);
c10 = isequal(size(tmv),[1 3]); ok = ok & c10;
chk(c10, 'wave_current_stress vector shape preserved');

% 11. the Paper_1 shadow now agrees with canonical
addpath('/Users/holden/Documents/Scripps/Research/Paper_1/DataCodes/PUV','-end');
w = which('settling_velocity','-all');
v = zeros(numel(w),1);
for i=1:numel(w)
    here = fileparts(w{i}); old = cd(here);
    v(i) = settling_velocity(246e-6,2650,1025,1e-6); cd(old);
end
c11 = max(abs(v - v(1))) < 1e-9; ok = ok & c11;
chk(c11, sprintf('shadow and canonical now agree (%d copies, spread %.2e)', numel(v), max(abs(v-v(1)))));

% 12. EVERY copy on the path must accept the SAME CALL, not just return the same
%     value. Added 2026-08-19: run_transport_model began forwarding 'shape', and the
%     Paper_1 shadow still had a 4-argument signature, so it threw "Too many input
%     arguments" wherever it won the path. That killed the Bailard M1 series and the
%     bailard animation variant, and test 11 did not catch it because the VALUES
%     agreed perfectly -- only the call did not.
c12 = true;
for i = 1:numel(w)
    here = fileparts(w{i}); old = cd(here);
    try
        settling_velocity(246e-6, 2650, 1025, 1e-6, 'shape', 'natural');
        settling_velocity(246e-6, 2650, 1025, 1e-6, 'shape', 'sphere');
        settling_velocity(246e-6, 2650, 1025, 1e-6, 'C2', 1.0);
    catch
        c12 = false;
    end
    cd(old);
end
ok = ok & c12;
chk(c12, sprintf('all %d copies accept the option signature', numel(w)));

if ok, fprintf('\nALL PASS\n'); else, fprintf('\nFAILURES PRESENT\n'); end
