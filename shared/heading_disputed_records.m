function [isDisputed, reason, TBL, SWITCHED] = heading_disputed_records(deployment, label)
% HEADING_DISPUTED_RECORDS  Records whose instrument heading is in dispute.
%
%   [tf, reason] = heading_disputed_records(deployment, label)
%   [~, ~, TBL]  = heading_disputed_records()          % the whole table
%   [~, ~, ~, SW] = heading_disputed_records()         % records switched off the list
%
% STATUS 2026-11-17: THE LIST IS EMPTY. All 12 records it held were switched
% to the logged heading in L1-L4 (HLB decision 2026-11-16; catalog version
% after 2026-11-17.1). The decision: prefer the diver log over the compass
% where an independent diagnostic agrees with the log. For all 12, the single
% constant rotation that best matches CDIP MOP Sxy has the sign of
% (log - compass), usually within 4 deg and at most 10.3 deg (CDF15C)
% (Paper_2/docs/RESULTS_eof_recovery_renumber_2026-11-12.md G30-G31;
% Paper_2/scripts/analysis/explore_sxy_rotation_2026_11_16.m). MOP is
% supporting evidence only. The configs carry each logged value exactly as
% recorded, never a MOP-fitted one. The 12 are returned in SWITCHED (same
% columns as TBL) so the history and the old compass medians stay readable.
% The text below describes the list as it stood from 2026-10-07 to 2026-11-16.
%
% WHY THIS EXISTS. Two independent sources give the heading of an XYZ record:
% the onboard compass (median over the record, the L1 default when the config
% heading is NaN) and the mount heading a diver logged in the field notes.
% Across the catalog they usually agree within about 5 deg (diver minus compass
% sd 4.8 deg over 9 records with both, 2026-10-07). Where they differ by more
% than 10 deg, about 2 sd, one of them is wrong by at least that much, and
% every directional quantity (meanDir, Sxy, the direction of uMean/vMean, the
% principal axis) inherits the doubt.
%
% The flag is defined WITHOUT reference to MOP or any other wave model, so it
% can be used to qualify a PUV-vs-MOP comparison without making it circular.
% It covers records NOT switched to the logged heading: a record switched by
% the drift rule (compass drifts or steps at constant tilt; see
% config/TorreyOffshore_config.m) carries the logged value and is not listed.
%
% (Until 2026-11-16:) This is applied at REPORTING time, not in L1-L4. The heading values in the
% configs are unchanged; each config line carries the logged value as a
% sourced comment. Evidence: outputs/validation/heading_audit_2026-10-07/.
%
% Denominator (2026-10-09): 62 catalog XYZ records; 9 switched to the logged
% heading; of the other 53, 45 have a usable logged value and 12 of those are
% listed here. Two records left the list on 2026-10-09:
%   LPL23/LPL_8m: NO USABLE LOG VALUE. DeploymentNotes2023-2024.xls 'All Data'
%     row 75 (S/N 15032) repeats Solana MOP651 5m row 64 (S/N 17045) in two
%     cells, "88cm sand to PUV pressure port on deployment." and "+X onshore,
%     96.7deg. magnetic."; its own rows 76/77 read 78 and 87 cm. Probably a
%     template copy, so 96.7 is not a measurement. Compass 82.0 kept.
%   TOR25S/MOP586_10m: NOT DISPUTED. Its only log value (2024-25 row 36,
%     "+X onshore, 286.6deg magnetic using new compass on 6/5/2025", taken at
%     recovery) contradicts the wave field, judged WITHOUT MOP: theta_PUV minus
%     the shore-normal is -6.4 deg on the compass (235.9; every hour within
%     +-90), +44.3 on 286.6, and -135.7 on its reciprocal 106.6. At 10 m depth
%     refraction keeps incidence small, so the compass stands.
% Borderline, NOT listed (|diff| = 9.7-10.0): SOL23/MOP654_7m,
% CAT21A/CAT_isl, LPL25B/LPL_8m. TBR23/MOP580_5m differs by 179.8 deg only
% because its compass is the documented 180 deg flip; the log agrees with the
% applied heading to 0.3 deg, so it is not listed.
%
% OUTPUTS
%   isDisputed  logical
%   reason      char, empty when not disputed
%   TBL         table: deployment, label, log heading, compass median, diff,
%               and the reason with its field-log source (empty since 2026-11-16)
%   SWITCHED    the same table for the 12 records switched to the log on
%               2026-11-16; compass_median is the median they carried before
%
% Author: Holden Leslie-Bole, 2026

