% TEST_L3_CURRENTS_DETERMINISM  PUV_L3_currents must not depend on the RNG state.
%
% WHY. t_tide's default confidence intervals ('error','cboot') are Monte Carlo,
% and its prediction keeps only constituents whose SNR clears a threshold, so
% before 2026-10-09 the tidal and subtidal currents changed with the caller's
% RNG state: two runs of SOL23/MOP654_7m differed by 0.0027 m/s rms against a
% tidal rms of 0.0124 m/s (TBR23/MOP586_5m: 0.0065 against 0.0030). Every L3
% rebuild re-rolled them. PUV_L3_currents now seeds each t_tide call
% (rng(0,'twister')) and restores the caller's state.
%
% WHAT. Run the real routine twice on a real record (read-only), once after
% rng(1) and once after rng(99). PASS requires
%   (a) tidal.u, tidal.v, subtidal.u, subtidal.v, tidal.depth_pred identical
%       (isequaln), and
%   (b) the caller's RNG state unchanged by each call.
% tidal.depth_pred comes from NOAA when the download succeeds, else from
% t_tide; the source of each run is printed, since a network failure in only
% one run would make (a) differ for that reason alone.
%
% Watched to fail against the unseeded routine (the commit before this one,
% prepended to the path): see that commit's message.
%
% Run from PUV_Pipeline/:   >> run validation/test_l3_currents_determinism
% Author: Holden Leslie-Bole, 2026

if ~exist('deployment_registry', 'file'), startup_puv; end
fprintf('\nPUV_L3_currents: %s\n', which('PUV_L3_currents'));
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
if ~isfolder(fullfile(root, 'L3'))      % running from a worktree without outputs/
    root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';
end
dep = 'SOL23'; lab = 'MOP654_7m';
a = load(fullfile(root, 'L2', dep, [lab '_L2.mat']), 'L2'); L2 = a.L2;
b = load(fullfile(root, 'L3', dep, [lab '_L3.mat']), 'L3'); L3in = b.L3; clear a b

seeds = [1 99]; out = cell(1,2); stateOK = false(1,2);
for k = 1:2
    rng(seeds(k)); before = rng;
    [~, out{k}] = evalc('PUV_L3_currents(L3in, L2)');
    after = rng;
    stateOK(k) = isequal(before.State, after.State) && strcmp(before.Type, after.Type);
    fprintf('  run after rng(%d): depth source %s, caller RNG state unchanged: %d\n', ...
        seeds(k), out{k}.tidal.depth_source, stateOK(k));
end

flds = {'tidal.u','tidal.v','subtidal.u','subtidal.v','tidal.depth_pred'};
nPass = 0;
for f = 1:numel(flds)
    x1 = eval(['out{1}.' flds{f}]); x2 = eval(['out{2}.' flds{f}]);
    same = isequaln(x1, x2);
    nPass = nPass + same;
    fprintf('  %-18s identical: %d   max |diff| %.3g\n', flds{f}, same, max(abs(x1(:) - x2(:)), [], 'omitnan'));
end
nPass = nPass + sum(stateOK);
nTot = numel(flds) + numel(stateOK);
fprintf('\n%d/%d checks pass\n', nPass, nTot);
if nPass < nTot
    error('test_l3_currents_determinism:fail', '%d/%d checks failed', nTot - nPass, nTot);
end
