function test_L2_velgap()
%TEST_L2_VELGAP  L2 treats L1 beam-step-unconfirmed samples and instr.velInvalidFrom as gaps.
%
% HLB decisions 2 and 4 of 2026-11-13 (docs/SPEC_L1_beam_step_correction_2026-11-13.md,
% sec. 11). Drives the real PUV_L2_spectral through a synthetic 3-hour L1 struct (the
% generator of test_L2_channel_decoupling). Criteria fixed before the first run. The record
% is 4 h long from 00:00:00; L2 skips to the next top of hour (01:00), so its segments
% s = 1..3 are samples s*7200 + (1:7200) and "hour 2" below means segment 2.
%
%   G1  no flags, no cutoff: every L2 field identical (isequaln) to a run of an L1 struct
%       without the new field at all. The change is a no-op on clean data.
%   G2  1,000 unconfirmed samples in hour 2 (13.9% > nanMaxFrac 10%): segValid_vel(2) and
%       segValid(2) false; hours 1 and 3 identical to G1 in Hs, u_uabs3, Ub.
%   G3  10 unconfirmed samples in hour 2: its velocity moments equal, exactly, those of a run
%       in which the same samples are NaN in the L1 velocity itself (gap = gap); they differ
%       from G1's; L2.velGap.nUnconfirmed = 10.
%   G4  instr.velInvalidFrom = hour 2 start + 30 min: segValid_vel and segValid false in
%       hours 2 and 3, hour 1 identical to G1, Hs in hours 2 and 3 identical to G1 (pressure
%       untouched), L2.velGap.nCutoff = 1.5 h of samples.
%   Breaks (each must make its check fail, while the check passes above):
%       B-G3  the flag stored under a misspelled field name;
%       B-G4  the cutoff stored under a misspelled field name.
%
% Run:  >> startup_puv;  test_L2_velgap
% 2026-11-13.

fprintf('\n=== test_L2_velgap ===\n');
[PUV, instr, opts] = synth();
N = numel(PUV.time);  seg = 7200;
ok = true;
run = @(P, I) quiet_L2(P, I, opts);

L0 = run(PUV, instr);                                   % no new field anywhere
P1 = PUV;  P1.qc.vel_beamstep_unconfirmed = false(N, 1);
L1 = run(P1, instr);
ok = rep('G1 no flags: identical to L1 without the field', isequaln(strip(L0), strip(L1))) && ok;

P2 = P1;  P2.qc.vel_beamstep_unconfirmed(2*seg + (1:1000)) = true;
L2 = run(P2, instr);
c2 = ~L2.segValid_vel(2) && ~L2.segValid(2) && ...
     isequaln(L2.Hs([1 3]), L1.Hs([1 3])) && isequaln(L2.vmom.u_uabs3([1 3]), L1.vmom.u_uabs3([1 3])) && ...
     isequaln(L2.Ub([1 3]), L1.Ub([1 3]));
ok = rep('G2 13.9% unconfirmed: hour 2 invalid, hours 1 and 3 unchanged', c2) && ok;

jj = 2*seg + 2000 + (1:10);
P3 = P1;  P3.qc.vel_beamstep_unconfirmed(jj) = true;
P3n = PUV;  P3n.BuoyCoord.U(jj) = NaN;  P3n.BuoyCoord.V(jj) = NaN;  P3n.BuoyCoord.W(jj) = NaN;
L3 = run(P3, instr);  L3n = run(P3n, instr);
g3 = @(A) A.vmom.u_uabs3(2) == L3n.vmom.u_uabs3(2) && A.vmom.u_uabs2(2) == L3n.vmom.u_uabs2(2) && ...
          A.vmom.u_uabs3(2) ~= L1.vmom.u_uabs3(2);
ok = rep(sprintf('G3 10 unconfirmed = 10 NaN (u_uabs3 %.6g vs %.6g), nUnconfirmed %d', ...
    L3.vmom.u_uabs3(2), L3n.vmom.u_uabs3(2), L3.velGap.nUnconfirmed), ...
    g3(L3) && L3.velGap.nUnconfirmed == 10) && ok;

