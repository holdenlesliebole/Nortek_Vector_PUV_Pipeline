% TEST_L3_DRIVER_TVALID  The supported L3 drivers must pass the config's Tvalid
% to PUV_L3_transport.
%
% WHY. PUV_L3_transport takes the per-segment viscosity from L2.Tmean, and a
% segment whose Tmean lies outside opts.Tvalid takes the record median instead.
% Called with two arguments it falls back to [-2 40]. Until 2026-10-14
% PUV_L3_driver.m and PUV_L3_run_all.m did exactly that, so a failed thermistor
% reading 30 C at a [9 26] site set that segment's viscosity, settling velocity
% and critical Shields number. The catalog itself was built by
% scripts/rerun_heading_ws_2026_10_07.m, which passed l1_qc_opts(cfg).Tvalid;
% only outputs made with the drivers were affected.
%
% Checks (criteria fixed before the first run):
%   A  every PUV_L3_transport call in each driver file has a third argument
%   B  that argument, evaluated from the driver's own assignment line with the
%      TBR23 config, carries Tvalid = l1_qc_opts(cfg).Tvalid = [9 26]
%   C  run on a synthetic L2 with Tmean [12 12 30 12], the driver's opts give
%      T_used(3) = 12 (record median) and nu(3) = nu(12); the two-argument
%      default gives T_used(3) = 30. C confirms the argument changes the output.
%
% To watch it fail on the old drivers: put copies of the pre-fix files in a
% folder and set driverFiles = {'<dir>/PUV_L3_driver.m', '<dir>/PUV_L3_run_all.m'}
% before running.
%
% Run from PUV_Pipeline/:  >> run validation/test_L3_driver_tvalid

if ~exist('PUV_L3_transport', 'file'), startup_puv; end
if ~exist('driverFiles', 'var') || isempty(driverFiles)
    driverFiles = {which('PUV_L3_driver'), which('PUV_L3_run_all')};
end
reg = deployment_registry(); fnCfg = reg('TBR23'); cfg = fnCfg();
wantT = l1_qc_opts(cfg).Tvalid;
mkL2 = @(Tmean) struct('time', datetime(2025,1,1) + hours(0:numel(Tmean)-1)', 'segValid', true(numel(Tmean),1), ...
    'depth', 7*ones(numel(Tmean),1), 'f', (0.005:0.005:0.5)', ...
    'S_eta', repmat(exp(-(((0.005:0.005:0.5)' - 0.08).^2)/(2*0.015^2))*0.5, 1, numel(Tmean)), ...
    'tau_b', 0.5*ones(numel(Tmean),1), 'Ub', 0.4*ones(numel(Tmean),1), ...
    'uMean', 0.05*ones(numel(Tmean),1), 'vMean', 0.10*ones(numel(Tmean),1), 'Tmean', Tmean(:), ...
    'label', 'MOP586_7m', 'params', struct('D50', 250e-6, 'bedstress_method', 'bed_stress_legacy'));
L2syn = mkL2([12 12 30 12]);

pass = 0; total = 0;
for i = 1:numel(driverFiles)
    src = fileread(driverFiles{i});
    [~, nm] = fileparts(driverFiles{i});
    calls = regexp(src, 'PUV_L3_transport\(([^;\n]*)\)\s*;', 'tokens');
    calls = calls(~cellfun(@isempty, calls));
    % A
    nArgs = cellfun(@(c) numel(strsplit(c{1}, ',')), calls);
    total = total + 1; okA = ~isempty(calls) && all(nArgs == 3); pass = pass + okA;
    fprintf('  A %-16s %d PUV_L3_transport call(s), args %s                 %d\n', nm, numel(calls), mat2str(nArgs), okA);
    % B and C, on the first call's third argument
    okB = false; okC = false;
    if okA
        argName = strtrim(subsref(strsplit(calls{1}{1}, ','), substruct('{}', {3})));
        line = regexp(src, ['(?m)^\s*' argName '\s*=\s*([^;\n]*);'], 'tokens', 'once');
        if ~isempty(line)
            o = eval(line{1});
            okB = isstruct(o) && isfield(o, 'Tvalid') && isequal(o.Tvalid, wantT);
            Lc = PUV_L3_transport(struct(), L2syn, o);
            Ld = PUV_L3_transport(struct(), L2syn);
            okC = Lc.T_used(3) == 12 && abs(Lc.nu(3) - seawater_nu(12)) <= 1e-15 && Ld.T_used(3) == 30;
            fprintf('  B %-16s %s = %s -> Tvalid %s (want %s)            %d\n', nm, argName, strtrim(line{1}), mat2str(o.Tvalid), mat2str(wantT), okB);
            fprintf('  C %-16s T_used(3): driver opts %g C, default %g C          %d\n', nm, Lc.T_used(3), Ld.T_used(3), okC);
        else
            fprintf('  B %-16s no assignment found for "%s"                      0\n', nm, argName);
        end
    else
        fprintf('  B %-16s not evaluated (A failed)                                 0\n', nm);
        fprintf('  C %-16s not evaluated (A failed)                                 0\n', nm);
    end
    total = total + 2; pass = pass + okB + okC;
end
fprintf('\n=== L3 driver Tvalid: %d/%d checks as required\n', pass, total);
if pass ~= total, error('test_L3_driver_tvalid:failed', 'L3 driver Tvalid FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');
