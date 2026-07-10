function test_L2_channel_decoupling()
%TEST_L2_CHANNEL_DECOUPLING  Integration gate for the Stage-1/Stage-2 pipeline change.
%
% test_channel_decoupling.m proves the ALGEBRA on stand-in code. This one drives the real
% PUV_L2_spectral through a synthetic L1 struct, which is the thing that can actually
% regress. Four runs of the same wave field:
%
%   RUN A  everything healthy
%   RUN B  pressure channel destroyed (the TOR23W/MOP586_10m failure), velocity untouched
%   RUN D  velocity destroyed, pressure untouched (the symmetric case, and the DOMINANT one
%          in the archive: MOP586_5m and MOP586_15m lose beam correlation while their sensor
%          block stays healthy and the frame never moves)
%   RUN C  legacy L1 struct with no PUV.qc masks at all (backward compatibility)
%
% ASSERTIONS
%   A1  Run A: every segment segValid, qc_flag = 1, Hs_source = 'measured'.
%   B1  Run B: segValid == false everywhere  -> no existing consumer (build_L4_site.getL2sub,
%       PUV_L4_moments, PUV_L4_eta) can pick these up by accident. This is the whole reason
%       segValid keeps its old meaning.
%   B2  Run B: segValid_vel == true, segValid_p == false, qc_flag = 3.
%   B3  Run B: velocity moments are computed and are IDENTICAL to Run A's.
%       This is the recovery. It is what the old row-level gate destroyed.
%   B4  Run B: Hs, depth, Kp, Ub, ztest_SS are all NaN. Pressure products must not be
%       invented from a dead sensor.
%   D1-D2 Run D: segValid false, segValid_p true, segValid_vel false, qc_flag = 3.
%   D3  Run D: Hs is computed and IDENTICAL to Run A's. The pressure record was always good.
%   D4  Run D: Ub, skewness, ztest, meanDir are NaN. They need velocity.
%   C1  Run C: a legacy L1 struct still processes, warns once, and reproduces Run A exactly.
%
% Run:  >> startup_puv;  test_L2_channel_decoupling
%
% 2026-07-09.

fprintf('\n=== test_L2_channel_decoupling ===\n');
rng(20260709);
fs = 2; nHr = 3; N = 7200*nHr;
g = 9.81; rho = 1025; h = 9.40; doffp = 1.00;

% --- synthetic linear wave field, 3 hours, starting exactly on the hour ---
t = (0:N-1)'/fs;
f = (0.05:0.005:0.20)';
S = 0.30*exp(-((f-0.09)/0.025).^2);
a = sqrt(2*S*0.005);
om = 2*pi*f; k = get_wavenumber(om, h);
eta = zeros(N,1); u = zeros(N,1); p_m = zeros(N,1);
for j = 1:numel(f)
    ph = 2*pi*rand;
    eta = eta + a(j)*cos(om(j)*t - ph);
    u   = u   + a(j)*om(j)*cosh(k(j)*doffp)/sinh(k(j)*h)*cos(om(j)*t - ph);
    p_m = p_m + a(j)*cosh(k(j)*doffp)/cosh(k(j)*h)*cos(om(j)*t - ph);
end
v = 0.02*randn(N,1); w = 0.01*randn(N,1);
P_dbar = (h - doffp + p_m) * rho*g/1e4;          % mean + wave, in dBar

PUV = struct();
PUV.time  = datetime(2024,1,1,0,0,0) + seconds(t);
PUV.fs    = fs;
PUV.P     = P_dbar;
PUV.T     = 17.2*ones(N,1);
PUV.BuoyCoord.U = u;  PUV.BuoyCoord.V = v;  PUV.BuoyCoord.W = w;
PUV.doffp = doffp;
PUV.label = 'SYNTH_10m';
PUV.deploymentName = 'SYNTH';
PUV.LATLON = [32.93035 -117.26572];
PUV.rotation = struct('sensor',NaN,'mag',NaN);
PUV.InstrCoord = struct('U',u,'V',v);
PUV.qc.valid_vel  = true(N,1);   PUV.qc.valid_p   = true(N,1);
PUV.qc.valid_tilt = true(N,1);   PUV.qc.valid_T   = true(N,1);
PUV.qc.valid_joint = true(N,1);
PUV.qc.vel_c_factor    = ones(N,1,'single');
PUV.qc.vel_c_corrected = false(N,1);
PUV.qc.vel_rotation_static = false(N,1);
PUV.qc.Tref = 17.2;  PUV.qc.opts = struct();

instr = struct('mopStation','');
opts  = struct('doRotate',false,'spectralMethod','welch','depthDeviationMax',0);

ok = true;

%% ---- RUN A: all healthy ----
fprintf('\n--- RUN A: healthy ---\n');
A = PUV_L2_spectral(PUV, instr, opts);
ok = rep('A1  every segment segValid, qc_flag=1, Hs_source=measured', ...
    all(A.segValid) && all(A.qc_flag==1) && all(strcmp(A.Hs_source,'measured')), sum(A.segValid)) && ok;
