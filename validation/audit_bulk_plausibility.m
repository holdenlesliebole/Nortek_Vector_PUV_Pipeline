% AUDIT_BULK_PLAUSIBILITY  Flag records whose bulk wave height is implausible
% against the reference model.
%
%   audit_bulk_plausibility
%
% THE GAP THIS CLOSES. RUBY22/MOP582_30m reports Hs < 0.06 m for 2,668 of its
% 2,688 hours while the reference model gives up to 2.5 m. The instrument is
% flat-lined and the automated quality control passed it, because every existing
% L2 check is INTERNAL -- it asks whether the record is self-consistent, never
% whether it is consistent with what the ocean was doing. A dead sensor produces
% a perfectly self-consistent record of nothing.
%
% This is deliberately an AUDIT rather than an L2 gate. Making L2 depend on
% THREDDS would couple processing to network availability and to a model that is
% itself under test in this project -- the wrong dependency for a pipeline whose
% output is used to evaluate that model. Run this after a sweep instead, and
% treat a flag as "inspect this record", not "discard it".
%
% THREE DETECTORS, deliberately crude, because the failure they catch is gross:
%   1. LEVEL      median observed / median model, per record. A dead sensor
%                 drives this toward 0; a mis-scaled one away from 1 either way.
%   2. DEADNESS   fraction of hours with observed Hs below an absolute floor
%                 while the model says it should be well above it.
%   3. RESPONSE   R^2 against the model. Near zero means the record does not
%                 track the ocean at all, whatever its level.
%
% A record failing any one is worth a look; failing all three is a dead sensor.
%
% Input: outputs/validation/cross_deployment_bulk.mat (run_bulk_validation_sweep)
% Author: Holden Leslie-Bole, 2026

startup_puv
root = fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation');
S = load(fullfile(root,'cross_deployment_bulk.mat'));
R = S.ROWS; Q = S.POOL;

LEVEL_LO = 0.60;    % median ratio below this -> suspicious
LEVEL_HI = 1.60;
FLOOR_M  = 0.10;    % "observed is essentially nothing"
MODEL_M  = 0.30;    % "...while the model says there were waves"
DEAD_FRC = 0.25;    % fraction of hours failing that pair
R2_MIN   = 0.30;

fprintf('\n%-9s %-13s %8s %8s %8s   %s\n', ...
    'deploy','label','lvl','dead','R2','flags');
nFlag = 0; rows = {};
for i = 1:numel(R)
    m = Q.rec == i & isfinite(Q.Hs_puv) & isfinite(Q.Hs_mop);
    if sum(m) < 20, continue; end
    lvl  = median(Q.Hs_puv(m)) / max(median(Q.Hs_mop(m)), eps);
    dead = mean(Q.Hs_puv(m) < FLOOR_M & Q.Hs_mop(m) > MODEL_M);
    r2   = R(i).Hs_R2;

    f = {};
    if lvl < LEVEL_LO || lvl > LEVEL_HI, f{end+1} = 'LEVEL';  end %#ok<AGROW>
    if dead > DEAD_FRC,                  f{end+1} = 'DEAD';   end %#ok<AGROW>
    if isfinite(r2) && r2 < R2_MIN,      f{end+1} = 'NO-RESP';end %#ok<AGROW>
    if isempty(f), continue; end
    nFlag = nFlag + 1;
    fprintf('%-9s %-13s %8.3f %8.3f %8.3f   %s\n', ...
        R(i).deployment, R(i).label, lvl, dead, r2, strjoin(f,','));
    rows(end+1,:) = {R(i).deployment, R(i).label, lvl, dead, r2, strjoin(f,',')}; %#ok<AGROW>
end

fprintf('\n%d of %d records flagged.\n', nFlag, numel(R));
fprintf('Thresholds: level outside [%.2f %.2f]; >%.0f%% of hours with observed\n', ...
    LEVEL_LO, LEVEL_HI, 100*DEAD_FRC);
fprintf('Hs < %.2f m while model > %.2f m; or Hs R^2 < %.2f.\n', FLOOR_M, MODEL_M, R2_MIN);
fprintf('\nA flag means INSPECT, not discard. Genuine sheltering (Catalina), a\n');
fprintf('deep station under a small sea, or a short deployment can all trip a\n');
fprintf('detector without the record being bad.\n');

save(fullfile(root,'bulk_plausibility_audit.mat'),'rows', ...
     'LEVEL_LO','LEVEL_HI','FLOOR_M','MODEL_M','DEAD_FRC','R2_MIN');
fprintf('\nSaved: %s\n', fullfile(root,'bulk_plausibility_audit.mat'));
