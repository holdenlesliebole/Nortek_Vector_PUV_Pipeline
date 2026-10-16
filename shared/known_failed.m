function [tf, reason] = known_failed(instr)
% KNOWN_FAILED  True when a configured instrument is flagged as a field failure.
%
%   [tf, reason] = known_failed(instr)
%
% A config marks an instrument that never produced usable data with
%   cfg.instruments(k).knownFailed = '<cause>; <source>';
% The instrument stays configured (serial, position, dates remain on record),
% but the PUV_L*_driver / PUV_L*_run_all scripts skip it with a printed line
% instead of counting it as a failure, so a batch ends in error only on a NEW
% failure. validation/audit_registry_loads lists it as known, not missing.
%
% Author: Holden Leslie-Bole, 2026

    reason = '';
    if isstruct(instr) && isfield(instr, 'knownFailed') && ~isempty(instr.knownFailed)
        reason = char(string(instr.knownFailed));
    end
    tf = ~isempty(reason);
end