I4 = instr;  I4.velInvalidFrom = PUV.time(2*seg + 1) + minutes(30);
L4 = run(P1, I4);
g4 = @(A) all(~A.segValid_vel(2:3)) && all(~A.segValid(2:3)) && A.segValid_vel(1) && ...
          isequaln(A.vmom.u_uabs3(1), L1.vmom.u_uabs3(1)) && isequaln(A.Hs(2:3), L1.Hs(2:3));
ok = rep(sprintf('G4 cutoff: hours 2-3 velocity invalid, pressure kept, nCutoff %d', L4.velGap.nCutoff), ...
    g4(L4) && L4.velGap.nCutoff == 1.5*seg) && ok;

% ---- breaks
P3b = P1;  P3b.qc.vel_beamstep_unconfirmd = P3.qc.vel_beamstep_unconfirmed;
ok = rep('B-G3 misspelled flag field: G3 fails', ~g3(run(P3b, instr))) && ok;
I4b = instr;  I4b.velInvalidFrm = I4.velInvalidFrom;
ok = rep('B-G4 misspelled cutoff field: G4 fails', ~g4(run(P1, I4b))) && ok;

fprintf('\n%s\n', repmat('-', 1, 50));
if ok, fprintf('ALL PASS\n'); else, error('test_L2_velgap:FAIL', 'assertion failed'); end
end

% ----------------------------------------------------------------------
function L = quiet_L2(P, I, opts)
    evalc('L = PUV_L2_spectral(P, I, opts);');
end

function L = strip(L)
    for f = {'velGap', 'prov', 'params'}
        if isfield(L, f{1}), L = rmfield(L, f{1}); end
    end
end

function [PUV, instr, opts] = synth()
    rng(20261113);
    fs = 2; N = 7200*4; rho = 1025; g = 9.81; h = 9.40; doffp = 1.00;
    t = (0:N-1)'/fs;
    f = (0.05:0.005:0.20)';  S = 0.30*exp(-((f-0.09)/0.025).^2);  a = sqrt(2*S*0.005);
    om = 2*pi*f;  k = get_wavenumber(om, h);
    u = zeros(N,1);  p_m = zeros(N,1);
    for j = 1:numel(f)
        ph = 2*pi*rand;
        u   = u   + a(j)*om(j)*cosh(k(j)*doffp)/sinh(k(j)*h)*cos(om(j)*t - ph);
        p_m = p_m + a(j)*cosh(k(j)*doffp)/cosh(k(j)*h)*cos(om(j)*t - ph);
    end
    u = u + 0.05;  v = 0.02*randn(N,1);  w = 0.01*randn(N,1);
    PUV = struct();
    PUV.time = datetime(2024,1,1,0,0,0) + seconds(t);
    PUV.fs = fs;  PUV.P = (h - doffp + p_m)*rho*g/1e4;  PUV.T = 17.2*ones(N,1);
    PUV.BuoyCoord.U = u;  PUV.BuoyCoord.V = v;  PUV.BuoyCoord.W = w;
    PUV.doffp = doffp;  PUV.label = 'SYNTH_10m';  PUV.deploymentName = 'SYNTH';
    PUV.LATLON = [32.93035 -117.26572];  PUV.rotation = struct('sensor', NaN, 'mag', NaN);
    PUV.InstrCoord = struct('U', u, 'V', v);
    PUV.qc.valid_vel = true(N,1);  PUV.qc.valid_p = true(N,1);  PUV.qc.valid_tilt = true(N,1);
    PUV.qc.valid_T = true(N,1);    PUV.qc.valid_joint = true(N,1);
    PUV.qc.vel_c_factor = ones(N,1,'single');  PUV.qc.vel_c_corrected = false(N,1);
    PUV.qc.vel_rotation_static = false(N,1);   PUV.qc.Tref = 17.2;  PUV.qc.opts = struct();
    instr = struct('mopStation', '');
    opts  = struct('doRotate', false, 'spectralMethod', 'welch', 'depthDeviationMax', 0);
end

function ok = rep(name, cond)
    ok = logical(cond);
    if ok, s = 'PASS'; else, s = 'FAIL'; end
    fprintf('  [%s] %s\n', s, name);
end
