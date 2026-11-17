function test_vector_beam_step()
%TEST_VECTOR_BEAM_STEP  Self-contained closure and break tests for the L1 beam-step correction.
%
% Run:  >> test_vector_beam_step
%
% No data needed. The base series is synthetic flow (two swell components plus
% noise) mapped to XYZ with a real head matrix (VEC 5724, TOR24S MOP586_5m .hdr),
% so this test is independent of any record. The real-data versions of these
% tests (T2 to T6 in docs/SPEC_L1_beam_step_correction_2026-11-13.md) are in
% validation/validate_beam_step_20261113.m.
%
% Checks (criteria fixed in the spec before any run):
%   C1 calm flow, Delta given 1.508 m/s: every injected step flagged exactly,
%      n/n per category; 0 false flags; untouched samples bitwise equal;
%      max |x' - x_clean| <= 1 mm/s
%   C2 calm flow, Delta estimated: |Delta_hat - 1.508| <= 0.010 m/s, flags as C1
%   C3 energetic flow (2.2 m/s orbital), Delta given: as C1, S7 exception
%   C4 energetic flow x 2.0, no injections: 0 corrected samples
%   C5 dense three-level flicker (POST HOC, see below)
%   B1-B5 break tests: each must make C1 fail or the corrector refuse, while the
%      unbroken C1 passes in the same run.
%
% 2026-11-13.
fprintf('\n=== test_vector_beam_step ===\n');
ok = true;
T = [2.6924 -1.3792 -1.3257; -0.0327 2.2444 -2.2178; 0.3604 0.3430 0.3298];
fs = 2;

[Xc, vc] = synth_flow(fs, 2, 0.35, 1);    % calm: 0.35 m/s orbital
[Xs, vs] = synth_flow(fs, 2, 2.2, 2);     % energetic: 2.2 m/s orbital
inj = struct();

% C1 unbroken
R1 = beam_step_closure(Xc, vc, fs, T, inj, struct('Delta', 1.508), T, 'calm');
ok = rep('C1 calm, Delta given: T2a', R1.pass_T2a, R1) && ok;

% C2
R2 = beam_step_closure(Xc, vc, fs, T, inj, struct(), T, 'calm est');
ok = rep(sprintf('C2 calm, Delta estimated %.4f m/s: T2b', R2.Delta), R2.pass_T2b, R2) && ok;

% C3
R3 = beam_step_closure(Xs, vs, fs, T, inj, struct('Delta', 1.508), T, 'energetic');
% C3's fixed criterion (T2a, S7 exception) FAILS: S6 59/60, one isolated sample between two
% short gaps missed. HLB accepted the rule with this failure as stated (2026-11-13, spec
% sec. 11 item 1). The check below is therefore a REGRESSION GUARD on that documented
% outcome, not the original criterion: every category except S6 and S7 n/n, S6 >= 59/60,
% S7 corrected or flagged, 0 wrong, 0 false flags.
fprintf('  [INFO] C3 original T2a criterion (S7 exception): %s (accepted failure)\n', ...
    string(R3.pass_T2a_stormS7exception));
c3 = all([R3.cat(1:5).exact] == [R3.cat(1:5).n]) && R3.cat(6).exact >= 59 && ...
     R3.cat(7).missed == 0 && all([R3.cat.wrong] == 0) && R3.nFalseFlagSamples == 0;
ok = rep('C3 energetic, Delta given: documented outcome held (guard)', c3, R3) && ok;

% C4: amplified energetic flow, no injections
[~, bs4] = vector_beam_step_correct(2.0 * Xs, vs, fs, T, struct('Delta', 1.508));
n4 = sum(any(bs4.k ~= 0, 2));
ok = rep(sprintf('C4 energetic x2.0, no steps: %d corrected', n4), n4 == 0, []) && ok;

% C5 (POST HOC, added 2026-11-13 after TOR17C's dense flicker exposed wrong
% corrections; criterion fixed before this check was first run): one hour of
% calm flow in which ~20% of samples sit on beam 2 at +Delta or -Delta, in runs
% of 1 to 5 samples separated by 1 to 10 clean samples. Every offset sample
% must be corrected exactly (n/n), 0 false flags, untouched samples bitwise.
[ok5, n5, e5, f5] = dense_flicker(Xc, vc, fs, T);
ok = rep(sprintf('C5 dense flicker (post hoc): %d/%d exact, %d false flags', e5, n5, f5), ok5, []) && ok;

% C6 (POST HOC, 2026-11-14, HLB ruling on TOR23W MOP580_7m; criterion fixed before
% its first run): only double steps (k = +2) injected, so Delta is not estimable.
% flagWhenNoDelta = false: status no_steps, nothing flagged or changed (this is also
% the break copy: without the option the steps go unflagged). true: status
% no_delta_flagged, exactly the injected samples flagged unconfirmed, values bitwise
% unchanged.
[ok6, msg6] = double_only(Xc, vc, fs, T);
ok = rep(['C6 double steps only, flagWhenNoDelta (post hoc): ' msg6], ok6, []) && ok;

