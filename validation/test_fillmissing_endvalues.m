% TEST_FILLMISSING_ENDVALUES  Edge gaps must not inflate any L2-L4 product.
%
% WHY. fillmissing(x,'linear') defaults to EndValues='extrap': a NaN run that
% touches a segment edge is filled by a straight line through the last two
% valid samples. Those samples carry swell, so the fill is a ramp, and detrend
% plus an IG bandpass turn that ramp into IG variance. IB19S/MOP045_7m segment
% 1255 (425 NaN at the end) came out with L4 Hs_IG 3.88 m against 0.76 m in L2;
% across the catalog, 2,371 segments with gaps differed from L2 by > 50%.
% Every fill site now uses 'EndValues','nearest'.
%
% WHAT. A synthetic record of linear waves (known IG + swell; pressure, u, v,
% w at the sensor) is pushed through each REAL routine twice: clean, and with
% an edge gap (400 samples, 5.6% of a 7200-sample segment, under nanMaxFrac
% 0.1) in ONLY the channel that site fills. Metric per site: gap / clean.
% PASS when the 90th percentile of |gap/clean - 1| over 10 random-phase
% realizations is <= 0.10. The tolerance was fixed before the first run.
% The two reflection sites first used out_gap/out_clean; the synthetic waves
% are purely progressive, so out_clean is ~0 and that ratio is meaningless.
% They now score the ADDED reflected variance as a fraction of the incident
% variance, against the same 0.10. Changed after the first run, said so here.
% Site 9 is not a fill-only fix: PUV_L3_currents now fits t_tide only over the
% span where velocity exists, because 'nearest' over a 10-day dead tail still
% biased the tidal current by ~14% in this test.
%
%   site  routine (line)                       channel  metric
%   1     PUV_L2_spectral main branch (466-469) p,u,v,w  Hs_IG and u_rms, seg 3
%   2     PUV_L2_spectral vel-only (375)        u,v,w    u_rms, seg 4 (p all NaN)
%   3     PUV_L2_spectral p-only (407)          p        Hs_IG, seg 2 (vel all NaN)
%   4     PUV_L4_eta (104)                      p        var(eta_ig), seg 3
%   5     PUV_L4_boundwave (177)                u,v      var_u_ig_total, seg 3
%   6     PUV_L4_reflection (260-261)           u,v      1 + (added var_IG_out)/var_IG_in, seg 3
%   7     PUV_L4_reflection_free (111-112)      u,v      1 + (added var eta_IG_out)/var eta_IG_in, seg 3
%   8     PUV_L4_velocity_pdf (78)              u,v      mean_absU, seg 3 only
%   9     PUV_L3_currents (87-89 + fit span)    uMean    rms tidal.u, velocity-dead tail
%
% Watched to fail: run against the pre-fix routines (the same files from the
% commit before this change, prepended to the path) and sites 1-9 are expected
% to FAIL where the old fill extrapolated. See the commit message for the run.
%
% Run from PUV_Pipeline/:   >> run validation/test_fillmissing_endvalues
% Author: Holden Leslie-Bole, 2026

if ~exist('get_wavenumber', 'file'), startup_puv; end
fprintf('\nroutines under test:\n');
fns = {'PUV_L2_spectral','PUV_L4_eta','PUV_L4_boundwave','PUV_L4_reflection', ...
       'PUV_L4_reflection_free','PUV_L4_velocity_pdf','PUV_L3_currents'};
for k = 1:numel(fns), fprintf('  %-24s %s\n', fns{k}, which(fns{k})); end

tol = 0.10; nReal = 10; gapLen = 400;
fs = 2; N = 7200; nHr = 6; H = 7; doffp = 0.7; rho = 1025; g = 9.81;
comps = [0.15 0.010; 0.35 0.070; 0.25 0.090; 0.15 0.120];   % eta [amp m, freq Hz]
names = {'L2 main Hs_IG','L2 main u_rms','L2 vel-only u_rms','L2 p-only Hs_IG', ...
         'L4 eta var_ig','L4 boundwave var_u_ig','L4 reflection var_IG_out', ...
         'L4 reflection_free var_out','L4 velocity_pdf mean_absU','L3 currents tidal.u'};
