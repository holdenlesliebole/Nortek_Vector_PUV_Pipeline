function summary = run_phase2_all_hourly(opts)
% RUN_PHASE2_ALL_HOURLY  Run Phase 2 tests against the 1-hour L2 outputs
% (outputs/L2_hourly/) and save a parallel summary file.
%
%   summary = run_phase2_all_hourly()
%
% Outputs go to outputs/validation/mean_flow_hourly/<dep>/, leaving the
% 17-min Phase 2 figures intact.
%   Aggregate summary: outputs/validation/mean_flow_hourly/_aggregate/phase2_summary.mat
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
opts.L2dir   = fullfile(pipelineRoot,'outputs','L2_hourly');
opts.figRoot = fullfile(pipelineRoot,'outputs','validation','mean_flow_hourly');
opts.summaryName = 'phase2_summary.mat';

summary = run_phase2_all_deployments(opts);
end
