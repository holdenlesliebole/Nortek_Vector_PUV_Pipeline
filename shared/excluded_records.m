function [isExcluded, reason, TBL] = excluded_records(deployment, label)
% EXCLUDED_RECORDS  Catalog records excluded from reported statistics.
%
%   [tf, reason] = excluded_records(deployment, label)
%   [~, ~, TBL]  = excluded_records()          % the whole table
%
% WHY THIS EXISTS. Two records in the 62-record catalog are not trustworthy as
% measurements of the ocean, and both were being handled ad hoc -- one by a
% hardcoded filter at each analysis site, the other not at all. Centralizing
% them means a record cannot be silently dropped in one analysis and kept in
% another, which is how the 65/62/61 count confusion started.
%
% This is applied at REPORTING time, not in L2. Making L2 depend on an external
% reference would couple processing to network availability and to the very
% model under test. The detector that found them is
% validation/audit_bulk_plausibility.m, which runs on cross_deployment_bulk.mat
% and flagged exactly these 2 of 62 with no false positives among the other 60.
%
% Excluding a record changes reported counts. State which count you mean:
%   65  instrument-records in the server manifest
%   62  produce matched-shape / consequences metrics
%   60  62 minus BOTH records below -- use this for reported statistics
%
% OUTPUTS
%   isExcluded  logical
%   reason      char, empty when not excluded
%   TBL         table of every exclusion with its reason and provenance
%
% Author: Holden Leslie-Bole, 2026

E = {
  'RUBY22', 'MOP582_30m', ...
  ['dead pressure transducer: Hs < 0.06 m across 2,668 "valid" segments. ' ...
   'Trips all three bulk-plausibility detectors (level 0.009, dead 0.993, ' ...
   'R^2 0.000) and returns Sxy_b0 = 666 against a catalog range of ' ...
   '-1.388 to 1.157. Deployed deeper than its rated range. ' ...
   'Excluded everywhere since 2026-07-26.']
  'RUBY22', 'MOP579_6m', ...
  ['not responsive to the ocean: reads 44% high (level 1.445) with ' ...
   'R^2 = 0.219 against the reference. Trips the NO-RESP detector only -- ' ...
   'not dead, but not tracking. Independently flagged in ' ...
   'findings_consequences_2026-07-25.md section 10 as separately unreliable ' ...
   '(n = 165 in the Sxy battery), so two unrelated routes converge on it. ' ...
   'Excluded 2026-07-29 by decision; it was still in the analysis before that.']
};

TBL = table(E(:,1), E(:,2), E(:,3), 'VariableNames', {'deployment','label','reason'});

isExcluded = false;
reason = '';
if nargin < 2, return; end

for i = 1:size(E,1)
    if strcmp(deployment, E{i,1}) && strcmp(label, E{i,2})
        isExcluded = true;
        reason = E{i,3};
        return
    end
end
end
