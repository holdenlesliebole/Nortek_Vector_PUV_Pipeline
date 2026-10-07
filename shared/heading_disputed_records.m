function [isDisputed, reason, TBL] = heading_disputed_records(deployment, label)
% HEADING_DISPUTED_RECORDS  Records whose instrument heading is in dispute.
%
%   [tf, reason] = heading_disputed_records(deployment, label)
%   [~, ~, TBL]  = heading_disputed_records()          % the whole table
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
% This is applied at REPORTING time, not in L1-L4. The heading values in the
% configs are unchanged; each config line carries the logged value as a
% sourced comment. Evidence: outputs/validation/heading_audit_2026-10-07/.
%
% Denominator (2026-10-07): 62 catalog XYZ records; 9 switched to the logged
% heading; of the other 53, 46 have a usable logged value and 14 of those are
% listed here. Borderline, NOT listed (|diff| = 9.7-10.0): SOL23/MOP654_7m,
% CAT21A/CAT_isl, LPL25B/LPL_8m. TBR23/MOP580_5m differs by 179.8 deg only
% because its compass is the documented 180 deg flip; the log agrees with the
% applied heading to 0.3 deg, so it is not listed.
%
% OUTPUTS
%   isDisputed  logical
%   reason      char, empty when not disputed
%   TBL         table: deployment, label, log heading, compass median, diff,
%               and the reason with its field-log source
%
% Author: Holden Leslie-Bole, 2026

E = {
  'TOR25S', 'MOP586_10m', 286.6, 235.9, ...
  ['DeploymentNotes2024-2025.xls ''All Data'' row 36, S/N 16737: "+X onshore, 286.6deg ' ...
   'magnetic using new compass on 6/5/2025." Neither value points +x onshore at face ' ...
   'value (onshore is ~73 deg magnetic at MOP586: shore-normal 84.5 true minus 11.1 declination).']
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
  'LPL23',  'LPL_8m',    96.7, 82.0, ...
  ['DeploymentNotes2023-2024.xls ''All Data'' row 75, S/N 15032: "+X onshore, 96.7deg. ' ...
   'magnetic." The same 96.7 appears for Solana MOP651 5m (row 64); a copy error is possible.']
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

dif = mod(cell2mat(E(:,3)) - cell2mat(E(:,4)) + 180, 360) - 180;
TBL = table(E(:,1), E(:,2), cell2mat(E(:,3)), cell2mat(E(:,4)), dif, E(:,5), ...
    'VariableNames', {'deployment','label','log_heading_mag','compass_median','log_minus_compass','reason'});

isDisputed = false;
reason = '';
if nargin < 2, return; end

for i = 1:size(E,1)
    if strcmp(deployment, E{i,1}) && strcmp(label, E{i,2})
        isDisputed = true;
        reason = sprintf('log %.1f vs compass %.1f deg (diff %+.1f). %s', ...
            E{i,3}, E{i,4}, dif(i), E{i,5});
        return
    end
end
end