R = NaN(nReal, numel(names));
instr = struct('shorenormal', 270, 'label', '', 'serialNum', 0);
o2 = struct('segLen', N, 'nanMaxFrac', 0.1);

for r = 1:nReal
    rng(100 + r);
    P0 = synth_puv(comps, fs, N*nHr, H, doffp, rho, g);
    L2 = quiet(@() PUV_L2_spectral(P0, instr, o2));          % clean; also fixes the segment grid
    so = L2.params.startOffset_samples;
    assert(numel(L2.time) >= 4, 'synthetic record yielded only %d L2 segments', numel(L2.time));
    segIx   = @(k) so + ((k-1)*N + 1 : k*N);
    lastEnd = @(k) so + ((k*N - gapLen + 1) : k*N);
    sP = 2; sM = 3; sV = 4;                                  % p-only, main, vel-only segments
    % ----- L2 sites 1-3 -----
    Pc = P0; Pc.P(segIx(sV)) = NaN;                          % pressure dead -> vel-only branch
    Pc.BuoyCoord.U(segIx(sP)) = NaN; Pc.BuoyCoord.V(segIx(sP)) = NaN; Pc.BuoyCoord.W(segIx(sP)) = NaN;  % velocity dead -> p-only
    Pg = Pc;
    g2 = lastEnd(sM); g3 = lastEnd(sV); g1 = lastEnd(sP);
    Pg.P(g2) = NaN; Pg.BuoyCoord.U(g2) = NaN; Pg.BuoyCoord.V(g2) = NaN; Pg.BuoyCoord.W(g2) = NaN;
    Pg.BuoyCoord.U(g3) = NaN; Pg.BuoyCoord.V(g3) = NaN; Pg.BuoyCoord.W(g3) = NaN;
    Pg.P(g1) = NaN;
    L2c = quiet(@() PUV_L2_spectral(Pc, instr, o2));
    L2g = quiet(@() PUV_L2_spectral(Pg, instr, o2));
    R(r,1) = L2g.Hs_IG(sM) / L2c.Hs_IG(sM);
    R(r,2) = L2g.reynolds.u_rms(sM) / L2c.reynolds.u_rms(sM);
    R(r,3) = L2g.reynolds.u_rms(sV) / L2c.reynolds.u_rms(sV);
    R(r,4) = L2g.Hs_IG(sP) / L2c.Hs_IG(sP);
    % ----- L4 sites 4-8: clean L2 from the fully clean record -----
    E0 = PUV_L4_eta(P0, L2);
    Pp = P0; Pp.P(g2) = NaN;                                 % pressure gap only
    Ep = PUV_L4_eta(Pp, L2);
    R(r,5) = var(Ep.eta_ig(:,sM)) / var(E0.eta_ig(:,sM));
    Pu = P0; Pu.BuoyCoord.U(g2) = NaN; Pu.BuoyCoord.V(g2) = NaN;   % velocity gap only
    B0 = quiet(@() PUV_L4_boundwave(E0, L2, P0));
    Bu = quiet(@() PUV_L4_boundwave(E0, L2, Pu));
    R(r,6) = Bu.var_u_ig_total(sM) / B0.var_u_ig_total(sM);
    F0 = quiet(@() PUV_L4_reflection(P0, L2, E0));
    Fu = quiet(@() PUV_L4_reflection(Pu, L2, E0));
    R(r,7) = 1 + (Fu.var_IG_out(sM) - F0.var_IG_out(sM)) / F0.var_IG_in(sM);   % added reflected var / incident var
    G0 = quiet(@() PUV_L4_reflection_free(P0, L2, E0, B0));
    Gu = quiet(@() PUV_L4_reflection_free(Pu, L2, E0, B0));
    R(r,8) = 1 + (var(Gu.eta_IG_out(:,sM)) - var(G0.eta_IG_out(:,sM))) / var(G0.eta_IG_in(:,sM));
    L2one = L2; L2one.segValid = false(size(L2.segValid)); L2one.segValid(sM) = true;
    V0 = quiet(@() PUV_L4_velocity_pdf(P0, L2one));
    Vu = quiet(@() PUV_L4_velocity_pdf(Pu, L2one));
    R(r,9) = Vu.mean_absU / V0.mean_absU;
    % ----- L3 site 9: hourly means with a velocity-dead tail -----
    R(r,10) = l3_tail_ratio(r);
