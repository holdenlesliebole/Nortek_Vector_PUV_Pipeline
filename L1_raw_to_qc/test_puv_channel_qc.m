function test_puv_channel_qc()
%TEST_PUV_CHANNEL_QC  Unit harness for the L1 per-channel QC decision logic.
%
% This drives the REAL puv_channel_qc function (the one PUV_raw_process calls) with
% synthetic DAT/SEN matrices that reproduce each failure mode in the archive. The previous
% suites re-implemented the masking algebra or hand-set the qc struct; this exercises the
% executed code, which is the point.
%
% Written test-first against the CORRECT intended behaviour. Against the pre-fix code, the
% scenarios that probe defects F1-F8 (docs/OUTSTANDING_channel_decoupling.md) are EXPECTED
% TO FAIL -- that is how we know the harness has teeth and the bugs are real. After the
% fixes land, all pass.
%
% Scenarios (each a 4-hour synthetic record at 2 Hz):
%   H  healthy
%   B  dead thermistor, still frame, healthy Doppler   (MOP586_10m: recover velocity, rescale)
%   T  healthy thermistor, TOPPLED frame               (MOP580_7m: reject velocity)
%   BT dead thermistor AND toppled frame               (F1/valid_vel: must still reject)
%   S  genuine >8 C seasonal sweep, all sensors healthy (F6: must NOT rescale)
%   D  on-deck warm-up before submersion               (F1/Tref: must not poison Tref)
%   W  whole-record dead thermistor                    (F2: static-tilt must not silently no-op-and-flag)
%
% Run:  >> startup_puv;  test_puv_channel_qc
%
% 2026-07-10.

fprintf('\n=== test_puv_channel_qc ===\n');
fs = 2; nHr = 4; N = round(fs*3600*nHr);
qcOpts = default_qcopts();
cfg = struct();               % no soundSpeedRef -> exercises the c(T) fit path
ok = true;

% c(T) reference: seawater sound speed, ~1447 + 4.0*(T-10) roughly; use a clean linear law.
cOfT = @(T) 1500 + 3.2*(T - 15);

%% ---------- H: everything healthy ----------
[DAT,SEN] = synth(N, fs, 'T',15, 'corr',95, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'H');
ok = rep('H1  all samples velocity-valid',        all(q.valid_vel), mean(q.valid_vel)) && ok;
ok = rep('H2  no sound-speed rescale (factor==1)', ~any(q.vel_c_corrected) && all(q.vel_c_factor==1), sum(q.vel_c_corrected)) && ok;
ok = rep('H3  tilt trusted, no static substitution', all(q.tilt_trusted) && ~any(q.vel_rotation_static), sum(q.vel_rotation_static)) && ok;

