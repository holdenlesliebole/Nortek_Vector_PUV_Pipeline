% DIAG_LEGACY_RUBY22_EXTENT  How much data did the legacy Ruby2D pipeline
% retain for the failed-pressure-sensor record?
% Author: Holden Leslie-Bole, 2026

LFile = '/Volumes/group/Ruby2D/PUV/Level1_QC/Torrey_Ruby2D_579_6m_processed.mat';
if ~isfile(LFile), error('legacy file missing'); end
S = load(LFile);

fprintf('=== Legacy Ruby2D 579_6m L1 ===\n');
fnTop = fieldnames(S);
fprintf('Top-level vars: %s\n', strjoin(fnTop', ', '));

PUVl = S.PUV;
fprintf('PUV fields: %s\n', strjoin(fieldnames(PUVl)', ', '));

%% Time extent
if isfield(PUVl,'time')
    t = PUVl.time;
    if isnumeric(t)
        t = datetime(t,'ConvertFrom','datenum');
    end
    fprintf('time array: n=%d, %s to %s, span=%.1f days\n', ...
        numel(t), char(t(1)), char(t(end)), days(t(end)-t(1)));
end

%% Pressure extent (which dates are non-NaN?)
if isfield(PUVl,'P')
    P = PUVl.P;
    valid = ~isnan(P);
    fprintf('P: total=%d, valid=%d (%.0f%%)\n', numel(P), sum(valid), 100*mean(valid));
    if isfield(PUVl,'time')
        idx = find(valid);
        if ~isempty(idx)
            fprintf('P valid time range: %s to %s (span=%.1f days)\n', ...
                char(t(idx(1))), char(t(idx(end))), days(t(idx(end))-t(idx(1))));
        end
    end
end

%% Velocity extent (does legacy keep velocity even where pressure failed?)
if isfield(PUVl,'BuoyCoord')
    bc = PUVl.BuoyCoord;
    fprintf('BuoyCoord fields: %s\n', strjoin(fieldnames(bc)', ', '));
    if isfield(bc,'U')
        U = bc.U;
        validU = ~isnan(U);
        fprintf('U: total=%d, valid=%d (%.0f%%)\n', numel(U), sum(validU), 100*mean(validU));
        if isfield(PUVl,'time')
            idxU = find(validU);
            if ~isempty(idxU)
                fprintf('U valid time range: %s to %s (span=%.1f days)\n', ...
                    char(t(idxU(1))), char(t(idxU(end))), days(t(idxU(end))-t(idxU(1))));
            end
        end
        % Check overlap: are there samples where U is valid but P is NaN?
        if isfield(PUVl,'P')
            U_only = validU & ~valid;
            both = validU & valid;
            fprintf('U-only valid (P=NaN): %d samples\n', sum(U_only));
            fprintf('Both U and P valid:   %d samples\n', sum(both));
            if sum(U_only) > 0 && isfield(PUVl,'time')
                idxUO = find(U_only);
                fprintf('U-only span: %s to %s\n', ...
                    char(t(idxUO(1))), char(t(idxUO(end))));
            end
        end
    end
end