end

fprintf('\n%-30s %8s %8s %8s   %s\n', 'site', 'median', 'p90|r-1|', 'max|r-1|', 'result');
nPass = 0;
for k = 1:numel(names)
    x = R(:,k); dev = abs(x - 1);
    ok = prctile(dev, 90) <= tol;
    nPass = nPass + ok;
    fprintf('%-30s %8.3f %8.3f %8.3f   %s\n', names{k}, median(x), prctile(dev,90), max(dev), tern(ok,'PASS','FAIL'));
end
fprintf('\n%d/%d sites PASS (p90 |gap/clean - 1| <= %.2f over %d realizations)\n', nPass, numel(names), tol, nReal);
if nPass < numel(names)
    error('test_fillmissing_endvalues:fail', '%d/%d sites failed', numel(names)-nPass, numel(names));
end

% =========================================================================
function PUV = synth_puv(comps, fs, n, H, doffp, rho, g)
% Linear progressive waves travelling onshore, sampled at the sensor.
t  = (0:n-1)'/fs;
ph = 2*pi*rand(size(comps,1),1);
eta_p = zeros(n,1); u = zeros(n,1);
for c = 1:size(comps,1)
    a = comps(c,1); w = 2*pi*comps(c,2); k = get_wavenumber(w, H);
    Kp = cosh(k*doffp)/cosh(k*H);
    eta_p = eta_p + a*Kp*cos(w*t + ph(c));
    u     = u + a*w*cosh(k*doffp)/sinh(k*H)*cos(w*t + ph(c));
end
PUV.time = datetime(2024,1,1,0,0,0) + seconds(t);
PUV.fs = fs;
PUV.P  = (H - doffp + eta_p) * rho * g / 1e4;               % dBar
PUV.BuoyCoord.U = -u;                                       % +x West; waves travel east
PUV.BuoyCoord.V = 0.2*u;
PUV.BuoyCoord.W = 0.05*u;
PUV.T = 15*ones(n,1);
PUV.LATLON = [32.93 -117.27];
PUV.doffp = doffp;
PUV.label = '';
PUV.deploymentName = 'SYNTH';
end

function r = l3_tail_ratio(seed)
% 40 days of hourly means; the last 10 days have pressure but no velocity,
% so uMean is NaN at the END of the t_tide grid. Compare the tidal fit with
% the record truncated before the dead tail.
rng(500 + seed);
t = (datetime(2024,1,1):hours(1):datetime(2024,2,10))'; n = numel(t);
th = hours(t - t(1));
u = 0.20*cos(2*pi*th/12.42 + 2*pi*rand) + 0.06*cos(2*pi*th/23.93 + 2*pi*rand) + 0.02*randn(n,1);
v = 0.05*cos(2*pi*th/12.42 + 2*pi*rand) + 0.02*randn(n,1);
d = 7 + 0.8*cos(2*pi*th/12.42 + 2*pi*rand);
dead = th >= 30*24;
L2g = struct('time', t, 'uMean', u, 'vMean', v, 'depth', d); L2g.uMean(dead) = NaN; L2g.vMean(dead) = NaN;
L3g = struct('time', t, 'segValid', true(n,1));
keep = ~dead;
L2c = struct('time', t(keep), 'uMean', u(keep), 'vMean', v(keep), 'depth', d(keep));
L3c = struct('time', t(keep), 'segValid', true(sum(keep),1));
% (synthetic L2 with no LATLON: name the station; the depth fallback is
% allowed because only the tidal CURRENT fit is compared here)
o3 = struct('tideStation', '9410230', 'allowTtideFallback', true);
Og = quiet(@() PUV_L3_currents(L3g, L2g, o3));
Oc = quiet(@() PUV_L3_currents(L3c, L2c, o3));
a = Og.tidal.u(keep); b = Oc.tidal.u;
r = rms(a) / rms(b);                % tidal-current amplitude, dead tail vs truncated
end

function out = quiet(f)
% Run f() without its console chatter.
[~, out] = evalc('f()');
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
