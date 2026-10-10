function qcOpts = l1_qc_opts(cfg)
% L1_QC_OPTS  Effective L1 per-channel QC options for a deployment config.
%
%   qcOpts = l1_qc_opts(cfg)
%
%   The defaults below, overlaid field by field with cfg.qcOpts. This is the
%   struct PUV_raw_process passes to puv_channel_qc and stores at PUV.qc.opts,
%   so validation/audit_L1_qcopts.m can compare a stored L1 against what its
%   config would produce today without duplicating the defaults.
%
%   Any field in cfg.qcOpts is copied, including ones the defaults do not
%   name (e.g. cutoffGapSec, which PUV_raw_process reads separately); they
%   are appended after the defaults, as before this was factored out.
%
%   Author: Holden Leslie-Bole, 2026

    % --- Per-channel QC options (channel decoupling, 2026-07-09). Thresholds unchanged
    % from the historical pipeline; only their propagation between channels has changed.
    qcOpts = struct( ...
        'corrMin',     70, ...      % Nortek minimum beam correlation, %
        'Tvalid',      [-2 40], ... % PRIMARY thermistor-failure discriminant: plausible
        ...                         % seawater temperature, degC. Default is a wide absolute
        ...                         % bound (catches freezing / firmware garbage anywhere);
        ...                         % SET TO THE SITE'S RANGE (SD coastal ~[9 26]) to catch
        ...                         % subtler within-bounds failures.
        'maxJump',     Inf, ...     % optional rate gate: |T[i]-T[i-1]| beyond this = sensor
        ...                         % glitch. Inf = off. Never fires on genuine drift.
        'cFactorTol',  0.002, ...   % below this, no sound-speed rescale is applied
        'tiltStdMax',  2, ...       % deg, rolling-std tilt-variability threshold
        'tiltAbsMax',  30, ...      % deg, absolute tilt = toppled; ALWAYS gates velocity
        'tiltWindow',  120, ...     % samples for the rolling std (60 s at 2 Hz)
        'offBedDbar',  1.0);        % dBar; |10-s mean - 30-min median| above this = the
                                    % sensor is in vertical transit (descent/ascent); those
                                    % samples, +-60 s, fail valid_p. Inf = off. Added
                                    % 2026-10-09; L1s built before then lack it.
    % TmaxDev / TrefHours (deviation-from-median test, first-48h reference) are REMOVED:
    % they conflated genuine seasonal range with sensor failure and corrupted good velocity
    % at the seasonal tails. See docs/OUTSTANDING_channel_decoupling.md and puv_channel_qc.m.
    if isfield(cfg,'qcOpts')
        fn = fieldnames(cfg.qcOpts);
        for q = 1:numel(fn), qcOpts.(fn{q}) = cfg.qcOpts.(fn{q}); end
    end
end