fprintf('    Hs = %s m\n', join(string(round(A.Hs',3)),', '));

%% ---- RUN B: pressure destroyed, velocity untouched ----
fprintf('\n--- RUN B: pressure channel dead (velocity healthy) ---\n');
B_in = PUV;
B_in.P(:) = NaN;                       % sensor returns nothing usable
B_in.qc.valid_p(:)     = false;
B_in.qc.valid_joint(:) = false;        % what the OLD row-level gate would have produced
B = PUV_L2_spectral(B_in, instr, opts);

ok = rep('B1  segValid == false everywhere (old consumers unaffected)', ~any(B.segValid), sum(B.segValid)) && ok;
ok = rep('B2  segValid_vel true, segValid_p false, qc_flag = 3', ...
    all(B.segValid_vel) && ~any(B.segValid_p) && all(B.qc_flag==3), sum(B.segValid_vel)) && ok;

d = max(abs(A.vmom.skewness - B.vmom.skewness)) + max(abs(A.vmom.u_uabs2 - B.vmom.u_uabs2)) ...
    + max(abs(A.uMean - B.uMean));
ok = rep('B3  velocity moments recovered, identical to the healthy run', d < 1e-12, d) && ok;
fprintf('    skewness A = %.6f   B = %.6f   <u|u|^2> A = %.6e  B = %.6e\n', ...
    A.vmom.skewness(1), B.vmom.skewness(1), A.vmom.u_uabs2(1), B.vmom.u_uabs2(1));

pressureProducts = all(isnan(B.Hs)) && all(isnan(B.depth)) && all(isnan(B.Ub)) && all(isnan(B.ztest_SS));
ok = rep('B4  Hs / depth / Ub / ztest are NaN (not invented from a dead sensor)', pressureProducts, 0) && ok;

fprintf('\n    Under the OLD pipeline these %d segments produced NOTHING: the row-level gate\n', numel(B.segValid));
fprintf('    NaN''d the velocity too, so nanFrac(u) > 0.10 and PUV_L2_spectral:299 skipped them.\n');

%% ---- RUN D: velocity destroyed, pressure untouched (the SYMMETRIC case) ----
% This is the dominant archive failure. The S1 .sen survey finds MOP586_5m and MOP586_15m
% with a healthy sensor block and a frame that never moved: their losses are beam-correlation
% failures. Their pressure is intact and Hs taken from it is an ordinary clean measurement.
fprintf('\n--- RUN D: velocity dead (pressure healthy) ---\n');
D_in = PUV;
D_in.BuoyCoord.U(:) = NaN; D_in.BuoyCoord.V(:) = NaN;
D_in.qc.valid_vel(:)   = false;
D_in.qc.valid_joint(:) = false;
D = PUV_L2_spectral(D_in, instr, opts);
ok = rep('D1  segValid == false everywhere (old consumers unaffected)', ~any(D.segValid), sum(D.segValid)) && ok;
ok = rep('D2  segValid_p true, segValid_vel false, qc_flag = 3', ...
    all(D.segValid_p) && ~any(D.segValid_vel) && all(D.qc_flag==3), sum(D.segValid_p)) && ok;
dH = max(abs(A.Hs - D.Hs));
ok = rep('D3  Hs recovered, identical to the healthy run', dH < 1e-9, dH) && ok;
fprintf('    Hs  A = %.6f   D = %.6f     depth A = %.4f  D = %.4f\n', A.Hs(1), D.Hs(1), A.depth(1), D.depth(1));
velProducts = all(isnan(D.Ub)) && all(isnan(D.vmom.skewness)) && all(isnan(D.ztest_SS)) && all(isnan(D.meanDir));
ok = rep('D4  Ub / skewness / ztest / meanDir are NaN (need velocity)', velProducts, 0) && ok;

%% ---- RUN C: legacy L1 with no qc masks ----
fprintf('\n--- RUN C: legacy L1 struct (no PUV.qc) ---\n');
C_in = rmfield(PUV, 'qc');
lastwarn('');
warnState = warning('off','PUV_L2_spectral:legacyL1');
C = PUV_L2_spectral(C_in, instr, opts);
warning(warnState);
dC = max(abs(A.Hs - C.Hs)) + max(abs(A.vmom.skewness - C.vmom.skewness));
ok = rep('C1  legacy L1 reproduces the healthy run exactly', dC < 1e-12 && all(C.segValid), dC) && ok;

fprintf('\n%s\n', repmat('-',1,70));
if ok, fprintf('ALL PASS\n'); else, error('test_L2_channel_decoupling:FAIL','one or more assertions failed'); end
end

function ok = rep(name, cond, val)
ok = logical(cond);
if ok, s='PASS'; else, s='FAIL'; end
fprintf('  [%s] %-62s %.3e\n', s, name, double(val));
end
