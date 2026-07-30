% TEST_BISPECTRAL_BOUND  Rule-4 synthetic closure test for the bispectral
% bound-energy estimator (PUV_paper todo #56).
%
% Pins every constant in the chain from a synthetic eta with a KNOWN bound
% amplitude through the ACTUAL production path -- PUV_L4_bispectra (nfft
% 2048, 50% overlap, mg 5 merging, fOut 0.3, complex-mean accumulation,
% stage-2 F3i rounding) -- to bound_energy_from_bispectrum. No constant is
% taken from memory; each expected value is hand-derived in the header of
% its test block.
%
% Conventions verified (bispectrum.m): A = fft/nfft so a cosine of
% amplitude a has |A| = a/2 and P = a^2/4 per bin; B = A1 A2 A3*, so a
% bound component theta3 = theta1 + theta2 + beta gives
% B = (a1 a2 ab / 8) e^{-i beta} and [Re B]^2/(P1 P2) = (ab^2/4) cos^2(beta).
%
% Design notes:
%  - All tone frequencies are multiples of the MERGED bin spacing
%    dfm = mg*fs/nfft = 0.0048828125 Hz, so every tone sits at a merged-bin
%    center and the F3i = round((f1+f2)/df)+1 mapping is exact.
%  - Every triad here is exactly resonant on the grid, so the 50%-overlap
%    sub-segments are COHERENT (the time shift adds 2*pi*(f1+f2-f3)*tau = 0
%    to the biphase): within-segment averaging does not decorrelate
%    anything, and cross-segment cancellation must be arranged explicitly.
%  - Where a cancellation is needed (two-pair cross terms, the exact null),
%    the relative phase is STEPPED uniformly over 2*pi across segments so
%    the incoherent term sums to zero deterministically -- the test then
%    checks bookkeeping, not statistical luck. One genuinely random-phase
%    null (TEST 4b) is kept as well, asserted against its expected
%    rectification floor ~ P3/(2*nSeg).
%
% Runtime: ~2-4 min (the L4 path is ~2.3 s per synthetic segment).

startup_puv;

fprintf('\n========== TEST_BISPECTRAL_BOUND (todo #56, Rule 4) ==========\n');

% Production parameters (PUV_L4_bispectra defaults -- do not change)
fs      = 2;                 % Hz
segLen  = 7200;              % samples = 1 hr
nfftSub = 2048;
mg      = 5;
dfm     = mg * fs / nfftSub; % merged bin spacing = 0.0048828125 Hz

% Merged-bin-center tone slots (frequency = n * dfm)
n1 = 16;  n2 = 21;  n3 = n1 + n2;    % 0.078125 + 0.102539 -> 0.180664 Hz
nD = 18;                              % diagonal case: 0.087891 -> 0.175781 Hz
nP = 14;  nQ = 23;                    % second pair, also summing to n3

rng(56, 'twister');   % deterministic; seed = todo item number

%% ---- TEST 0: conventions, single bispectrum() call --------------------
% x = a1 cos(th1) + a2 cos(th2) + ab cos(th1+th2), exact-bin tones.
% Expect P(f1) = a1^2/4, B(f1,f2) = a1 a2 ab/8 (real, positive), Bic = 1.
a1 = 0.5; a2 = 0.4; ab = 0.08;
t0   = (0:nfftSub-1)' / fs;
ph1  = 0.7; ph2 = -1.3;
x0   = a1*cos(2*pi*n1*dfm*t0 + ph1) + a2*cos(2*pi*n2*dfm*t0 + ph2) ...
     + ab*cos(2*pi*n3*dfm*t0 + ph1 + ph2);
bs   = bispectrum(x0, fs, mg, 0.3);

i1 = n1 + 1; i2 = n2 + 1; i3 = n3 + 1;   % f(1) = 0 => f(n+1) = n*dfm
assert(abs(bs.f(i1) - n1*dfm) < 1e-12 && abs(bs.f(i3) - n3*dfm) < 1e-12, ...
    'TEST 0 FAILED: merged grid is not f(n+1) = n*dfm.');

errP  = abs(bs.P(i1) - a1^2/4) / (a1^2/4);
Bexp  = a1*a2*ab/8;
errB  = abs(bs.B(i1,i2) - Bexp) / Bexp;    % complex error: checks Im ~ 0 too
errBic = abs(bs.Bic(i1,i2) - 1);
fprintf('\nTEST 0  conventions (single bispectrum call)\n');
fprintf('   P(f1) vs a1^2/4      : rel err %.2e\n', errP);
fprintf('   B(f1,f2) vs a1a2ab/8 : rel err %.2e\n', errB);
fprintf('   Bic(f1,f2) vs 1      : abs err %.2e\n', errBic);
assert(errP < 1e-2 && errB < 1e-2 && errBic < 1e-2, 'TEST 0 FAILED');
fprintf('   PASS\n');

%% ---- TEST 1: single mixed triad through the L4 path -------------------
% Random primary phases per segment, bound phase locked (beta = 0).
% Expect Eb(f3) = ab^2/4 from the single unordered pair (f1,f2); zero
% everywhere else; Bic_mean = 1 and Bip_mean = 0 at the cell.
nSeg = 6;
eta  = zeros(segLen, nSeg);
tt   = (0:segLen-1)' / fs;
for s = 1:nSeg
    p1 = 2*pi*rand; p2 = 2*pi*rand;
    eta(:,s) = a1*cos(2*pi*n1*dfm*tt + p1) + a2*cos(2*pi*n2*dfm*tt + p2) ...
             + ab*cos(2*pi*n3*dfm*tt + p1 + p2);
end
L4   = run_l4_path(eta, fs, segLen);
nf   = numel(L4.f);

Pana = zeros(nf, 1);                       % analytic P, checked vs path by TEST 0/Bic
Pana(i1) = a1^2/4;  Pana(i2) = a2^2/4;  Pana(i3) = ab^2/4;
Eb   = bound_energy_from_bispectrum(L4.B_mean, Pana, L4.f, struct('minP', 1e-12));

Etrue  = ab^2/4;
err1   = abs(Eb(i3) - Etrue) / Etrue;
leak   = sum(Eb([1:i3-1, i3+1:nf])) / Etrue;
errBic = abs(L4.Bic_mean(i1,i2) - 1);
errBip = abs(L4.Bip_mean(i1,i2));
fprintf('\nTEST 1  mixed triad, full L4 path (%d segments)\n', nSeg);
fprintf('   Eb(f3) = %.6e vs ab^2/4 = %.6e : rel err %.2e\n', Eb(i3), Etrue, err1);
fprintf('   sum of Eb off f3 (localization)     : %.2e of true\n', leak);
fprintf('   Bic_mean at cell vs 1               : abs err %.2e\n', errBic);
fprintf('   Bip_mean at cell vs 0               : abs err %.2e rad\n', errBip);
assert(err1 < 1e-2, 'TEST 1 FAILED: bound power not recovered');
assert(leak < 1e-2, 'TEST 1 FAILED: bound energy leaked off f3');
assert(errBic < 1e-2 && errBip < 1e-2, 'TEST 1 FAILED: Bic/Bip closure');
fprintf('   PASS\n');

%% ---- TEST 2: self-self (diagonal) harmonic ----------------------------
% eta = a cos(th) + ab cos(2 th). The (fD,fD) diagonal cell must be
% counted ONCE and recover Eb(2fD) = ab^2/4.
aD = 0.5; abD = 0.08;
iD = nD + 1; iD2 = 2*nD + 1;
eta = zeros(segLen, nSeg);
for s = 1:nSeg
    p = 2*pi*rand;
    eta(:,s) = aD*cos(2*pi*nD*dfm*tt + p) + abD*cos(2*pi*2*nD*dfm*tt + 2*p);
end
L4 = run_l4_path(eta, fs, segLen);

Pana = zeros(nf, 1);
Pana(iD) = aD^2/4;  Pana(iD2) = abD^2/4;
Eb = bound_energy_from_bispectrum(L4.B_mean, Pana, L4.f, struct('minP', 1e-12));

Etrue = abD^2/4;
err2  = abs(Eb(iD2) - Etrue) / Etrue;
fprintf('\nTEST 2  self-self harmonic (diagonal counted once)\n');
fprintf('   Eb(2fD) = %.6e vs ab^2/4 = %.6e : rel err %.2e\n', Eb(iD2), Etrue, err2);
assert(err2 < 1e-2, 'TEST 2 FAILED: diagonal bookkeeping wrong (2x => counted twice)');
fprintf('   PASS\n');

%% ---- TEST 3: two pairs into one sum bin + ordered-pair double-count ---
% Pairs (n1,n2) and (nP,nQ) both sum to n3, with bound amplitudes abA, abB.
% The two bound phasors share the f3 bin; each pair's estimator cell sees
% the OTHER pair's phasor as an incoherent term. Its relative phase is
% stepped uniformly over 2*pi across segments so it cancels EXACTLY:
% expect Eb(f3) = (abA^2 + abB^2)/4 to numerical precision.
% Then the ordered-pair (full anti-diagonal) sum must give exactly 2x --
% the double-count hazard flagged in todo #56.
c1 = 0.45; c2 = 0.35; abA = 0.08; abB = 0.06;
nSeg3 = 12;
iP = nP + 1; iQ = nQ + 1;
eta = zeros(segLen, nSeg3);
for s = 1:nSeg3
    p1 = 2*pi*rand; p2 = 2*pi*rand; q1 = 2*pi*rand;
    q2 = (p1 + p2) + 2*pi*(s-1)/nSeg3 - q1;   % steps (q1+q2)-(p1+p2) over 2*pi
    eta(:,s) = a1*cos(2*pi*n1*dfm*tt + p1) + a2*cos(2*pi*n2*dfm*tt + p2) ...
             + c1*cos(2*pi*nP*dfm*tt + q1) + c2*cos(2*pi*nQ*dfm*tt + q2) ...
             + abA*cos(2*pi*n3*dfm*tt + p1 + p2) ...
             + abB*cos(2*pi*n3*dfm*tt + q1 + q2);
end
L4 = run_l4_path(eta, fs, segLen);

Pana = zeros(nf, 1);
Pana(i1) = a1^2/4;  Pana(i2) = a2^2/4;
Pana(iP) = c1^2/4;  Pana(iQ) = c2^2/4;
Pana(i3) = (abA^2 + abB^2)/4;              % incoherent superposition at f3
Eb = bound_energy_from_bispectrum(L4.B_mean, Pana, L4.f, struct('minP', 1e-12));

Etrue = (abA^2 + abB^2)/4;
err3  = abs(Eb(i3) - Etrue) / Etrue;
fprintf('\nTEST 3  two unordered pairs into one bin (%d segments, stepped phases)\n', nSeg3);
fprintf('   Eb(f3) = %.6e vs (abA^2+abB^2)/4 = %.6e : rel err %.2e\n', ...
    Eb(i3), Etrue, err3);
assert(err3 < 2e-2, 'TEST 3 FAILED: pair-sum bookkeeping wrong');

% Ordered-pair sum along the full anti-diagonal: both contributing pairs
% are off-diagonal, so this must come out at exactly 2x the true value.
Eord = 0;
for j1 = 2:i3-1
    j2 = i3 + 1 - j1;
    if Pana(j1) > 1e-12 && Pana(j2) > 1e-12
        Eord = Eord + real(L4.B_mean(j1,j2))^2 / (Pana(j1)*Pana(j2));
    end
end
errOrd = abs(Eord - 2*Etrue) / (2*Etrue);
fprintf('   ordered-pair sum = %.6e = %.4f x true (expect 2.0000) : rel err %.2e\n', ...
    Eord, Eord/Etrue, errOrd);
assert(errOrd < 2e-2, 'TEST 3 FAILED: ordered sum is not exactly the 2x double-count');
fprintf('   PASS\n');

%% ---- TEST 4a: exact null (stepped free phase) -------------------------
% Free wave at f3 whose phase relative to (th1+th2) steps over 2*pi:
% <B> = 0 exactly, so Eb(f3) must be at numerical-leakage level.
a3 = 0.08;   % same power as the TEST 1 bound wave -- contrast is the point
nSeg4 = 12;
eta = zeros(segLen, nSeg4);
for s = 1:nSeg4
    p1 = 2*pi*rand; p2 = 2*pi*rand;
    p3 = (p1 + p2) + 2*pi*(s-1)/nSeg4;
    eta(:,s) = a1*cos(2*pi*n1*dfm*tt + p1) + a2*cos(2*pi*n2*dfm*tt + p2) ...
             + a3*cos(2*pi*n3*dfm*tt + p3);
end
L4 = run_l4_path(eta, fs, segLen);
Pana = zeros(nf, 1);
Pana(i1) = a1^2/4;  Pana(i2) = a2^2/4;  Pana(i3) = a3^2/4;
Eb = bound_energy_from_bispectrum(L4.B_mean, Pana, L4.f, struct('minP', 1e-12));
r4a = Eb(i3) / (a3^2/4);
fprintf('\nTEST 4a exact null (stepped phase, %d segments)\n', nSeg4);
fprintf('   Eb(f3)/P(f3) = %.2e (a bound wave of this power gives 1.0)\n', r4a);
assert(r4a < 1e-3, 'TEST 4a FAILED: exact-cancellation null not ~0');
fprintf('   PASS\n');

%% ---- TEST 4b: random-phase null ---------------------------------------
% Same construction, genuinely random p3. Expected rectification floor for
% M independent segments: E[Eb(f3)] ~ P3/(2M) (Re part of an M-average of
% unit-modulus random phasors). Assert well below the bound-wave answer.
nSeg4b = 40;
eta = zeros(segLen, nSeg4b);
for s = 1:nSeg4b
    p1 = 2*pi*rand; p2 = 2*pi*rand; p3 = 2*pi*rand;
    eta(:,s) = a1*cos(2*pi*n1*dfm*tt + p1) + a2*cos(2*pi*n2*dfm*tt + p2) ...
             + a3*cos(2*pi*n3*dfm*tt + p3);
end
L4 = run_l4_path(eta, fs, segLen);
Eb = bound_energy_from_bispectrum(L4.B_mean, Pana, L4.f, struct('minP', 1e-12));
r4b   = Eb(i3) / (a3^2/4);
floor4b = 1 / (2*nSeg4b);
fprintf('\nTEST 4b random-phase null (%d segments)\n', nSeg4b);
fprintf('   Eb(f3)/P(f3) = %.3e; expected floor ~1/(2M) = %.3e\n', r4b, floor4b);
assert(r4b < 0.10, 'TEST 4b FAILED: random-phase null too large');
fprintf('   PASS  (floor scales as 1/(2M); L4 records average ~1300 hrs, so this is negligible there)\n');

%% ---- TEST 5: nonzero biphase ------------------------------------------
% th3 = th1 + th2 + beta with beta = pi/3. The Re-projection estimator
% must return (ab^2/4) cos^2(beta) = (ab^2/4)/4, and the measured biphase
% is -beta (B = A1 A2 A3* => phase(B) = -beta). The production analysis
% checks Bip_mean ~ 0 in the coupling region before trusting Re B; this
% test pins what a violated check would do to the number.
beta = pi/3;
eta  = zeros(segLen, nSeg);
for s = 1:nSeg
    p1 = 2*pi*rand; p2 = 2*pi*rand;
    eta(:,s) = a1*cos(2*pi*n1*dfm*tt + p1) + a2*cos(2*pi*n2*dfm*tt + p2) ...
             + ab*cos(2*pi*n3*dfm*tt + p1 + p2 + beta);
end
L4 = run_l4_path(eta, fs, segLen);
Pana = zeros(nf, 1);
Pana(i1) = a1^2/4;  Pana(i2) = a2^2/4;  Pana(i3) = ab^2/4;
Eb = bound_energy_from_bispectrum(L4.B_mean, Pana, L4.f, struct('minP', 1e-12));

Etrue = (ab^2/4) * cos(beta)^2;
err5  = abs(Eb(i3) - Etrue) / Etrue;
errBp = abs(L4.Bip_mean(i1,i2) - (-beta));
fprintf('\nTEST 5  biphase beta = pi/3\n');
fprintf('   Eb(f3) = %.6e vs (ab^2/4)cos^2(beta) = %.6e : rel err %.2e\n', ...
    Eb(i3), Etrue, err5);
fprintf('   Bip_mean at cell = %.4f rad vs -beta = %.4f : abs err %.2e\n', ...
    L4.Bip_mean(i1,i2), -beta, errBp);
assert(err5 < 2e-2, 'TEST 5 FAILED: cos^2(beta) projection wrong');
assert(errBp < 2e-2, 'TEST 5 FAILED: biphase sign convention wrong');
fprintf('   PASS\n');

fprintf('\n========== ALL TESTS PASSED ==========\n');
fprintf(['Pinned: P = a^2/4; B = a1a2ab/8; Eb per unordered pair, diagonal\n' ...
         'once, ordered sum = 2x; null floor ~ 1/(2M); Re-projection = cos^2(beta),\n' ...
         'measured biphase = -beta. Safe to build analyze_bispectral_beta.m on\n' ...
         'shared/bound_energy_from_bispectrum.m.\n']);

%% ---- local helpers ----------------------------------------------------
function L4 = run_l4_path(eta, fs, segLen)
% Minimal L2 stand-in; runs the ACTUAL PUV_L4_bispectra with its defaults
% (nfft 2048, overlap 0.5, mg 5, fOut 0.3).
nSeg = size(eta, 2);
L2 = struct();
L2.time     = datetime(2024,1,1) + hours(0:nSeg-1)';
L2.segValid = true(nSeg, 1);
L2.params.segLen = segLen;
L2.fs       = fs;
L4 = PUV_L4_bispectra(eta, L2, struct());
end