%% ---------- B: dead thermistor, still frame, healthy Doppler ----------
% Realistic: a long healthy window then a late failure (MOP586_10m ran 41 healthy days
% before failing). Last 25% reads -5 C; frame steady; correlation stays 94.
[DAT,SEN] = synth(N, fs, 'T',15, 'corr',94, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
dead = round(0.75*N)+1:N;  live = 1:round(0.75*N);
SEN(dead,14) = -5;  SEN(dead,10) = cOfT(-5);   % thermistor + the sound speed it drove
% The sensor-block failure also makes the tilt READING jittery (as at MOP586_10m, where
% pitchStd spiked while the frame stayed still) -> valid_tilt trips, so a static tilt from
% the healthy window is genuinely needed. Small absolute values: the frame did not topple.
SEN(dead,12) = 1.3 + 5*sin((1:numel(dead))'/3);   % |pitch| < 7, but high rolling std
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'B');
% Interior of the dead tail (past the tilt-variability window that straddles the transition):
% the whole point is that a dead thermistor does not kill velocity.
deadInt = dead(qcOpts.tiltWindow+1:end);
ok = rep('B1  velocity kept through the dead-thermistor tail', all(q.valid_vel(deadInt)), mean(q.valid_vel(deadInt))) && ok;
ok = rep('B2  rescale fires on the dead-T tail only', all(q.vel_c_corrected(dead)) && ~any(q.vel_c_corrected(live)), sum(q.vel_c_corrected)) && ok;
truef = cOfT(15)/cOfT(-5);
ok = rep('B3  rescale factor ~ c_true/c_rec', abs(median(double(q.vel_c_factor(dead)))-truef) < 0.01, median(double(q.vel_c_factor(dead)))) && ok;
ok = rep('B4  static tilt substituted where the block-failure jitters the tilt reading', ...
    any(q.vel_rotation_static(dead)) && isfinite(q.pStat), sum(q.vel_rotation_static(dead))) && ok;

%% ---------- T: healthy thermistor, toppled frame ----------
% roll ramps 0 -> -35 deg over the second half; thermistor fine.
[DAT,SEN] = synth(N, fs, 'T',15, 'corr',94, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
sec = round(0.5*N)+1:N;
SEN(sec,13) = linspace(-1, -35, numel(sec));
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'T');
toppled = abs(SEN(:,13)) >= qcOpts.tiltAbsMax;
ok = rep('T1  velocity REJECTED where frame is past tiltAbsMax', ~any(q.valid_vel(toppled)), sum(q.valid_vel(toppled))) && ok;
ok = rep('T2  no rescale (thermistor healthy)', ~any(q.vel_c_corrected), sum(q.vel_c_corrected)) && ok;
ok = rep('T3  no static-tilt substitution (tilt is trusted)', ~any(q.vel_rotation_static), sum(q.vel_rotation_static)) && ok;

%% ---------- BT: dead thermistor AND toppled frame (F1 escalation) ----------
% This is the dangerous compound case. With tilt_trusted = valid_T, a dead thermistor
% disables the topple gate and the toppled velocity would be KEPT. It must not be.
[DAT,SEN] = synth(N, fs, 'T',15, 'corr',94, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
dead = round(0.75*N)+1:N;
SEN(dead,14) = -5;  SEN(dead,10) = cOfT(-5);
SEN(dead,13) = linspace(-1, -35, numel(dead));    % and the frame falls over
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'BT');
toppled = abs(SEN(:,13)) >= qcOpts.tiltAbsMax;
ok = rep('BT1 velocity REJECTED on a toppled frame even with a dead thermistor', ...
    ~any(q.valid_vel(toppled)), sum(q.valid_vel(toppled))) && ok;

%% ---------- S: genuine seasonal drift, all sensors healthy (F6) ----------
% TmaxDev is a deviation from the first-48h MEDIAN, not a range, so the failure needs an
% ASYMMETRIC drift whose tail exceeds 8 C from the start-dominated reference: a warm summer
% start (75% at 20 C) then a genuine cold-upwelling tail (25% at 8 C, plausible seawater,
% HONEST sound speed). |8 - 20| = 12 > 8, so the deviation test mis-flags good cold water.
[DAT,SEN] = synth(N, fs, 'T',20, 'corr',95, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
cold = round(0.75*N)+1:N;
SEN(cold,14) = 8;  SEN(cold,10) = cOfT(8);   % genuine cold water, honest c
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'S');
ok = rep('S1  genuine cold-water tail does NOT trigger a rescale', ~any(q.vel_c_corrected), sum(q.vel_c_corrected)) && ok;
ok = rep('S2  genuine cold water keeps tilt trusted', all(q.tilt_trusted), mean(q.tilt_trusted)) && ok;
ok = rep('S3  all velocity kept, none corrupted', all(q.valid_vel) && all(q.vel_c_factor==1), sum(q.vel_c_corrected)) && ok;

%% ---------- D: on-deck warm-up before submersion (F1/Tref) ----------
% First 30 min the instrument is on deck at 25 C in air, out of water (p ~ 0); then in water
% at 15 C. A Tref that includes the deck period is biased warm and mis-flags good samples.
[DAT,SEN] = synth(N, fs, 'T',15, 'corr',95, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
deck = 1:round(fs*60*30);
SEN(deck,14) = 25;  SEN(deck,10) = cOfT(25);  DAT(deck,15) = 0.05;   % out of water: p ~ 0
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'D');
inwater = setdiff(1:N, deck);
ok = rep('D1  Tref ~ 15 C (water), not pulled toward 25 C (deck)', abs(q.Tref - 15) < 2, q.Tref) && ok;
ok = rep('D2  in-water samples keep tilt trusted', all(q.tilt_trusted(inwater)), mean(q.tilt_trusted(inwater))) && ok;
ok = rep('D3  no spurious rescale of good in-water velocity', ~any(q.vel_c_corrected(inwater)), sum(q.vel_c_corrected(inwater))) && ok;

%% ---------- W: whole-record dead thermistor (F2) ----------
% If the thermistor is dead for the ENTIRE record, there is no healthy window to draw a
% static tilt from. A toppled-or-not frame must not be silently marked "static-tilt applied"
% when no static tilt could be computed.
[DAT,SEN] = synth(N, fs, 'T',-5, 'corr',94, 'pitch',1.3, 'roll',-0.2, 'p',9.4, cOfT);
SEN(:,10) = cOfT(-5);
q = puv_channel_qc(DAT, SEN, fs, 9.4, cfg, qcOpts, 'W');
% pStat/rStat come from (valid_tilt & tilt_trusted); with no trusted tilt anywhere they are NaN.
if any(q.vel_rotation_static)
    ok = rep('W1  static-tilt flagged only if a static tilt actually exists', isfinite(q.pStat) && isfinite(q.rStat), double(isfinite(q.pStat))) && ok;
else
    ok = rep('W1  no static-tilt substitution claimed when none is computable', true, 0) && ok;
end

fprintf('\n%s\n', repmat('-',1,68));
if ok, fprintf('ALL PASS\n'); else, fprintf('SOME FAILED (expected against pre-fix code)\n'); end
end

% ---------------- helpers ----------------
function o = default_qcopts()
o = struct('corrMin',70,'Tvalid',[-2 40],'maxJump',Inf,'cFactorTol',0.002, ...
    'tiltStdMax',2,'tiltAbsMax',30,'tiltWindow',120);
end

function [DAT,SEN] = synth(N, fs, varargin) %#ok<INUSL>
% Build minimal DAT (>=15 col) and SEN (>=14 col) matrices with constant defaults, then
% overlay the named constants. cOfT is the LAST argument.
cOfT = varargin{end};  args = varargin(1:end-1);
p = struct('T',15,'corr',95,'pitch',1.3,'roll',-0.2,'p',9.4);
for k=1:2:numel(args), p.(args{k}) = args{k+1}; end
DAT = zeros(N,15);
DAT(:,3) = 0.10*randn(N,1);  DAT(:,4) = 0.05*randn(N,1);  DAT(:,5) = 0.02*randn(N,1);
DAT(:,12:14) = p.corr;       % beam correlations
DAT(:,15) = p.p;             % pressure dBar
SEN = zeros(N,14);
SEN(:,9)  = 14.4;            % battery
SEN(:,10) = cOfT(p.T);       % sound speed
SEN(:,11) = 78;             % heading
SEN(:,12) = p.pitch;
SEN(:,13) = p.roll;
SEN(:,14) = p.T;
end

function ok = rep(name, cond, val)
ok = logical(cond);
if ok, s='PASS'; else, s='FAIL'; end
fprintf('  [%s] %-62s %.4g\n', s, name, double(val));
end