% Break tests: each must FIRE (C1 fails or refuses)
Tc = T(:, [2 1 3]);
B1 = beam_step_closure(Xc, vc, fs, T, inj, struct('Delta', 1.508), Tc, 'B1');
ok = rep('B1 T columns 1,2 swapped: fires', ~B1.pass_T2a, B1) && ok;
B2 = beam_step_closure(Xc, vc, fs, T, inj, struct('Delta', 1.0), T, 'B2');
ok = rep(sprintf('B2 Delta = 1.0 m/s: fires (%s)', B2.status), ~B2.pass_T2a, B2) && ok;
Xz = Xc;  Xz(:, 3) = -Xz(:, 3);
Tz = T;   Tz(3, :) = -Tz(3, :);   % inject with the true head, then give the flipped series
B3 = beam_step_closure(Xz, vc, fs, Tz, inj, struct('Delta', 1.508), T, 'B3');
ok = rep('B3 Z sign flipped: fires', ~B3.pass_T2a, B3) && ok;
Tr = T([2 1 3], :);
B4 = beam_step_closure(Xc, vc, fs, T, inj, struct('Delta', 1.508), Tr, 'B4');
ok = rep('B4 T rows 1,2 swapped: fires', ~B4.pass_T2a, B4) && ok;
B5 = beam_step_closure(Xc, vc, fs, T, struct('Dinj', 1.30), struct(), T, 'B5');
ok = rep(sprintf('B5 steps of 1.30 m/s, Delta estimated: fires (%s)', B5.status), ...
    ~B5.pass_T2a && strcmp(B5.status, 'refused_delta'), B5) && ok;

fprintf('\n%s\n', repmat('-', 1, 60));
if ok, fprintf('ALL PASS\n'); else, error('test_vector_beam_step:FAIL', 'assertion failed'); end
end

% ----------------------------------------------------------------------
function [X, valid] = synth_flow(fs, days, A, seed)
% Two swell components (12 s and 7.3 s), a 0.1 m/s mean, slow modulation,
% vertical velocity in quadrature at 15% of horizontal, 0.02 m/s white noise per
% beam, mapped through the head matrix by the caller's convention (x = T*b is
% applied later; here X is built directly in XYZ, then noise is added in beams).
    rng(seed);
    N = round(days * 86400 * fs);
    t = (0:N-1).' / fs;
    env = 1 + 0.3 * sin(2*pi*t/(6*3600));
    u = 0.1 + A*env.*(0.8*cos(2*pi*t/12) + 0.45*cos(2*pi*t/7.3 + 1.1));
    v = 0.05 + 0.25*A*env.*cos(2*pi*t/12 + 0.7);
    w = 0.15*A*env.*sin(2*pi*t/12);
    T = [2.6924 -1.3792 -1.3257; -0.0327 2.2444 -2.2178; 0.3604 0.3430 0.3298];
    B = (T \ [u v w].').' + 0.02*randn(N, 3);
    X = (T * B.').';
    valid = rand(N, 1) > 0.01;   % 1% scattered QC dropouts
end

function [ok, n, nExact, nFalse] = dense_flicker(X, v, fs, T)
    rng(7);
    i0 = 100000;  N1 = 3600 * fs;  j = (i0:i0+N1-1).';
    X = X(j, :);  v = true(N1, 1);
    Kexp = zeros(N1, 3);  p = 50;
    while p < N1 - 60
        L = randi(5);  Kexp(p:p+L-1, 2) = 2*randi(2) - 3;
        p = p + L + randi(10);
    end
    Xi = X + (T * (Kexp.' * 1.508)).';
    [Xo, bs] = vector_beam_step_correct(Xi, v, fs, T, struct('Delta', 1.508));
    inj = any(Kexp ~= 0, 2);
    n = sum(inj);
    nExact = sum(inj & all(double(bs.k) == Kexp, 2));
    nFalse = sum(any(bs.k ~= 0, 2) & ~inj) + sum(inj & any(double(bs.k) ~= Kexp, 2) & any(bs.k ~= 0, 2));
    untouched = ~inj & ~any(bs.k ~= 0, 2);
    ok = nExact == n && nFalse == 0 && isequal(Xo(untouched, :), X(untouched, :));
    fprintf('         offset fraction %.1f%%\n', 100*mean(inj));
end

function [ok, msg] = double_only(X, v, fs, T)
    rng(11);  N = size(X, 1);  v = true(N, 1);
    p = 1000 + (0:19)' * 5000;  K = zeros(N, 3);  K(p, 2) = 2;
    Xi = X + (T * (K.' * 1.508)).';
    [X0, b0] = vector_beam_step_correct(Xi, v, fs, T, struct());
    [X1, b1] = vector_beam_step_correct(Xi, v, fs, T, struct('flagWhenNoDelta', true));
    inj = any(K ~= 0, 2);
    okOff = strcmp(b0.status, 'no_steps') && ~any(b0.unconfirmed) && isequal(X0, Xi);
    okOn  = strcmp(b1.status, 'no_delta_flagged') && isequal(b1.unconfirmed, inj) && isequal(X1, Xi) && ~any(b1.k(:));
    ok = okOff && okOn;
    msg = sprintf('off: %s, %d flagged; on: %s, %d/%d flagged exactly, values unchanged %d', ...
        b0.status, nnz(b0.unconfirmed), b1.status, nnz(b1.unconfirmed & inj), nnz(inj), isequal(X1, Xi));
end

function ok = rep(name, cond, R)
ok = logical(cond);
if ok, s = 'PASS'; else, s = 'FAIL'; end
fprintf('  [%s] %s\n', s, name);
if ~isempty(R) && isstruct(R) && isfield(R, 'cat')
    fprintf('         ');
    for c = 1:numel(R.cat)
        fprintf('%s %d/%d', R.cat(c).name, R.cat(c).exact, R.cat(c).n);
        if R.cat(c).unconfirmed, fprintf(' (+%d unconf)', R.cat(c).unconfirmed); end
        if R.cat(c).wrong, fprintf(' (%d WRONG)', R.cat(c).wrong); end
        if R.cat(c).missed, fprintf(' (%d missed)', R.cat(c).missed); end
        fprintf('; ');
    end
    fprintf('\n         false flags %d, untouched bitwise %d, max err %.2e m/s, status %s\n', ...
        R.nFalseFlagSamples, R.untouchedBitwise, R.maxErr, R.status);
end
end
