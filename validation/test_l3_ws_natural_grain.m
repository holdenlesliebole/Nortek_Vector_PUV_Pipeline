% TEST_L3_WS_NATURAL_GRAIN  Regression test: the settling velocity PUV_L3_transport
% stores (and feeds to the Rouse number) is the natural-grain Ferguson & Church
% (2004) value, and the C2 it used is stamped in transport_params.ws_C2.
%
% Why: 63 of 66 catalog L3 files still carried the smooth-sphere C2 = 0.4 ws on
% 2026-10-07, seven weeks after settling_velocity's default became natural
% grains (C2 = 1.0), and nothing in L3 recorded which C2 had been used.
%
% A synthetic L2 (3 hourly segments, legacy bed-stress method so D50 comes from
% L2.params.D50) is pushed through the real PUV_L3_transport. The expected ws is
% written out here from the formula, NOT taken from settling_velocity:
%     ws = R g D^2 / (C1 nu + sqrt(0.75 C2 R g D^3)),  R = rho_s/rho - 1,
%     C1 = 18, C2 = 1.0, rho_s = 2650, rho = 1025, nu = 1e-6, g = 9.81.
% Hand value at D = 250 um: R = 1.585366, numerator 9.7203e-7, denominator
% 18e-6 + 1.3500e-5 = 3.1500e-5, ws = 0.030858 m/s.
%
% Criteria fixed before running: ws within 1e-12 relative of the formula at
% every D tested; ws_C2 == 1.0; hand value 0.030858 within 1e-4 relative; the
% Rouse number scales with ws (rouse / ws identical across D at fixed stress).
%
% Run from PUV_Pipeline/:  >> run validation/test_l3_ws_natural_grain

% Only add paths if needed, so a deliberately broken copy placed ahead of the
% repo on the path is the one under test (see test_enu_declination_closure.m).
if ~exist('PUV_L3_transport', 'file'), startup_puv; end
fprintf('settling_velocity under test: %s\n', which('settling_velocity'));
fprintf('PUV_L3_transport under test : %s\n', which('PUV_L3_transport'));

rho_s = 2650; rho = 1025; nu = 1e-6; g = 9.81; C1 = 18; C2 = 1.0;
wsFormula = @(D) ((rho_s/rho - 1) * g * D.^2) ./ ...
                 (C1 * nu + sqrt(0.75 * C2 * (rho_s/rho - 1) * g * D.^3));

Ds = [138.6 217.4 250 500] * 1e-6;     % m; spans the catalog's measured D50
nSeg = 3;
f = (0.005:0.005:0.5)';
S = exp(-((f - 0.08).^2) / (2 * 0.015^2)) * 0.5;   % m^2/Hz, peaked swell

pass = 0; total = 0; ratio = NaN(size(Ds));
for k = 1:numel(Ds)
    L2 = struct();
    L2.time     = datetime(2025,1,1) + hours(0:nSeg-1)';
    L2.segValid = true(nSeg,1);
    L2.depth    = 7 * ones(nSeg,1);
    L2.f        = f;
    L2.S_eta    = repmat(S, 1, nSeg);
    L2.tau_b    = [0.3; 0.5; 0.8];      % Pa
    L2.Ub       = [0.3; 0.4; 0.5];
    L2.uMean    = [0.05; 0.05; 0.05];
    L2.vMean    = [0.10; 0.10; 0.10];
    L2.label    = 'SYNTHETIC';
    L2.params   = struct('D50', Ds(k), 'bedstress_method', 'bed_stress_legacy');

    L3 = PUV_L3_transport(struct(), L2);
    tp = L3.transport_params;

    rel = abs(tp.ws - wsFormula(Ds(k))) / wsFormula(Ds(k));
    total = total + 1; ok = rel < 1e-12; pass = pass + ok;
    fprintf('  D50 %5.1f um: ws %.6f m/s vs formula %.6f, rel %.1e  %s\n', ...
        Ds(k)*1e6, tp.ws, wsFormula(Ds(k)), rel, string(ok));

    total = total + 1; ok = isfield(tp,'ws_C2') && tp.ws_C2 == 1.0; pass = pass + ok;
    if isfield(tp,'ws_C2'), c2s = sprintf('%g', tp.ws_C2); else, c2s = 'missing'; end
    fprintf('             ws_C2 = %s (expect 1)  %s\n', c2s, string(ok));

    ratio(k) = L3.rouse(2) / tp.ws;    % same tau_m in every case
end

total = total + 1;
ok = abs(wsFormula(250e-6) - 0.030858) / 0.030858 < 1e-4; pass = pass + ok;
fprintf('  hand value at 250 um: formula %.6f vs 0.030858  %s\n', wsFormula(250e-6), string(ok));

total = total + 1;
ok = max(abs(ratio - ratio(1))) / abs(ratio(1)) < 1e-12; pass = pass + ok;
fprintf('  rouse/ws constant across D at fixed stress: spread %.1e  %s\n', ...
    max(abs(ratio - ratio(1))) / abs(ratio(1)), string(ok));

fprintf('\n=== L3 ws natural grain: %d/%d checks pass\n', pass, total);
if pass ~= total
    error('test_l3_ws_natural_grain:failed', 'L3 ws regression test FAILED (%d/%d)', pass, total);
end
fprintf('  PASS\n');