% The 12 formerly disputed records (switched to the log 2026-11-16).
S = {
  'TOR17D', 'MOP591_9m', 66.7, 100.3, ...
  ['SoCal_instruments_2017-2018.xls ''All Data'' row 36, S/N V0806: ''""'' (inherits ' ...
   'row 33: "66.7 deg (mag)"). Steady tilt ~(5, 12-15) deg, so the drift rule does not apply.']
  'TOR14C', 'MOP591_9m', 101.5, 76.1, ...
  'SoCal_instruments_2014.xls ''All Data'' row 42, S/N V0806: "113.3 deg (101.5mag)".'
  'TOR17B', 'MOP591_9m', 66.7, 87.6, ...
  ['SoCal_instruments_2017-2018.xls ''All Data'' row 34, S/N V0806: ''""'' (inherits ' ...
   'row 33: "66.7 deg (mag)"). Steady tilt ~(8, 16-19) deg, so the drift rule does not apply.']
  'COR17D', 'MOP158_9m', 28.9, 49.0, ...
  'SoCal_instruments_2017-2018.xls ''All Data'' row 40, S/N V1181: ''""'' (inherits row 37: "28.9 deg (mag)").'
  'TOR15D', 'MOP591_9m', 43.0, 26.8, ...
  'SoCal_instruments_2015.xls ''All Data'' row 59, S/N V0824: "55 deg (43.0mag)".'
  'TOR15A', 'MOP591_9m', 63.6, 48.7, ...
  'SoCal_instruments_2015.xls ''All Data'' row 55, S/N V1181: "75 deg (63.6mag)".'
  'CDF15C', 'MOP677_9m', 62.2, 47.4, ...
  'SoCal_instruments_2015.xls ''All Data'' row 52, S/N V1053: "74 deg (62.2mag)".'
  'CDF15A', 'MOP677_9m', 62.2, 47.6, ...
  'SoCal_instruments_2015.xls ''All Data'' row 49, S/N V1049: "74 deg (62.2mag)".'
  'TOR24W', 'MOP586_10m', 59.5, 71.9, ...
  ['DeploymentNotes2024-2025.xls ''All Data'' row 34, S/N 16737: "+X onshore, ???deg. ' ...
   'magnetic. KVH Compass failed. 59.5deg previously measured." Inherited from the ' ...
   'previous deployment, not measured for this one.']
  'TOR25S', 'MOP586_15m', 34.2, 46.1, ...
  'DeploymentNotes2024-2025.xls ''All Data'' row 40, S/N 17047: "+X onshore, 34.2deg magnetic using new compass on 6/5/2025."'
  'TOR14B', 'MOP591_9m', 101.5, 89.9, ...
  'SoCal_instruments_2014.xls ''All Data'' row 41, S/N V0475: "113.3 deg (101.5mag)".'
  'SIO25E', 'SIO_6m',    88.0, 99.3, ...
  'DeploymentNotes2025-2026.xls ''All Data'' row 8, S/N 17047: "+X onshore, 88.0deg magnetic.  Measured with new KVH."'
};

% Records currently disputed (log and compass differ by > 10 deg and the
% record stays on the compass). Empty since 2026-11-16.
E = cell(0, 5);

TBL = mk_table(E);
SWITCHED = mk_table(S);

isDisputed = false;
reason = '';
if nargin < 2, return; end

for i = 1:size(E,1)
    if strcmp(deployment, E{i,1}) && strcmp(label, E{i,2})
        isDisputed = true;
        reason = sprintf('log %.1f vs compass %.1f deg (diff %+.1f). %s', ...
            E{i,3}, E{i,4}, TBL.log_minus_compass(i), E{i,5});
        return
    end
end
end

function T = mk_table(C)
if isempty(C)
    T = table(cell(0,1), cell(0,1), zeros(0,1), zeros(0,1), zeros(0,1), cell(0,1), ...
        'VariableNames', {'deployment','label','log_heading_mag','compass_median','log_minus_compass','reason'});
    return
end
dif = mod(cell2mat(C(:,3)) - cell2mat(C(:,4)) + 180, 360) - 180;
T = table(C(:,1), C(:,2), cell2mat(C(:,3)), cell2mat(C(:,4)), dif, C(:,5), ...
    'VariableNames', {'deployment','label','log_heading_mag','compass_median','log_minus_compass','reason'});
end
