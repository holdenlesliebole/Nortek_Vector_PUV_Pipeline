function PUV = PUV_raw_process(instr, cfg)
% PUV_RAW_PROCESS  Load, QC, and rotate Nortek Vector data for one instrument.
%
%   PUV = PUV_raw_process(instr, cfg)
%
%   Reads raw .dat/.sen/.hdr files, applies clock-drift correction,
%   removes bad data (pitch/roll > 5 deg, pressure anomalies, minCorr < 70%),
%   rotates velocities from instrument XYZ to buoy coordinates
%   (+x WEST, +y NORTH, +z UP), and returns a PUV struct.
%
%   INPUTS
%     instr  - one element of cfg.instruments (struct with fields:
%              label, filePrefix, rawSubfolder, mopStation, mopLine,
%              depth_nominal, serialNum, latlon, heading, clockDrift, doffp)
%     cfg    - deployment config (struct with fields: name, rawDataRoot,
%              outputDir, fs)
%
%   OUTPUT
%     PUV    - struct with fields: time, fs, P, BuoyCoord, InstrCoord,
%              T, LATLON, rotation, doffp, label, deploymentName
%
%   Original code: Athina Lange, SIO July 2021
%   Rewritten for config-driven pipeline April 2026
% Author: Holden Leslie-Bole, 2026

    %% ========== GEOGRAPHICAL INFO ==========
    LAT = instr.latlon(1);
    LON = instr.latlon(2);

    %% ========== LOCATE RAW FILES ==========
    % Use localDataRoot if set (populated by copy_raw_to_local), otherwise
    % fall back to rawDataRoot (lab server). Reading from a local disk is
    % ~10x faster than reading large ASCII files over a network mount.
    if isfield(cfg, 'localDataRoot') && ~isempty(cfg.localDataRoot)
        dataRoot = cfg.localDataRoot;
    else
        dataRoot = cfg.rawDataRoot;
        warning('PUV_raw_process:networkRead', ...
            ['Reading from network mount — this will be slow for large files.\n' ...
             'Run copy_raw_to_local(cfg) first to cache files locally.']);
    end

    % Support both flat (rawSubfolder empty) and subfolder layouts
    if ~isempty(instr.rawSubfolder)
        instrDir = fullfile(dataRoot, instr.rawSubfolder);
    else
        instrDir = dataRoot;
    end

    if ~isfolder(instrDir)
        error('PUV_raw_process:dirNotFound', ...
            'Instrument directory not found: %s', instrDir);
    end

    %% ========== LOAD RAW DATA ==========
    % Two ingest paths produce the same DAT/SEN matrices:
    %   ASCII - the .dat/.sen/.hdr export written by Nortek ExploreV
    %   VEC   - the raw recorder binary, decoded by read_VEC
    %
    % Most of the pre-2023 archive was never exported to ASCII, and some of the
    % exports that do exist are partial (TORREY02_1.dat holds 5.1 days of a
    % 174-day record) or ship 0-byte .hdr files, which leaves sampling rate and
    % coordinate system unrecoverable from ASCII. Decoding the binary avoids
    % both problems and needs no Windows tooling.
    %
    % Set instr.rawFormat to 'VEC' or 'ASCII' to force a path. Leaving it unset
    % auto-detects and prefers ASCII, so deployments with a partial export MUST
    % set 'VEC' explicitly — see the warning in select_raw_format.
    rawFormat = select_raw_format(instrDir, instr);
    fprintf('  Ingest format: %s\n', rawFormat);

    switch rawFormat
        case 'ASCII'
            [DAT_bursts, SEN_bursts, date_start, date_end, fs, coordSystem] = ...
                load_from_ASCII(instrDir, instr);
        case 'VEC'
            [DAT_bursts, SEN_bursts, date_start, date_end, fs, coordSystem] = ...
                load_from_VEC(instrDir, instr);
    end
    nBursts = numel(DAT_bursts);

    %% ========== CLOCK DRIFT CORRECTION ==========
    % Total deployment duration in seconds (start of first burst to end of last)
    dt_start = datetime(date_start(1,:),   'InputFormat', 'YYYYMMDDHHmmSS');
    dt_final = datetime(date_end(end,:),   'InputFormat', 'YYYYMMDDHHmmSS') + seconds(1/fs);
    totalseconds = seconds(dt_final - dt_start);

    if isnan(instr.clockDrift)
        warning('PUV_raw_process:nanClockDrift', ...
            'Clock drift is NaN for %s — skipping drift correction.', instr.label);
        nSamples_drift = round(totalseconds * fs) + 1;
        driftfix = zeros(1, nSamples_drift);
    else
        nSamples_drift = round(totalseconds * fs) + 1;
        driftfix = linspace(0, instr.clockDrift, nSamples_drift);
        % Convert to duration for subtraction from datetime array
    end

    %% ========== DETECT BATTERY CUTOFF ==========
    % A large gap between consecutive SEN samples means the instrument was
    % recording intermittently (battery depletion); truncate at the first one.
    %
    % The threshold defaults to 1 s, which suits the modern continuously-sampled
    % instruments. The firmware-1.21 recorders in the pre-2019 archive instead
    % put one benign 3-4 s hiccup in essentially every hourly file, so a 1 s
    % threshold would read the first hiccup as death and discard the whole
    % record. Those configs set cfg.qcOpts.cutoffGapSec to a value (e.g. 60 s)
    % that clears the hiccups while still catching a real multi-minute dropout.
    cutoffGapSec = 1;
    if isfield(cfg, 'qcOpts') && isfield(cfg.qcOpts, 'cutoffGapSec') && ...
            ~isempty(cfg.qcOpts.cutoffGapSec)
        cutoffGapSec = cfg.qcOpts.cutoffGapSec;
    end

    % A gap at the very start of a burst is a power-on glitch, not battery
    % death: some recorders write a single sample when switched on, then a big
    % gap, then the real deployment. TOR16B opens with one ping and a 2463 s
    % gap. Trim those isolated leading samples off the front burst(s) so the
    % record starts at the first continuous data, instead of reading the glitch
    % as an end-of-life cutoff. Only the leading edge is trimmed; an interior
    % gap still marks a real cutoff below.
    b = 1;
    while b <= nBursts
        S = SEN_bursts{b};
        if isempty(S), b = b + 1; continue; end
        tt = datetime([S(:,3) S(:,1:2) S(:,4:6)], 'InputFormat', 'YYYYMMDDHHmmSS');
        g = find(diff(tt) > seconds(cutoffGapSec), 1, 'first');
        if isempty(g)
            break;                     % this burst starts clean — done trimming
        end
        % Drop samples 1..g (the isolated leading ping and the gap) from burst b.
        keepFrom = g + 1;
        DATb = DAT_bursts{b};
        S(1:g, :) = [];
        DATb(1 : min(g*fs, size(DATb,1)), :) = [];
        if isempty(S)
            SEN_bursts(b) = []; DAT_bursts(b) = [];
            date_start(b,:) = []; date_end(b,:) = [];
            nBursts = nBursts - 1;     % re-check the same index, now the next burst
        else
            SEN_bursts{b} = S; DAT_bursts{b} = DATb;
            date_start(b,:) = [S(1,3) S(1,1:2) S(1,4:6)];
            fprintf('  Trimmed %d leading glitch sample(s) from burst %d (power-on gap)\n', ...
                keepFrom-1, b);
            break;                     % front is now clean
        end
    end

    % Now scan for a genuine interior cutoff (battery death / clock jump).
    cutoff = [];
    for ii = 1:nBursts
        SENii = SEN_bursts{ii};
        date_temp = datetime([SENii(:,3) SENii(:,1:2) SENii(:,4:6)], ...
                             'InputFormat', 'YYYYMMDDHHmmSS');
        gaps = find(diff(date_temp) > seconds(cutoffGapSec));
        if ~isempty(gaps)
            cutoff.burst = ii;
            cutoff.id    = gaps(1);
            warning('PUV_raw_process:cutoffDetected', ...
                'Battery cutoff detected in burst %d at sample %d (gap > %g s).', ...
                ii, gaps(1), cutoffGapSec);
            break
        end
    end

    % Trim data at the cutoff point
    if ~isempty(cutoff)
        ii = cutoff.burst;

        if cutoff.id <= 1
            % The gap is at the very start of this burst, so there is nothing
            % worth keeping in it — the instrument had already gone intermittent
            % before burst ii opened. Keep bursts 1..ii-1 whole. (Possible with
            % the per-file bursts of the pre-2019 archive, where each hourly
            % file is its own burst; the large-burst deployments always had
            % cutoff.id well inside a burst.)
            lastKeep = ii - 1;
            if lastKeep < 1
                error('PUV_raw_process:cutoffAtStart', ...
                    ['Battery cutoff at the first sample of the first burst — ' ...
                     'no usable data in %s.'], instrDir);
            end
            SEN_bursts(lastKeep+1 : end) = [];
            DAT_bursts(lastKeep+1 : end) = [];
            date_start(lastKeep+1 : end, :) = [];
            date_end(lastKeep+1 : end, :)   = [];
            nBursts = lastKeep;
            fprintf('  Truncated before burst %d (gap at its first sample); kept %d bursts\n', ...
                ii, lastKeep);
        else
            SENii = SEN_bursts{ii};
            DATii = DAT_bursts{ii};

            % Pad DAT to match fs * length(SEN) before trimming
            nSEN = size(SENii, 1);
            nDAT = size(DATii, 1);
            nCols_DAT = size(DATii, 2);
            if nDAT < nSEN * fs
                DATii(end+1 : nSEN*fs, :) = NaN;
            end

            % Remove everything past the cutoff in this burst
            SENii(cutoff.id:end, :) = [];
            DATii(cutoff.id * fs - 1:end, :) = [];

            SEN_bursts{ii} = SENii;
            DAT_bursts{ii} = DATii;

            % Update the end date for this burst
            date_end(ii,:) = [SENii(end,3) SENii(end,1:2) SENii(end,4:6)];

            % Discard all bursts after the cutoff
            SEN_bursts(cutoff.burst+1 : end) = [];
            DAT_bursts(cutoff.burst+1 : end) = [];
            date_start(cutoff.burst+1 : end, :) = [];
            date_end(cutoff.burst+1 : end, :)   = [];
            nBursts = cutoff.burst;

            fprintf('  Truncated at burst %d, sample %d\n', cutoff.burst, cutoff.id);
        end
    end

    %% ========== COMBINE ALL BURSTS INTO FULL-DEPLOYMENT ARRAYS ==========
    % Convert date bookends to datetime
    dt_starts = datetime(date_start, 'InputFormat', 'YYYYMMDDHHmmSS');
    dt_ends   = datetime(date_end,   'InputFormat', 'YYYYMMDDHHmmSS');

    % Full datetime vector at sampling rate
    full_date = dt_starts(1) : seconds(1/fs) : dt_ends(end) + seconds(1/fs);

    nCols_DAT = size(DAT_bursts{1}, 2);
    nCols_SEN = size(SEN_bursts{1}, 2);
    DAT = NaN(length(full_date), nCols_DAT);
    SEN = NaN(length(full_date), nCols_SEN);

    if fs == 2
        fprintf('  Merging bursts (2 Hz sampling)\n');
        for ii = 1:nBursts
            SENii = SEN_bursts{ii};
            DATii = DAT_bursts{ii};

            % Pad DAT so it has exactly 2x the number of SEN rows
            nSEN = size(SENii, 1);
            nDAT = size(DATii, 1);
            if nDAT < nSEN * 2
                DATii(end+1 : nSEN*2, :) = NaN;
            end

            % Find index range in the full deployment array.
            % Use nearest-match (within 1 sample) to handle sub-second
            % time misalignments between burst boundaries and the
            % regular full_date grid.
            iStart = find(full_date == dt_starts(ii), 1);
            iEnd   = find(full_date == dt_ends(ii), 1);

            if isempty(iStart)
                [minDt, iStart] = min(abs(full_date - dt_starts(ii)));
                if minDt > seconds(1/fs)
                    warning('PUV_raw_process:burstAlignFailed', ...
                        'Burst %d start time misaligned by %.2f s — skipping.', ii, seconds(minDt));
                    continue
                end
            end
            if isempty(iEnd)
                [minDt, iEnd] = min(abs(full_date - dt_ends(ii)));
                if minDt > seconds(1/fs)
                    warning('PUV_raw_process:burstAlignFailed', ...
                        'Burst %d end time misaligned by %.2f s — skipping.', ii, seconds(minDt));
                    continue
                end
            end

            % DAT is at 2 Hz — fill contiguously
            nFill = iEnd - iStart + 2;  % +2 because original uses iEnd+1
            nFill = min(nFill, size(DATii, 1));
            nFill = min(nFill, length(full_date) - iStart + 1);
            DAT(iStart : iStart+nFill-1, :) = DATii(1:nFill, :);

            % SEN is at 1 Hz — duplicate each sample to fill 2 Hz slots. When a
            % burst has an internal gap (the firmware-1.21 recorders drop a few
            % seconds in nearly every hourly file), its grid span iEnd-iStart is
            % larger than its SEN row count, so the destination index can have
            % more slots than there are source rows. Truncate BOTH sides to the
            % common length rather than only the source, or the assignment sizes
            % disagree. (Latent since the pipeline began; the gap-free modern
            % bursts never exposed it.)
            senEnd  = min(iEnd+1, length(full_date));
            evenIdx = iStart   : 2 : senEnd;
            oddIdx  = iStart+1 : 2 : iEnd;
            nEven = min(numel(evenIdx), size(SENii,1));
            nOdd  = min(numel(oddIdx),  size(SENii,1));
            SEN(evenIdx(1:nEven), :) = SENii(1:nEven, :);
            SEN(oddIdx(1:nOdd),   :) = SENii(1:nOdd,  :);
        end
    else
        % 1 Hz sampling
        fprintf('  Merging bursts (1 Hz sampling)\n');
        for ii = 1:nBursts
            SENii = SEN_bursts{ii};
            DATii = DAT_bursts{ii};

            nSEN = size(SENii, 1);
            nDAT = size(DATii, 1);
            if nDAT < nSEN
                DATii(end+1 : nSEN, :) = NaN;
            end

            iStart = find(full_date == dt_starts(ii), 1);
            iEnd   = find(full_date == dt_ends(ii), 1);

            if isempty(iStart)
                [minDt, iStart] = min(abs(full_date - dt_starts(ii)));
                if minDt > seconds(1), continue; end
            end
            if isempty(iEnd)
                [minDt, iEnd] = min(abs(full_date - dt_ends(ii)));
                if minDt > seconds(1), continue; end
            end

            nFill = iEnd - iStart + 2;
            nFill = min(nFill, size(DATii, 1));
            nFill = min(nFill, length(full_date) - iStart + 1);
            DAT(iStart : iStart+nFill-1, :) = DATii(1:nFill, :);
            nSenFill = min(nFill, size(SENii,1));   % SEN can be shorter than the span
            SEN(iStart : iStart+nSenFill-1, :) = SENii(1:nSenFill, :);
        end
    end

    % Free burst cell arrays to save memory
    clear SEN_bursts DAT_bursts

    %% ========== APPLY CLOCK DRIFT ==========
    % Trim drift vector to match the actual data length (may differ from
    % initial estimate if cutoff was applied)
    if length(driftfix) > length(full_date)
        driftfix(length(full_date)+1 : end) = [];
    elseif length(driftfix) < length(full_date)
        % Extend with the final drift value (unlikely but defensive)
        driftfix(end+1 : length(full_date)) = driftfix(end);
    end
    full_date = full_date - seconds(driftfix);

    %% ========== QC: PITCH, ROLL, PRESSURE THRESHOLDS ==========
    % Two-stage tilt QC:
    %   Stage 1: Flag samples where pitch/roll VARIABILITY is high (instrument
    %            is moving/unstable). Uses a rolling-window std deviation.
    %   Stage 2: Flag samples where pressure is anomalous (deployment/recovery).
    %
    % Samples with large but STABLE tilt (e.g., bent pipe after a storm) are
    % kept — the tilt will be corrected via rotation before heading rotation.
    %
    % Thresholds:
    %   tiltStdMax   = 2 deg — max rolling std of pitch or roll (instability)
    %   tiltAbsMax   = 30 deg — absolute tilt beyond which data is unreliable
    %   tiltWindow   = 120 samples (60 sec at 2 Hz) — window for rolling std

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
        'tiltWindow',  120);        % samples for the rolling std (60 s at 2 Hz)
    % TmaxDev / TrefHours (deviation-from-median test, first-48h reference) are REMOVED:
    % they conflated genuine seasonal range with sensor failure and corrupted good velocity
    % at the seasonal tails. See docs/OUTSTANDING_channel_decoupling.md and puv_channel_qc.m.
    if isfield(cfg,'qcOpts')
        fn = fieldnames(cfg.qcOpts);
        for q = 1:numel(fn), qcOpts.(fn{q}) = cfg.qcOpts.(fn{q}); end
    end

    tiltStdMax = qcOpts.tiltStdMax;   % used by the diagnostic plot below; the per-channel
    tiltAbsMax = qcOpts.tiltAbsMax;   % QC decisions are made in puv_channel_qc.m from qcOpts
    tiltWindow = qcOpts.tiltWindow;

    % --- Build diagnostic copies for the "before/after" plot ---
    pitch_raw    = SEN(:, 12);
    roll_raw     = SEN(:, 13);
    pressure_raw = DAT(:, 15);

    % Work on copies first to produce the "after" trace for diagnostics
    pitch_qc    = pitch_raw;
    roll_qc     = roll_raw;
    pressure_qc = pressure_raw;

    % Compute rolling standard deviation of pitch and roll
    pitchStd = movstd(pitch_raw, tiltWindow, 'omitnan');
    rollStd  = movstd(roll_raw,  tiltWindow, 'omitnan');

    % Stage 1: Flag UNSTABLE tilt (high variability within window)
    bad_tilt_var = pitchStd > tiltStdMax | rollStd > tiltStdMax;
    pitch_qc(bad_tilt_var) = NaN;
    roll_qc(bad_tilt_var)  = NaN;
    pressure_qc(bad_tilt_var) = NaN;

    % Stage 1b: Flag extreme absolute tilt (instrument completely toppled)
    bad_tilt_abs = abs(pitch_raw) >= tiltAbsMax | abs(roll_raw) >= tiltAbsMax;
    pitch_qc(bad_tilt_abs) = NaN;
    roll_qc(bad_tilt_abs)  = NaN;
    pressure_qc(bad_tilt_abs) = NaN;

    % Stage 1c: Compute pMed from a HEALTHY reference window — the first
    % burst's in-water samples — instead of the full record. Rationale:
    % some instruments (e.g., RUBY22/MOP579_6m) suffered mid-deployment
    % sensor-block failure where pressure saturates at the firmware
    % overflow code (~239.679 dBar) AND temperature/sound-speed read
    % unphysical values. When >50% of samples are corrupted, the global
    % median lands in the bad band and the [pMed/2, 2*pMed] filter below
    % inverts — keeping noise and rejecting good data.
    %
    % Reference-window strategy:
    %   - Use the first burst (~the first 1/nBursts of full_date, but more
    %     robustly we use the first ~10% of valid samples).
    %   - Restrict to in-water samples (P > 0.5 dBar) so deployment-time
    %     zeros don't pull pMed toward 0.
    %   - If the reference window is empty (instrument failed at deploy),
    %     fall back to depth_nominal as a prior.
    nValid_init = sum(~isnan(pressure_qc));
    refN = max(round(0.10 * numel(pressure_qc)), 1000);
    refN = min(refN, numel(pressure_qc));
    refSlice = pressure_qc(1:refN);
    refIn   = refSlice(refSlice > 0.5 & ~isnan(refSlice));
    if numel(refIn) >= 100
        pMed_ref = median(refIn);
        fprintf('  pMed reference: first %d samples, %d in-water → pMed_ref=%.2f dBar\n', ...
            refN, numel(refIn), pMed_ref);
    elseif isfield(instr,'depth_nominal') && ~isnan(instr.depth_nominal)
        pMed_ref = instr.depth_nominal;
        warning('PUV_raw_process:noRefWindow', ...
            'No healthy reference window — falling back to depth_nominal=%.1f m as pMed prior.', pMed_ref);
    else
        error('PUV_raw_process:noRefWindow', ...
            'Cannot estimate pMed: no healthy early samples and no depth_nominal.');
    end

    % Sanity-check the reference pMed against expected depth.
    if isfield(instr, 'depth_nominal') && ~isnan(instr.depth_nominal)
        h_expect = instr.depth_nominal;
        if pMed_ref > 3 * h_expect + 5 || pMed_ref < 0.2 * h_expect
            error('PUV_raw_process:pressureSanity', ...
                ['pMed_ref = %.2f dBar is implausible for nominal depth %.1f m. ' ...
                 'Likely sensor failed at deployment; check L1 diagnostic plot.'], ...
                pMed_ref, h_expect);
        end
    end

    % Stage 2: Use the reference pMed to filter the WHOLE record. Samples
    % outside [pMed_ref/2, 2*pMed_ref] are treated as failed-sensor data —
    % even if they look "consistent" later in the record (e.g., a sensor
    % that saturates at 239 dBar for weeks). The row-level NaN'ing below
    % at line ~510 will propagate this to velocities, which is the right
    % call when the failure is sensor-block-wide (pressure + temperature +
    % sound-speed all corrupt → ADV velocities are also unreliable).
    pMed = pMed_ref;
    bad = pressure_qc < pMed/2;
    pitch_qc(bad) = NaN; roll_qc(bad) = NaN; pressure_qc(bad) = NaN;

    bad = pressure_qc > pMed*2;
    pitch_qc(bad) = NaN; roll_qc(bad) = NaN; pressure_qc(bad) = NaN;

    nValid_post = sum(~isnan(pressure_qc));
    fprintf('  Pressure QC: %d → %d samples valid (%.1f%% of original valid)\n', ...
        nValid_init, nValid_post, 100*nValid_post/max(nValid_init,1));

    % --- Save diagnostic plot ---
    diagDir = fullfile(cfg.outputDir, 'L1', 'diagnostics');
    if ~exist(diagDir, 'dir'), mkdir(diagDir); end

    fig = figure('Visible', 'off', 'Position', [100 100 1200 900]);

    subplot(4,1,1)
    plot(full_date, pitch_raw, 'Color', [0.7 0.7 0.7]); hold on
    plot(full_date, pitch_qc, 'b');
    title('Pitch'); ylabel('degrees'); legend('raw','QC');

    subplot(4,1,2)
    plot(full_date, roll_raw, 'Color', [0.7 0.7 0.7]); hold on
    plot(full_date, roll_qc, 'b');
    title('Roll'); ylabel('degrees'); legend('raw','QC');

    subplot(4,1,3)
    plot(full_date, pitchStd, 'r', 'LineWidth', 0.5); hold on
    plot(full_date, rollStd, 'b', 'LineWidth', 0.5);
    yline(tiltStdMax, 'k--', sprintf('%.0f° threshold', tiltStdMax));
    title('Tilt variability (rolling std)'); ylabel('degrees');
    legend('pitch std', 'roll std');

    subplot(4,1,4)
    plot(full_date, pressure_raw, 'Color', [0.7 0.7 0.7]); hold on
    plot(full_date, pressure_qc, 'b');
    title('Pressure'); ylabel('dBar'); legend('raw','QC');

    sgtitle(sprintf('%s  %s  —  L1 QC (tilt variability method)', cfg.name, instr.label), ...
        'Interpreter', 'none');
    diagFile = fullfile(diagDir, sprintf('%s_%s_L1_QC.png', cfg.name, instr.label));
    exportgraphics(fig, diagFile, 'Resolution', 150);
    close(fig);
    fprintf('  Diagnostic plot saved: %s\n', diagFile);

    %% ========== PER-CHANNEL QC (channel decoupling, 2026-07-09) ==========
    % PREVIOUS BEHAVIOUR, now removed: a pressure excursion or an unstable-tilt flag
    % NaN'd the ENTIRE DAT/SEN row, destroying Doppler velocities that were
    % independently healthy:
    %
    %     bad = bad_tilt_var | bad_tilt_abs;  DAT(bad,:) = NaN; SEN(bad,:) = NaN;
    %     bad = DAT(:,15) < pMed/2;           DAT(bad,:) = NaN; SEN(bad,:) = NaN;
    %     bad = DAT(:,15) > pMed*2;           DAT(bad,:) = NaN; SEN(bad,:) = NaN;
    %
    % The justification given for that ("sensor-block-wide failure => ADV velocities
    % are also unreliable") was a HYPOTHESIS about the Doppler channels, written for the
    % RUBY22 failure, never tested against them. It is false at TOR23W/MOP586_10m: through
    % 25-29 Dec 2023 the pressure sensor and thermistor were dead while beam correlations
    % held at 92.6-97.0% and amplitude was elevated. 597 L2 segments -- including every
    % hour of the deployment above Hs = 3 m -- were discarded for no reason.
    %
    % Each channel is now judged on its own evidence. THRESHOLDS ARE UNCHANGED; only the
    % propagation between channels is removed. On healthy data this is a bitwise no-op.
    % See docs/L1_sensor_block_failure_2026-07-09.md and test_channel_decoupling.m.

    % TILT IS NOT AN AUXILIARY CHANNEL. Pressure and temperature say nothing about the
    % Doppler measurement, so they must not gate it. Tilt is different: it is a statement
    % about the measurement GEOMETRY. A frame that has toppled, or that is still moving,
    % contaminates the velocity with its own motion, and no rotation repairs that.
    %
    % Found the hard way (N6, 2026-07-09). TOR23W/MOP580_7m fails in the same storm and
    % looks superficially similar -- one unbroken 523-segment run from 28 Dec 23:29 -- but
    % its sensor block is HEALTHY throughout (battery 14.40 V, c = 1511 m/s, T = 17.0-17.4).
    % What failed is the frame: pitch -0.8 -> -15.6 deg, roll -0.6 -> -33.7 deg, heading
    % 73 -> 117 deg over three days. It fell over. Rescuing that velocity and rotating it
    % with a "healthy" static tilt would fabricate a geometry the instrument never had.
    %
    % So: trust the tilt sensor only when the sensor block it lives on is healthy. The
    % thermistor is the tell -- it shares that block, and it is what failed at MOP586_10m
    % (T = -5 C, battery swinging to 19.5 V, heading wandering 70-96 deg) while the frame
    % itself sat still at 1.3 deg.
    %
    %   tilt trusted   (valid_T) -> tilt gates velocity, exactly as before
    %   tilt untrusted (~valid_T) -> tilt cannot gate velocity; rotate with a static tilt
    %                               from the healthy window, and flag it
    %
    % All of these decisions are made in puv_channel_qc.m (a pure, tested function). This
    % block only APPLIES them to DAT/SEN. See test_puv_channel_qc.m.
    qc = puv_channel_qc(DAT, SEN, fs, pMed, cfg, qcOpts, instr.label);
    valid_vel   = qc.valid_vel;    valid_p     = qc.valid_p;
    valid_tilt  = qc.valid_tilt;   valid_joint = qc.valid_joint;
    valid_T     = qc.valid_T;      tilt_trusted = qc.tilt_trusted;
    Tref = qc.Tref;

    nToppled = sum(qc.valid_corr & qc.present & tilt_trusted & ~valid_tilt);
    if nToppled > 0
        fprintf(['  %d samples (%.1f%%) have healthy Doppler but a TRUSTED bad tilt ' ...
                 '(frame moved or toppled): velocity invalidated, as before.\n'], ...
                nToppled, 100*nToppled/numel(valid_vel));
    end

    % Velocity: killed ONLY by the Doppler diagnostics.
    DAT(~valid_vel, 3:5)  = NaN;
    % Pressure: killed only by pressure.
    DAT(~valid_p, 15)     = NaN;
    % Tilt: killed only by tilt. (SEN cols 12,13 = pitch, roll.)
    SEN(~valid_tilt, 12:13) = NaN;

    fprintf('  Per-channel QC: velocity %.1f%% valid, pressure %.1f%% valid, tilt %.1f%% valid\n', ...
        100*mean(valid_vel), 100*mean(valid_p), 100*mean(valid_tilt));
    nRescued = sum(valid_vel & ~valid_joint);
    if nRescued > 0
        fprintf('  --> %d samples (%.1f%%) carry healthy velocity that the old row-level gate discarded\n', ...
            nRescued, 100*nRescued/numel(valid_vel));
    end

    %% ========== TRIM LEADING NaNs ==========
    % Start the timeseries at the first in-water sample so we don't carry a block of NaN from
    % before submersion. Channel-aware (F5 fix): a whole-deployment pressure failure with a
    % healthy Doppler head used to make DAT(:,15) all-NaN and throw, discarding exactly the
    % velocity Stage 1 exists to rescue. See puv_trim_anchor.m / test_puv_trim_anchor.
    if all(isnan(DAT(:,15))) && any(~isnan(DAT(:,3)) & ~isnan(DAT(:,4)))
        warning('PUV_raw_process:noValidPressure', ...
            ['%s: no valid pressure anywhere; anchoring the trim on velocity instead. ' ...
             'Pressure-derived products (Hs, depth) unavailable, but velocity is recovered.'], ...
            instr.label);
    end
    firstGood = puv_trim_anchor(DAT);
    % Pull the per-sample decisions out of qc and trim them alongside the data.
    vel_c_factor        = qc.vel_c_factor;
    vel_c_corrected     = qc.vel_c_corrected;
    vel_rotation_static = qc.vel_rotation_static;
    trim = @(x) x(firstGood:end, :);
    DAT = trim(DAT);  SEN = trim(SEN);  full_date = full_date(firstGood:end);
    valid_vel = trim(valid_vel);  valid_p = trim(valid_p);  valid_tilt = trim(valid_tilt);
    valid_joint = trim(valid_joint);  valid_T = trim(valid_T);  tilt_trusted = trim(tilt_trusted);
    vel_c_factor = trim(vel_c_factor);  vel_c_corrected = trim(vel_c_corrected);
    vel_rotation_static = trim(vel_rotation_static);

    %% ========== EXTRACT VELOCITY, PRESSURE, TEMPERATURE ==========
    U = DAT(:,3);   % East / X velocity (m/s)
    V = DAT(:,4);   % North / Y velocity (m/s)
    W = DAT(:,5);   % Up / Z velocity (m/s)
    T = SEN(:,14);  % temperature (deg C)
    P = DAT(:,15);  % pressure (dBar)

    %% ========== SOUND-SPEED CORRECTION (Stage 2, 2026-07-09) ==========
    % The .hdr declares `Sound speed  MEASURED`, so the Vector computes c from its own
    % thermistor and scales the recorded velocity by it. Nortek, "Comprehensive Manual --
    % Velocimeters" (N3015-030) section 2.4.9 p.53, repeated 5.3.4 p.112:
    %
    %       V_corrected = V_old * (C_new / C_old)
    %
    %   "The instruments compute the speed of sound based on the measured temperature
    %    (accuracy of 0.1 C). A nominal salinity is assumed."
    %
    % A dead thermistor therefore biases every velocity LINEARLY. At TOR23W/MOP586_10m the
    % thermistor read -5 C, c fell 1512 -> 1433 m/s, and the recorded velocities were 5.2%
    % low -- which is 14.9% low in <u^3>, since the moment goes as c^3.
    %
    % Verified against the data band by band (docs/..., Addendum 2): in the swell band the
    % Phase-A deflation is 0.9659 / 0.9488 / 0.9353 over 0.040-0.090 Hz, bracketing the
    % predicted c_rec/c_true = 0.9497.
    %
    % The factor is EXACTLY 1 wherever the thermistor is healthy, so this is a bitwise
    % no-op on good data -- a property, not a gate. test_puv_channel_qc T3 asserts it.
    % The factor and the c(T) reference were decided in puv_channel_qc; apply them here,
    % ONLY where a correction is actually needed, so healthy samples are untouched
    % bit-for-bit rather than multiplied by a floating-point 1.0.
    ap = vel_c_corrected;
    if any(ap)
        U(ap) = U(ap) .* double(vel_c_factor(ap));
        V(ap) = V(ap) .* double(vel_c_factor(ap));
        W(ap) = W(ap) .* double(vel_c_factor(ap));
        fprintf(['  Sound-speed correction: %d samples rescaled (median factor %.4f)\n' ...
                 '    source: %s\n'], sum(ap), median(double(vel_c_factor(ap))), qc.c_source);
    end
    T(~valid_T) = NaN;   % never pass a fabricated temperature downstream

    %% ========== TILT CORRECTION ==========
    % If the instrument is tilted (bent pipe), rotate velocities from the
    % tilted instrument frame to the true vertical frame using measured
    % pitch and roll angles. This corrects for static tilts (stable bent
    % pipe) while the variability QC above already rejected unstable periods.
    %
    % For a tilted instrument:
    %   R_pitch rotates around the Y axis by pitch angle
    %   R_roll  rotates around the X axis by roll angle
    %   [U;V;W]_corrected = R_roll * R_pitch * [U;V;W]_measured
    %
    % The pitch/roll values from SEN are at 1 Hz (duplicated to 2 Hz),
    % so the correction is applied sample-by-sample.
    % Static tilt substitution applies ONLY where the tilt sensor itself is untrustworthy
    % (its sensor block failed), never where a trusted sensor reports a real tilt. In the
    % latter case the velocity has already been invalidated above. See N6. The decision
    % (which samples, and the static pitch/roll from the healthy window) is made in
    % puv_channel_qc; apply it here.
    if any(vel_rotation_static)
        pStat = qc.pStat;  rStat = qc.rStat;
        if isfinite(pStat) && isfinite(rStat)
            SEN(vel_rotation_static,12) = pStat;
            SEN(vel_rotation_static,13) = rStat;
            fprintf('  Static tilt applied to %d samples (pitch %.2f, roll %.2f deg)\n', ...
                sum(vel_rotation_static), pStat, rStat);
        end
    end

    pitch_deg = SEN(:, 12);
    roll_deg  = SEN(:, 13);

    % Only apply tilt correction where pitch/roll are valid (not NaN'd by QC)
    hasValidTilt = ~isnan(pitch_deg) & ~isnan(roll_deg) & ~isnan(U);
    maxTilt = max(abs(median(pitch_deg(hasValidTilt), 'omitnan')), ...
                  abs(median(roll_deg(hasValidTilt), 'omitnan')));

    if maxTilt > 1.0  % only correct if median tilt > 1 degree
        fprintf('  Tilt correction: median pitch=%.1f°, roll=%.1f° — applying rotation\n', ...
            median(pitch_deg(hasValidTilt), 'omitnan'), ...
            median(roll_deg(hasValidTilt), 'omitnan'));

        p_rad = deg2rad(pitch_deg);
        r_rad = deg2rad(roll_deg);

        % Apply sample-by-sample 3D rotation
        U_tc = U;  V_tc = V;  W_tc = W;
        idx = find(hasValidTilt);
        for jj = 1:length(idx)
            ii = idx(jj);
            cp = cos(p_rad(ii)); sp = sin(p_rad(ii));
            cr = cos(r_rad(ii)); sr = sin(r_rad(ii));

            % R_roll * R_pitch (extrinsic rotation)
            U_tc(ii) =  cp      * U(ii) + sp*sr   * V(ii) + sp*cr   * W(ii);
            V_tc(ii) =              cr   * V(ii) -    sr   * W(ii);
            W_tc(ii) = -sp      * U(ii) + cp*sr   * V(ii) + cp*cr   * W(ii);
        end
        U = U_tc;  V = V_tc;  W = W_tc;
    else
        fprintf('  Tilt < 1° — no tilt correction needed\n');
    end

    %% ========== COORDINATE ROTATION TO BUOY FRAME ==========
    % Compute magnetic declination at the deployment start location and time.
    % decyear() requires Aerospace Toolbox, so compute decimal year manually.
    yr   = date_start(1,1);
    doy  = datenum(yr, date_start(1,2), date_start(1,3)) - datenum(yr, 1, 0);
    isLeap = (mod(yr,4)==0 && mod(yr,100)~=0) || mod(yr,400)==0;
    decYr = yr + (doy - 1) / (365 + double(isLeap));
    % igrfmagm (Mapping Toolbox) — handles any date, unlike wrldmagm which is
    % limited to a 5-year WMM lifespan. Height in km (0 = sea level).
    % IGRF-13 covers through 2025.0; for later dates, try epoch 14 first,
    % fall back to capping at 2025.0 (extrapolation error < 0.1 deg/yr).
    try
        [~, ~, magDeclination, ~, ~] = igrfmagm(0, LAT, LON, decYr, 14);
    catch
        decYrCapped = min(decYr, 2024.99);
        [~, ~, magDeclination, ~, ~] = igrfmagm(0, LAT, LON, decYrCapped, 13);
        if decYr > 2025
            warning('PUV_raw_process:igrfCapped', ...
                'IGRF-13 limit reached (decYr=%.2f). Using 2025.0 declination (error < 0.1 deg).', decYr);
        end
    end

    if coordSystem == "XYZ"
        % For an upward-looking XYZ sensor, +z is down, so flip sign.
        W = -W;

        % Sensor heading is the magnetic compass bearing of beam 1 (+x axis).
        % If heading is NaN in config, compute from median compass reading.
        if isnan(instr.heading)
            heading_col = SEN(:, 11);
            heading_col = heading_col(~isnan(heading_col));
            theta_mag   = median(heading_col);
            fprintf('  Auto-computed heading from .sen data: %.4f deg\n', theta_mag);
        else
            theta_mag = instr.heading;
        end

        % Add mag declination to get true bearing of +x.
        theta_true = theta_mag + magDeclination;

        % Rotation angle: we want +x = WEST (270 deg true), so the CW
        % rotation from the instrument's true-x axis to 270 deg is:
        rotation_deg = 270 - theta_true;
        alpha_rad    = rotation_deg * pi / 180;

        % Left-handed (CW) rotation matrix
        rot_mat = [ cos(alpha_rad)  sin(alpha_rad);
                   -sin(alpha_rad)  cos(alpha_rad)];

        uv     = rot_mat * [U'; V'];
        U_true = uv(1,:).';   % +x WEST
        V_true = uv(2,:).';   % +y NORTH

    elseif coordSystem == "ENU"
        % ENU: instrument compass already rotated to East-North-Up.
        % U = East, V = North, W = Up (no z-flip needed).
        % Convert to MOP convention: +x WEST = -East, +y NORTH = North.
        U_true = -U;          % +x WEST
        V_true =  V;          % +y NORTH
        % W already +z UP in ENU — no flip.
        theta_mag = NaN;      % heading not used for ENU rotation
        fprintf('  ENU coordinates — no heading rotation needed\n');

    else
        error('PUV_raw_process:unknownCoordSys', ...
            'Unknown coordinate system: %s', coordSystem);
    end

    %% ========== BUILD OUTPUT STRUCT ==========
    % +x WEST, +y NORTH, +z UP  (left-handed, matches MOP convention)

    PUV.time           = full_date(:);     % column datetime vector (UTC)
    PUV.fs             = fs;
    PUV.P              = P;                % pressure, dBar
    PUV.BuoyCoord.U    = U_true;           % +x WEST
    PUV.BuoyCoord.V    = V_true;           % +y NORTH
    PUV.BuoyCoord.W    = W;               % +z UP
    PUV.InstrCoord.U   = U;               % instrument XYZ frame
    PUV.InstrCoord.V   = V;
    PUV.T              = T;               % temperature, deg C (NaN where thermistor failed)

    % --- Per-channel provenance (channel decoupling, 2026-07-09). These travel with the
    % data so that reconstructed or rescaled samples can never be mistaken for clean ones.
    PUV.qc.valid_vel           = valid_vel;            % Doppler diagnostics only
    PUV.qc.valid_p             = valid_p;              % pressure only
    PUV.qc.valid_tilt          = valid_tilt;           % tilt only
    PUV.qc.valid_T             = valid_T;              % thermistor only
    PUV.qc.valid_joint         = valid_joint;          % the OLD row-level mask, verbatim
    PUV.qc.vel_c_factor        = vel_c_factor;         % single; exactly 1 on healthy data
    PUV.qc.vel_c_corrected     = vel_c_corrected;      % logical
    PUV.qc.vel_rotation_static = vel_rotation_static;  % logical
    PUV.qc.Tref                = Tref;
    PUV.qc.opts                = qcOpts;

    PUV.LATLON         = instr.latlon;
    PUV.rotation.sensor = theta_mag;      % actual heading used (may be auto-computed)
    PUV.rotation.mag    = magDeclination;
    PUV.doffp           = instr.doffp;     % pressure sensor height above bed (m)
    PUV.label            = instr.label;
    PUV.deploymentName   = cfg.name;

    fprintf('  PUV struct built: %d samples, %.1f days\n', ...
        length(PUV.time), days(PUV.time(end) - PUV.time(1)));
end


% ======================================================================
function fmt = select_raw_format(instrDir, instr)
% Decide whether to ingest the Nortek ASCII export or the raw .VEC binary.
%
% Auto-detection prefers ASCII when a .dat file is present, because that is the
% path the existing 33 instrument-deployments were processed through. That
% preference is a trap for deployments whose export was interrupted, so when
% both forms exist this warns rather than silently ingesting the shorter one.
    if isfield(instr, 'rawFormat') && ~isempty(instr.rawFormat)
        fmt = upper(char(instr.rawFormat));
        if ~ismember(fmt, {'ASCII', 'VEC'})
            error('PUV_raw_process:badRawFormat', ...
                'instr.rawFormat must be ''ASCII'' or ''VEC'', got ''%s''.', fmt);
        end
        return
    end

    datFiles = list_raw_files(instrDir, instr, {'.dat'});
    vecFiles = list_raw_files(instrDir, instr, {'.VEC', '.vec', '.049'});

    if ~isempty(datFiles)
        fmt = 'ASCII';
        if ~isempty(vecFiles)
            warning('PUV_raw_process:asciiPreferredOverVEC', ...
                ['Both ASCII (%d file(s)) and raw binary (%d file(s)) are present in\n' ...
                 '%s\nDefaulting to ASCII. If the export was interrupted, the ASCII\n' ...
                 'covers only part of the record — set instr.rawFormat = ''VEC'' to\n' ...
                 'decode the full deployment.'], ...
                numel(datFiles), numel(vecFiles), instrDir);
        end
    elseif ~isempty(vecFiles)
        fmt = 'VEC';
    else
        error('PUV_raw_process:noFiles', ...
            'No .dat or .VEC/.vec/.049 files%s found in %s', ...
            prefix_note(instr), instrDir);
    end
end

% ======================================================================
function files = list_raw_files(instrDir, instr, exts)
% Raw files in instrDir matching the instrument prefix, as a cellstr.
%
% macOS and SMB mounts are case-insensitive, so dir('*.VEC') can also return
% *.vec entries; unique() collapses those to one entry per physical file.
    if isfield(instr, 'filePrefix') && ~isempty(instr.filePrefix)
        pat = [instr.filePrefix '*'];
    else
        pat = '*';
    end
    names = {};
    for e = 1:numel(exts)
        d = dir(fullfile(instrDir, [pat exts{e}]));
        if ~isempty(d)
            d = d(~[d.isdir]);
            names = [names, {d.name}];   %#ok<AGROW>
        end
    end
    names = unique(names);
    if isempty(names)
        files = {};
    else
        files = cellfun(@(n) fullfile(instrDir, n), names, 'UniformOutput', false);
    end
end

% ======================================================================
function s = prefix_note(instr)
    if isfield(instr, 'filePrefix') && ~isempty(instr.filePrefix)
        s = sprintf(' matching prefix "%s"', instr.filePrefix);
    else
        s = '';
    end
end

% ======================================================================
function [DAT_bursts, SEN_bursts, date_start, date_end, fs, coordSystem] = ...
        load_from_VEC(instrDir, instr)
% Decode the raw Nortek recorder binary into the same matrices the ASCII path
% produces. Sampling rate and coordinate system come from the binary's User
% Configuration record, so this works on deployments whose .hdr is 0 bytes.
    vecFiles = list_raw_files(instrDir, instr, {'.VEC', '.vec', '.049'});
    if isempty(vecFiles)
        error('PUV_raw_process:noFiles', ...
            'No .VEC/.vec/.049 files%s found in %s', ...
            prefix_note(instr), instrDir);
    end
    fprintf('  Found %d raw binary file(s)\n', numel(vecFiles));

    % One burst per recorder file, matching how the ASCII path treats the _N
    % split files. Concatenating them instead would expose the file seams to
    % the battery-cutoff detector below, which truncates the record at the
    % first gap over a second — IB-S02 loses a second across its _4/_5 seam
    % and would lose four months of good data to it.
    % Verbose off: these deployments have hundreds of hourly files and the
    % per-file line is just noise once the decoder is trusted.
    [DAT_bursts, SEN_bursts, meta] = read_VEC(vecFiles, 'Split', true, 'Verbose', false);

    keep = ~cellfun(@isempty, SEN_bursts);
    if ~any(keep)
        error('PUV_raw_process:noSystemRecords', ...
            ['Decoded no system records from %s, so the record cannot be ' ...
             'timestamped.'], instrDir);
    end
    if ~all(keep)
        % Empty trailing files are normal: the recorder keeps opening an hourly
        % file after the instrument has stopped sampling, so a deployment that
        % ended early leaves a tail of zero-record files.
        warning('PUV_raw_process:emptyVECFile', ...
            'Dropping %d raw file(s) with no decodable system records.', sum(~keep));
        DAT_bursts = DAT_bursts(keep);
        SEN_bursts = SEN_bursts(keep);
        % meta.files must stay aligned with the bursts — the filename-based
        % clock recovery pairs them off by index.
        meta.files = meta.files(keep);
    end

    % Order bursts chronologically by their first clock timestamp. read_VEC
    % returns them in filename order, which is NOT chronological when the raw
    % files are named MMDDHHMM and the deployment crosses a year boundary: the
    % January files sort before the previous November, scrambling the record
    % (Cardiff 2015-2016 is the case). The instrument clock is monotonic even
    % from a wrong epoch, so sorting on it recovers the true order regardless of
    % filename or of the clock-epoch recovery applied next.
    nB0 = numel(SEN_bursts);
    firstT = NaT(nB0, 1);
    for ii = 1:nB0
        S = SEN_bursts{ii};
        firstT(ii) = datetime(S(1,3), S(1,1), S(1,2), S(1,4), S(1,5), S(1,6));
    end
    if any(diff(firstT) < 0)
        [~, chrono] = sort(firstT);
        DAT_bursts = DAT_bursts(chrono);
        SEN_bursts = SEN_bursts(chrono);
        meta.files = meta.files(chrono);
        fprintf('  Reordered %d bursts into chronological order (filename order was not)\n', nB0);
    end

    fs = meta.fs;
    if isempty(fs) || isnan(fs) || fs <= 0
        error('PUV_raw_process:fsNotFound', ...
            'Sampling rate did not decode from the User Configuration in %s', ...
            vecFiles{1});
    end

    % Optional decimation to a lower rate (instr.decimateTo, Hz). A few
    % deployments sample at 8 Hz for turbulence/dye work; the wave-climate
    % catalog is 2 Hz, and the downstream merge and L2 segmentation assume 2 Hz.
    % Decimating here (anti-aliased for the continuous channels, block-worst for
    % the QC channels) brings such a record into the standard 2 Hz catalog with
    % the full wave band intact — the >Nyquist/2 content it drops is turbulence,
    % not waves. The raw high-rate files remain for a separate dye analysis.
    if isfield(instr, 'decimateTo') && ~isempty(instr.decimateTo) && instr.decimateTo < fs
        factor = fs / instr.decimateTo;
        if abs(factor - round(factor)) > 1e-6
            error('PUV_raw_process:badDecimate', ...
                'decimateTo=%g does not divide the measured fs=%g evenly.', ...
                instr.decimateTo, fs);
        end
        factor = round(factor);
        for ii = 1:numel(DAT_bursts)
            DAT_bursts{ii} = decimate_DAT(DAT_bursts{ii}, factor);
        end
        fprintf('  Decimated %g Hz -> %g Hz (factor %d, anti-aliased velocity/pressure)\n', ...
            fs, instr.decimateTo, factor);
        fs = instr.decimateTo;
    end

    coordSystem = string(meta.coordSystem);

    % Some pre-2019 instruments recorded with the real-time clock set to a
    % nonsense epoch (2000-01-01, 2002-01-01). The clock still RAN correctly, and
    % the recorder named each hourly file for the true wall-clock hour, so the
    % epoch is recoverable — see vec_clock_from_filenames. Opt in per instrument
    % with clockSource = 'filename' plus deployYear.
    if isfield(instr, 'clockSource') && strcmpi(instr.clockSource, 'filename')
        if ~isfield(instr, 'deployYear') || isempty(instr.deployYear)
            error('PUV_raw_process:noDeployYear', ...
                ['instr.clockSource = ''filename'' needs instr.deployYear — the ' ...
                 'MMDDHHMM filenames carry no year.']);
        end
        [offSec, cdiag] = vec_clock_from_filenames(meta.files, SEN_bursts, ...
            struct('startYear', instr.deployYear));
        fprintf(['  Clock recovered from filenames: offset %.3f days, ' ...
                 'residual spread %.0f s, drift %+.0f s over %d files\n'], ...
            offSec/86400, cdiag.maxDevSec, cdiag.driftSec, cdiag.nFiles);
        fprintf('  Recovered span: %s to %s\n', ...
            string(cdiag.firstTime), string(cdiag.lastTime));

        % The filename clock is whatever the recorder was SET to, which for this
        % archive was Pacific local time, not UTC. vec_clock_from_filenames says
        % so in its header and asks for the L3 tidal check; that check was run
        % 2026-07-27 and every clockSource='filename' record came back 7-8 h out
        % of phase against the NOAA-referenced prediction (R ~ -0.55 at lag 0,
        % 0.93-0.99 at the right lag). instr.clockOffsetHours is ADDED to bring
        % the record to UTC.
        %
        % It is a fixed number per deployment, NOT a timezone conversion: the
        % instruments were set to PST and left there, so four records sitting
        % entirely in daylight time (TOR15D, TOR16D, TOR17D, COR17D) still
        % measure a lag of 8 h, not 7. A tz-aware conversion would over-correct
        % every spring deployment by an hour. The 2014-15 season is the
        % exception at 7 h, stable across thirds of each record.
        %
        % SIGN: the measured lag is NEGATIVE (-8) and the applied offset is
        % POSITIVE (+8). For data D(t)=W(t+d) against a correct prediction
        % P(t)=W(t), rolling P by L matches at L=-d, so a lag of -8 means the
        % timestamps are slow and 8 h must be ADDED. Applying -8 instead makes
        % the record twice as wrong AND still produces a confident peak in a lag
        % scan, so the scan alone cannot tell you which way to go. Derive it.
        if isfield(instr, 'clockOffsetHours') && ~isempty(instr.clockOffsetHours) ...
                && isfinite(instr.clockOffsetHours) && instr.clockOffsetHours ~= 0
            tzSec  = instr.clockOffsetHours * 3600;
            offSec = offSec + tzSec;
            fprintf(['  Clock offset applied: %+g h (local -> UTC); ' ...
                     'span becomes %s to %s\n'], ...
                instr.clockOffsetHours, ...
                string(cdiag.firstTime + hours(instr.clockOffsetHours)), ...
                string(cdiag.lastTime  + hours(instr.clockOffsetHours)));
        else
            warning('PUV_raw_process:noClockOffset', ...
                ['clockSource=''filename'' with no instr.clockOffsetHours. The ' ...
                 'filename clock records LOCAL time for this archive; without an ' ...
                 'offset the record will be 7-8 h fast. Verify with the L3 tidal ' ...
                 'lag check before trusting absolute timing.']);
        end
        SEN_bursts = shift_SEN_time(SEN_bursts, offSec);
    end

    % A few instruments have a wrong clock epoch AND raw files named with a
    % sequence counter rather than the wall-clock hour (TOR20A), so the filename
    % recovery cannot be used. The clock still runs correctly, so a single fixed
    % offset from a known true start time recovers the whole record. Opt in with
    % clockSource = 'fixed' and instr.deployStart (a datetime of the first
    % sample). Anchor it from the deployment log, then confirm/refine against the
    % MOP reference — the absolute epoch is only as good as deployStart, while
    % the sample spacing is exact.
    if isfield(instr, 'clockSource') && strcmpi(instr.clockSource, 'fixed')
        if ~isfield(instr, 'deployStart') || isempty(instr.deployStart)
            error('PUV_raw_process:noDeployStart', ...
                'instr.clockSource = ''fixed'' needs instr.deployStart (a datetime).');
        end
        S1 = SEN_bursts{1};   % chronological first burst after the sort above
        firstRTC = datetime(S1(1,3), S1(1,1), S1(1,2), S1(1,4), S1(1,5), S1(1,6));
        offSec = seconds(instr.deployStart - firstRTC);
        fprintf('  Clock set from fixed start: RTC %s -> deployStart %s (offset %.2f days)\n', ...
            string(firstRTC), string(instr.deployStart), offSec/86400);
        SEN_bursts = shift_SEN_time(SEN_bursts, offSec);
    end

    % SEN columns are [month day year hour minute second ...]; the caller wants
    % [year month day hour minute second], one row per burst.
    nB = numel(SEN_bursts);
    date_start = zeros(nB, 6);
    date_end   = zeros(nB, 6);
    for ii = 1:nB
        S = SEN_bursts{ii};
        date_start(ii, :) = [S(1,   3) S(1,   1:2) S(1,   4:6)];
        date_end(ii, :)   = [S(end, 3) S(end, 1:2) S(end, 4:6)];
    end

    nSamp = sum(cellfun(@(x) size(x, 1), DAT_bursts));
    fprintf('  Serial %s (head %s), firmware %s\n', ...
        meta.serialNo, meta.headSerialNo, meta.fwVersion);
    fprintf('  Sampling rate: %g Hz\n', fs);
    fprintf('  Coordinate system: %s\n', coordSystem);
    fprintf('  Decoded %d velocity samples in %d burst(s), %s to %s\n', nSamp, nB, ...
        string(datetime(date_start(1,   :), 'InputFormat', 'YYYYMMDDHHmmSS')), ...
        string(datetime(date_end(end, :),   'InputFormat', 'YYYYMMDDHHmmSS')));
end

% ======================================================================
function D = decimate_DAT(D, factor)
% Downsample one burst's DAT matrix by an integer factor.
%
% The continuous channels (velocity, pressure, analogue in) are anti-alias
% decimated with a linear-phase FIR filter so the wave band is preserved without
% phase distortion. The per-sample quality channels are handled to keep their
% meaning across the decimation: correlation takes the block MINIMUM (the
% decimated sample inherits the worst correlation in its window, so a bad stretch
% still gates QC), amplitude/SNR are subsampled. Columns are the ASCII .dat
% layout: 3:5 vel, 6:8 amp, 9:11 snr, 12:14 corr, 15 pressure, 16:17 ain.
    if isempty(D), return; end
    n = size(D, 1);
    nOut = floor(n / factor);
    if nOut < 2, D = D(1:0, :); return; end
    keep = 1 : nOut*factor;

    out = zeros(nOut, size(D, 2));
    % continuous channels: anti-aliased decimation
    for c = [3 4 5 15 16 17]
        out(:, c) = decimate(D(keep, c), factor, 'fir');
    end
    % correlation: block minimum (conservative QC)
    for c = 12:14
        blk = reshape(D(keep, c), factor, nOut);
        out(:, c) = min(blk, [], 1)';
    end
    % amplitude / SNR: subsample
    for c = [6 7 8 9 10 11]
        out(:, c) = D(factor:factor:nOut*factor, c);
    end
    % bookkeeping columns
    out(:, 1) = D(1, 1);            % burst number (constant within a burst)
    out(:, 2) = (1:nOut)';          % ensemble index within the decimated burst
    out(:, 18) = 0;                 % checksum flag
    D = out;
end

% ======================================================================
function SEN_bursts = shift_SEN_time(SEN_bursts, offsetSec)
% Add a constant offset to the clock columns of every SEN burst.
% SEN columns 1:6 are [month day year hour minute second].
    for ii = 1:numel(SEN_bursts)
        S = SEN_bursts{ii};
        if isempty(S), continue; end
        t = datetime(S(:,3), S(:,1), S(:,2), S(:,4), S(:,5), S(:,6)) + seconds(offsetSec);
        [y, mo, d] = ymd(t);
        [h, mi, s] = hms(t);
        S(:, 1:6) = [mo d y h mi round(s)];
        SEN_bursts{ii} = S;
    end
end

% ======================================================================
function [DAT_bursts, SEN_bursts, date_start, date_end, fs, coordSystem] = ...
        load_from_ASCII(instrDir, instr)
% Ingest the Nortek ExploreV ASCII export (.dat/.sen/.hdr).
%
% Moved verbatim out of the body of PUV_raw_process when the .VEC path was
% added; behaviour is unchanged.

    % Discover all .dat files (one per burst) and extract the common prefix.
    % If instr.filePrefix is specified, restrict to .dat files matching it —
    % this is necessary when one folder holds files from multiple deployments
    % with different prefixes (e.g., Catalina_2021 has both CATISL02.dat and
    % CATISL03_*.dat from two separate deployments).
    if isfield(instr, 'filePrefix') && ~isempty(instr.filePrefix)
        datFiles = dir(fullfile(instrDir, [instr.filePrefix '*.dat']));
        if isempty(datFiles)
            error('PUV_raw_process:noFiles', ...
                'No .dat files matching prefix "%s" found in %s', ...
                instr.filePrefix, instrDir);
        end
    else
        datFiles = dir(fullfile(instrDir, '*.dat'));
        if isempty(datFiles)
            error('PUV_raw_process:noFiles', ...
                'No .dat files found in %s', instrDir);
        end
    end

    filenames = {datFiles.name};
    nBursts   = numel(filenames);

    % The common prefix is the part of the filename that is identical across
    % all burst files (e.g. "7M_58602_MOP586_"). We find the first column
    % where any character differs across files.
    if nBursts == 1
        % Single burst file: strip the trailing '.dat' to get the full name.
        % The file has no _N burst suffix, so we use the full name as prefix
        % and set burstID to '' in the loading loop.
        depstr = filenames{1}(1:end-4);  % remove '.dat'
    else
        nameChars = char(filenames(:));
        firstDiff = find(any(diff(nameChars, 1, 1), 1), 1, 'first');
        depstr    = filenames{1}(1:firstDiff-1);
    end

    fprintf('  Found %d burst files, prefix: %s\n', nBursts, depstr);

    %% ========== LOAD ALL BURSTS ==========
    % NOTE: If rawDataRoot is a network mount (/Volumes/group/...), reading
    % large ASCII files over the network will be slow regardless of parser.
    % For fastest processing, consider copying raw files to a local directory
    % and pointing rawDataRoot there. On a local disk, each burst should load
    % in ~5-15 seconds; over the network, expect 1-5 min per burst.
    SEN_bursts = cell(1, nBursts);
    DAT_bursts = cell(1, nBursts);
    date_start = zeros(nBursts, 6);   % [YYYY MM DD HH mm SS]
    date_end   = zeros(nBursts, 6);

    tLoad = tic;
    for ii = 1:nBursts
        if nBursts == 1
            burstID = '';  % single-burst file has no _N suffix
        else
            burstID = num2str(ii);
        end
        senfile = fullfile(instrDir, [depstr burstID '.sen']);
        datfile = fullfile(instrDir, [depstr burstID '.dat']);

        % Handle prefix mismatch between .dat and .sen files.
        % Some deployments use underscore in .dat but hyphen in .sen
        % (e.g., 6M_51102_1.dat vs 6M-51102_1.sen), or the common
        % prefix across .dat files is too short. Search for matching
        % .sen and .dat files by burst number pattern if direct path fails.
        if ~isfile(senfile)
            % Try swapping _ <-> - in prefix
            altPrefix = strrep(depstr, '_', '-');
            altSen = fullfile(instrDir, [altPrefix burstID '.sen']);
            if isfile(altSen)
                senfile = altSen;
            else
                altPrefix = strrep(depstr, '-', '_');
                altSen = fullfile(instrDir, [altPrefix burstID '.sen']);
                if isfile(altSen)
                    senfile = altSen;
                else
                    % Fallback: find any .sen file ending with burstID.sen
                    senCandidates = dir(fullfile(instrDir, ['*' burstID '.sen']));
                    if ~isempty(senCandidates)
                        senfile = fullfile(instrDir, senCandidates(1).name);
                    end
                end
            end
        end
        if ~isfile(datfile)
            % Try swapping _ <-> - in prefix
            altPrefix = strrep(depstr, '_', '-');
            altDat = fullfile(instrDir, [altPrefix burstID '.dat']);
            if isfile(altDat)
                datfile = altDat;
            else
                % Fallback: find any .dat file ending with burstID.dat
                datCandidates = dir(fullfile(instrDir, ['*' burstID '.dat']));
                if ~isempty(datCandidates)
                    datfile = fullfile(instrDir, datCandidates(1).name);
                end
            end
        end

        fprintf('  Loading burst %d/%d: .sen ...', ii, nBursts);
        t1 = tic;
        fid = fopen(senfile, 'r');
        raw = textscan(fid, repmat('%f', 1, 16), 'CollectOutput', true);
        fclose(fid);
        SEN_bursts{ii} = raw{1};
        fprintf(' %.1fs  .dat ...', toc(t1));

        t1 = tic;
        fid = fopen(datfile, 'r');
        raw = textscan(fid, repmat('%f', 1, 18), 'CollectOutput', true);
        fclose(fid);
        DAT_bursts{ii} = raw{1};
        fprintf(' %.1fs\n', toc(t1));

        % SEN columns: 1=Month, 2=Day, 3=Year, 4=Hour, 5=Minute, 6=Second
        % Reorder to [YYYY MM DD HH mm SS] for datetime construction
        date_start(ii,:) = [SEN_bursts{ii}(1,3)   SEN_bursts{ii}(1,1:2)   SEN_bursts{ii}(1,4:6)];
        date_end(ii,:)   = [SEN_bursts{ii}(end,3) SEN_bursts{ii}(end,1:2) SEN_bursts{ii}(end,4:6)];
    end
    fprintf('  All bursts loaded in %.1f min\n', toc(tLoad)/60);

    %% ========== PARSE SAMPLING RATE AND COORDINATE SYSTEM FROM HDR ==========
    if nBursts == 1
        hdrFile = fullfile(instrDir, [depstr '.hdr']);
    else
        hdrFile = fullfile(instrDir, [depstr '1.hdr']);
    end

    % Handle prefix mismatch (same logic as .sen/.dat)
    if ~isfile(hdrFile)
        altPrefix = strrep(depstr, '_', '-');
        if nBursts == 1
            altHdr = fullfile(instrDir, [altPrefix '.hdr']);
        else
            altHdr = fullfile(instrDir, [altPrefix '1.hdr']);
        end
        if isfile(altHdr)
            hdrFile = altHdr;
        else
            % Fallback: find any .hdr file
            hdrCandidates = dir(fullfile(instrDir, '*.hdr'));
            if ~isempty(hdrCandidates)
                hdrFile = fullfile(instrDir, hdrCandidates(1).name);
            end
        end
    end

    fid = fopen(hdrFile, 'r');
    if fid == -1
        error('PUV_raw_process:hdrNotFound', ...
            'Cannot open header file: %s', hdrFile);
    end

    % Read sampling rate from line 12
    frewind(fid);
    C_fs = split(string(textscan(fid, '%s', 1, 'delimiter', '\n', 'headerlines', 11)));
    fsIdx = find(C_fs == "Sampling", 1);
    if isempty(fsIdx)
        fclose(fid);
        error('PUV_raw_process:fsNotFound', ...
            'Could not find "Sampling rate" on line 12 of %s', hdrFile);
    end
    fs = double(C_fs(3));
    fprintf('  Sampling rate: %d Hz\n', fs);

    % Read coordinate system from line 32
    frewind(fid);
    C_coord = split(string(textscan(fid, '%s', 1, 'delimiter', '\n', 'headerlines', 31)));
    fclose(fid);

    coordIdx = find(C_coord == "Coordinate", 1);
    if isempty(coordIdx)
        error('PUV_raw_process:coordNotFound', ...
            'Could not find "Coordinate system" on line 32 of %s', hdrFile);
    end
    coordSystem = C_coord(3);
    fprintf('  Coordinate system: %s\n', coordSystem);
end
