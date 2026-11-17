function [velGap, info] = l1_velocity_gap_mask(PUV, instr)
%L1_VELOCITY_GAP_MASK  Samples of an L1 record whose velocity is treated as a gap.
%
%   [velGap, info] = l1_velocity_gap_mask(PUV, instr)
%
%   The same rule PUV_L2_spectral applies (HLB, 2026-11-13; see
%   docs/SPEC_L1_beam_step_correction_2026-11-13.md, sec. 11):
%     (a) samples flagged PUV.qc.vel_beamstep_unconfirmed by the L1 beam-step
%         correction (step-like runs it could not confirm, left as recorded);
%     (b) samples at or after instr.velInvalidFrom (datetime, UTC), a per-record
%         cutoff for a known velocity failure that L1 QC passes.
%
%   Inputs
%     PUV    L1 struct (needs .time; .qc.vel_beamstep_unconfirmed if present)
%     instr  config instrument struct (optional field .velInvalidFrom)
%   Outputs
%     velGap logical column, one per L1 sample; true = treat velocity as missing
%     info   struct: nUnconfirmed, nCutoff (sample counts), velInvalidFrom
%
%   Velocity only. Pressure is never masked here.
%
%   Written 2026-11-17 so the L4 modules that read L1 velocity directly
%   (reflection, reflection_free, boundwave, velocity_pdf) see the same gaps as
%   L2. PUV_L2_spectral keeps its own inline copy of this rule (unchanged, so
%   the published L2 needs no rebuild); test_l1_velocity_gap_mask checks that the
%   two agree on a record's counts.

n = numel(PUV.time);
velGap = false(n, 1);
info = struct('nUnconfirmed', 0, 'velInvalidFrom', NaT, 'nCutoff', 0);

if isfield(PUV, 'qc') && isfield(PUV.qc, 'vel_beamstep_unconfirmed')
    uc = logical(PUV.qc.vel_beamstep_unconfirmed(:));
    if numel(uc) ~= n
        error('l1_velocity_gap_mask:size', ...
            'qc.vel_beamstep_unconfirmed has %d samples, PUV.time has %d', numel(uc), n);
    end
    velGap = velGap | uc;
    info.nUnconfirmed = sum(uc);
end

if nargin > 1 && isfield(instr, 'velInvalidFrom') && ~isempty(instr.velInvalidFrom) ...
        && ~isnat(instr.velInvalidFrom)
    tcut = instr.velInvalidFrom;
    tL1  = PUV.time(:);
    if isempty(tL1.TimeZone) && ~isempty(tcut.TimeZone)
        tcut = datetime(tcut, 'TimeZone', 'UTC');  tcut.TimeZone = '';
    elseif ~isempty(tL1.TimeZone) && isempty(tcut.TimeZone)
        tcut.TimeZone = 'UTC';
    end
    cut = tL1 >= tcut;
    velGap = velGap | cut;
    info.velInvalidFrom = instr.velInvalidFrom;
    info.nCutoff = sum(cut);
end
end
