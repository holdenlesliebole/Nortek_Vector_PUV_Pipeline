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
    % If the time gap between consecutive SEN samples exceeds 1 second,
    % the instrument was intermittently recording (battery depletion).
    % Truncate data at the first gap.
    cutoff = [];
    for ii = 1:nBursts
        SENii = SEN_bursts{ii};
        date_temp = datetime([SENii(:,3) SENii(:,1:2) SENii(:,4:6)], ...
                             'InputFormat', 'YYYYMMDDHHmmSS');
        gaps = find(diff(date_temp) > seconds(1));
        if ~isempty(gaps)
            cutoff.burst = ii;
            cutoff.id    = gaps(1);
            warning('PUV_raw_process:cutoffDetected', ...
                'Battery cutoff detected in burst %d at sample %d.', ii, gaps(1));
            break
        end
    end

    % Trim data at the cutoff point
    if ~isempty(cutoff)
        ii = cutoff.burst;
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

            % SEN is at 1 Hz — duplicate each sample to fill 2 Hz slots
            senEnd = min(iEnd+1, length(full_date));
            SEN(iStart   : 2 : senEnd, :) = SENii(1:min(size(SENii,1), numel(iStart:2:senEnd)), :);
            SEN(iStart+1 : 2 : iEnd,   :) = SENii(1:min(size(SENii,1)-1, numel(iStart+1:2:iEnd)), :);
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
            SEN(iStart : iStart+nFill-1, :) = SENii(1:min(nFill, size(SENii,1)), :);
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

    tiltStdMax = 2;    % degrees — variability threshold
    tiltAbsMax = 30;   % degrees — absolute tilt beyond which data is unreliable
    tiltWindow = 120;  % samples for rolling std (60 sec at 2 Hz)

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

    % --- Apply QC to actual DAT/SEN arrays ---
    bad = bad_tilt_var | bad_tilt_abs;
    DAT(bad,:) = NaN; SEN(bad,:) = NaN;

    % Apply the same reference-pMed pressure QC to DAT (uses pMed = pMed_ref
    % computed above from the healthy first-burst window).
    bad = DAT(:,15) < pMed/2;
    DAT(bad,:) = NaN; SEN(bad,:) = NaN;

    bad = DAT(:,15) > pMed*2;
    DAT(bad,:) = NaN; SEN(bad,:) = NaN;

    %% ========== QC: CORRELATION < 70% ==========
    % Nortek recommends discarding samples where the minimum beam
    % correlation drops below 70%.
    bad_corr = min(DAT(:, 12:14), [], 2) < 70;
    DAT(bad_corr, :) = NaN;
    SEN(bad_corr, :) = NaN;

    %% ========== TRIM LEADING NaNs ==========
    % Start the timeseries at the first valid pressure sample so we
    % don't carry a block of NaN from before the instrument was submerged.
    validIdx = find(~isnan(DAT(:,15)));
    if isempty(validIdx)
        error('PUV_raw_process:noValidData', ...
            'No valid pressure data remains after QC for %s.', instr.label);
    end
    firstGood = validIdx(1);
    DAT(1:firstGood-1, :) = [];
    SEN(1:firstGood-1, :) = [];
    full_date(1:firstGood-1) = [];

    %% ========== EXTRACT VELOCITY, PRESSURE, TEMPERATURE ==========
    U = DAT(:,3);   % East / X velocity (m/s)
    V = DAT(:,4);   % North / Y velocity (m/s)
    W = DAT(:,5);   % Up / Z velocity (m/s)
    T = SEN(:,14);  % temperature (deg C)
    P = DAT(:,15);  % pressure (dBar)

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
    PUV.T              = T;               % temperature, deg C
    PUV.LATLON         = instr.latlon;
    PUV.rotation.sensor = theta_mag;      % actual heading used (may be auto-computed)
    PUV.rotation.mag    = magDeclination;
    PUV.doffp           = instr.doffp;     % pressure sensor height above bed (m)
    PUV.label            = instr.label;
    PUV.deploymentName   = cfg.name;

    fprintf('  PUV struct built: %d samples, %.1f days\n', ...
        length(PUV.time), days(PUV.time(end) - PUV.time(1)));
end
