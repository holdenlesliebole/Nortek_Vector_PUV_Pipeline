function [applied, fallbacks] = prov_applied(level, S, instr)
% PROV_APPLIED  The physical choices a built level actually carries, read from
% the level struct itself, plus any silent fallbacks visible in it.
%
%   [applied, fallbacks] = prov_applied(level, S)
%   [applied, fallbacks] = prov_applied(level, S, instr)
%
% level  'L1' | 'L2' | 'L3' | 'L4' | 'L4_xspec'
% S      the level struct (PUV, L2, L3, L4 or L4xs) as saved
% instr  (optional) the config instrument struct used for the build. With it,
%        the source of a choice can be stated (e.g. heading from config vs
%        compass median); without it (backfill) such sources are 'not recorded'.
%
% Used by build_provenance at build time and by scripts/backfill_provenance.m,
% so a built stamp and a backfilled stamp describe the same fields the same way.
% Values the struct does not store are written as 'not recorded', never guessed.
%
% Silent fallbacks this detects (both are caught by the producing function and
% the build carries on):
%   L2  shore-normal NaN although the instrument has a mopStation
%       (PUV_L2_spectral: CDIP fetch failed, processed in buoy coordinates)
%   L3  no L3.mop although the instrument has a mopStation
%       (PUV_L3_storms: offshore reference load failed, storms from PUV only)
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 3, instr = []; end
    NR = 'not recorded';
    applied = struct(); fallbacks = {};
    hasInstr = isstruct(instr) && ~isempty(instr);
    mopSt = '';
    if hasInstr && isfield(instr, 'mopStation') && ~isempty(instr.mopStation), mopSt = char(instr.mopStation); end

    switch level
    case 'L1'
        applied.doffp  = getf(S, 'doffp', NR);
        applied.LATLON = getf(S, 'LATLON', NR);
        applied.fs     = getf(S, 'fs', NR);
        if isfield(S, 'time') && ~isempty(S.time)
            applied.time_first = char(string(S.time(1), 'yyyy-MM-dd''T''HH:mm:ss'));
            applied.time_last  = char(string(S.time(end), 'yyyy-MM-dd''T''HH:mm:ss'));
            applied.n_samples  = numel(S.time);
        end
        r = getf(S, 'rotation', struct());
        applied.coordSystem        = getf(r, 'coordSystem', NR);
        applied.heading_deg        = getf(r, 'sensor', NR);
        applied.declination_deg    = getf(r, 'mag', NR);
        applied.declinationApplied = getf(r, 'declinationApplied', NR);
        if hasInstr && strcmp(applied.coordSystem, 'ENU')
            applied.heading_source = 'n/a (ENU: rotated on board)';
        elseif hasInstr && isfield(instr, 'heading') && isfinite(instr.heading)
            applied.heading_source = 'config';
        elseif hasInstr
            applied.heading_source = 'compass median (config heading NaN)';
        else
            applied.heading_source = NR;
        end
        q = getf(S, 'qc', struct());
        applied.qc_opts = getf(q, 'opts', NR);
        if hasInstr
            applied.rawFormat        = getf(instr, 'rawFormat', '');
            applied.clockSource      = getf(instr, 'clockSource', '');
            applied.clockOffsetHours = getf(instr, 'clockOffsetHours', []);
        end

    case 'L2'
        applied.shorenormal = getf(S, 'shorenormal', NR);
        if hasInstr && isfield(instr, 'shorenormal') && ~isempty(instr.shorenormal) && isfinite(instr.shorenormal)
            applied.shorenormal_source = 'manual config';
        elseif ~isempty(mopSt)
            applied.shorenormal_source = ['CDIP ' mopSt ' metaShoreNormal'];
        else
            applied.shorenormal_source = NR;
        end
        if ~isempty(mopSt) && isnumeric(applied.shorenormal) && ~isfinite(applied.shorenormal)
            fallbacks{end+1} = sprintf('L2 shore-normal: CDIP %s fetch failed, processed in buoy coordinates', mopSt);
        end
        applied.mopStation = getf(S, 'mopStation', NR);
        applied.doffp      = getf(S, 'doffp', NR);
        applied.LATLON     = getf(S, 'LATLON', NR);
        p = getf(S, 'params', struct());
        for f = {'segLen','nfft','overlap','fSS','fIG','fQ','spectralMethod','NW','D50', ...
                 'bedstress_method','bedstress_ks_m','bedstress_D84_m','bedstress_D50_m_used','bedstress_gs_status'}
            applied.(f{1}) = getf(p, f{1}, NR);
        end
        if isfield(S, 'time'), applied.n_segments = numel(S.time); end
        if isfield(S, 'segValid'), applied.n_valid = sum(S.segValid); end

    case 'L3'
        tp = getf(S, 'transport_params', struct());
        for f = {'D50','D50_source','rho_s','theta_cr','ws','ws_C2','Dstar','Cd_current','rouse_stress','code_version'}
            applied.(f{1}) = getf(tp, f{1}, NR);
        end
        applied.storm_reference = ternary(isfield(S, 'mop'), 'loaded', 'absent');
        if ~isempty(mopSt) && ~isfield(S, 'mop')
            fallbacks{end+1} = sprintf('L3 storm reference: CDIP %s load failed, storms from PUV only', mopSt);
        end
        if isfield(S, 'time'), applied.n_segments = numel(S.time); end

    case 'L4'
        applied.doffp       = getf(S, 'doffp', NR);
        applied.LATLON      = getf(S, 'LATLON', NR);
        applied.shorenormal = getf(S, 'shorenormal', NR);
        applied.builtAt     = NR;
        if isfield(S, 'builtAt'), applied.builtAt = char(string(S.builtAt, 'yyyy-MM-dd''T''HH:mm:ss')); end
        e = getf(S, 'eta', struct());   applied.eta_bands = getf(e, 'bands', NR);
        b = getf(S, 'bispectra', struct());
        for f = {'K','nfftSub','bandSwell','bandIG','bandSea'}, applied.(['bispectra_' f{1}]) = getf(b, f{1}, NR); end
        w = getf(S, 'boundwave', struct()); applied.boundwave_bandIG = getf(w, 'bandIG', NR);
        if isfield(e, 'time'), applied.n_segments = numel(e.time); end

    case 'L4_xspec'
        applied.inputField = getf(S, 'inputField', NR);
        applied.opts       = getf(S, 'opts', NR);
        if isfield(S, 'instruments'), applied.labels = {S.instruments.label}; end
        if isfield(S, 'pairs'), applied.n_pairs = numel(S.pairs); end

    otherwise
        error('prov_applied:level', 'unknown level %s', level);
    end
end

function v = getf(s, f, default)
    if isstruct(s) && isfield(s, f), v = s.(f); else, v = default; end
end

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
