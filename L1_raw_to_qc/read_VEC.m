function [DAT, SEN, meta] = read_VEC(vecFiles, varargin)
% READ_VEC  Decode raw Nortek Vector binary (.VEC/.vec/.049) to DAT/SEN matrices.
%
%   [DAT, SEN, meta] = read_VEC(vecFiles)
%   [DAT, SEN, meta] = read_VEC(vecFiles, 'Verbose', false)
%
%   Reads the Nortek Vector raw binary recorder format directly, producing the
%   same two matrices that PUV_raw_process otherwise obtains by textscan-ing the
%   ASCII .dat/.sen files exported by Nortek ExploreV. This removes the
%   Windows-only ExploreV step from the ingest path entirely.
%
%   Motivation: much of the pre-2023 archive in
%   /Volumes/group/PUV_data/Vector/recopied/ exists ONLY as .VEC binary, and
%   where an ASCII export does exist it is often partial (e.g. TORREY02_1.dat
%   covers 5.1 days of a 174-day deployment and terminates mid-line). Several
%   of those deployments also ship 0-byte .hdr/.vhd files, so sampling rate and
%   coordinate system are not recoverable from ASCII at all — but they ARE
%   recorded in the binary's User Configuration record, which this function
%   reads.
%
%   INPUTS
%     vecFiles - char path to one .VEC file, or cellstr of paths. Multi-file
%                deployments are split by the recorder at 100 MiB with a _N
%                suffix; pass them all and they are concatenated in numeric
%                order (NOT lexical, so _10 follows _9).
%
%   OPTIONS (name/value)
%     'Verbose'  - print per-file progress (default true)
%     'Split'    - return one cell per input file instead of concatenating
%                  (default false). Use this when the caller treats each
%                  recorder file as its own burst; see the note below.
%
%   BURSTS. The recorder splits at 100 MiB mid-sampling, and the resulting
%   files are not always perfectly abutting: a seam can lose a second (IB-S02
%   steps 2020-01-21 13:00:10 -> 13:00:12 across the _4/_5 boundary). The ASCII
%   path treats each _N file as a separate burst, so L1's battery-cutoff
%   detector — which truncates the record at the first gap longer than one
%   second — never tested those seams. Concatenating the files here would
%   expose them and silently truncate good data, so callers should pass
%   'Split', true to keep one burst per file and leave seam handling to the
%   burst-merge logic.
%
%   OUTPUTS  (cell arrays of the below, one per file, when 'Split' is true)
%     DAT  - N x 18, matching the ASCII .dat column layout:
%              1 burst      2 ens        3 u (m/s)    4 v (m/s)    5 w (m/s)
%              6:8 amp1-3   9:11 snr1-3  12:14 corr1-3
%              15 pressure (dBar)        16 ain1      17 ain2      18 checksum flag
%     SEN  - M x 16, matching the ASCII .sen column layout:
%              1 month  2 day  3 year  4 hour  5 minute  6 second
%              7 error  8 status  9 battery (V)  10 sound speed (m/s)
%              11 heading  12 pitch  13 roll (deg)  14 temperature (degC)
%              15 ain1  16 ain2
%            System records are written at 1 Hz, so M ~ N/fs.
%     meta - struct: serialNo, headSerialNo, fwVersion, coordSystem
%            ('ENU'|'XYZ'|'BEAM'), fs (Hz), nBeams, deployName, clockDeploy
%            (datetime), headFreq_kHz, velScale, nFiles, files, nBadChecksum.
%
%   RECORD FORMAT (Nortek System Integrator Manual). Every record is
%   sync 0xA5, id, then a 16-bit little-endian size in WORDS. Records used:
%     0xA5 0x05  Hardware Configuration     48 bytes
%     0xA5 0x04  Head Configuration        224 bytes
%     0xA5 0x00  User Configuration        512 bytes
%     0xA5 0x12  Velocity Data Header       42 bytes  (per burst; noise floor)
%     0xA5 0x11  Vector System Data         28 bytes  (1 Hz attitude -> SEN)
%     0xA5 0x10  Vector Velocity Data       24 bytes  (fs Hz -> DAT)
%   0xA5 also occurs inside data, so every candidate record is confirmed by its
%   Nortek checksum (0xB58C + sum of all preceding 16-bit words) before use.
%
%   VERIFICATION: test_read_VEC.m checks this decoder against the TORREY02
%   ASCII export over the 5.1-day window where both exist.
%
% Author: Holden Leslie-Bole, 2026

    p = inputParser;
    addParameter(p, 'Verbose', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'Split',  false, @(x) islogical(x) || isnumeric(x));
    parse(p, varargin{:});
    verbose = logical(p.Results.Verbose);
    split   = logical(p.Results.Split);

    if ischar(vecFiles) || isstring(vecFiles)
        vecFiles = cellstr(vecFiles);
    end
    vecFiles = sort_split_files(vecFiles);
    nFiles   = numel(vecFiles);

    % Record ids and their byte lengths
    ID_HW = 5;    LEN_HW = 48;
    ID_HD = 4;    LEN_HD = 224;
    ID_US = 0;    LEN_US = 512;
    ID_VH = 18;   LEN_VH = 42;    % 0x12 velocity data header
    ID_SY = 17;   LEN_SY = 28;    % 0x11 system data
    ID_VD = 16;   LEN_VD = 24;    % 0x10 velocity data

    datCell = cell(1, nFiles);
    senCell = cell(1, nFiles);
    meta    = struct();
    nBadCS  = 0;
    burstOffset = 0;   % running burst counter across split files

    for ff = 1:nFiles
        fname = vecFiles{ff};
        fid = fopen(fname, 'r');
        if fid == -1
            error('read_VEC:cannotOpen', 'Cannot open %s', fname);
        end
        b = fread(fid, inf, '*uint8');
        fclose(fid);

        % Some archived files (the Cardiff .049 set) are missing the leading
        % 0xA5 sync byte of the first record. Restore it so the hardware-config
        % record parses; interior records are found by search regardless.
        if numel(b) > 3 && b(1) ~= 165 && b(1) == ID_HW && b(2) == 24 && b(3) == 0
            b = [uint8(165); b];
        end

        if verbose
            [~, shortName, ext] = fileparts(fname);
            fprintf('    read_VEC: %s%s (%.0f MB)', shortName, ext, numel(b)/1e6);
        end

        % ---- configuration records (first file only) ----
        if ff == 1
            meta = parse_config(b, ID_HW, LEN_HW, ID_HD, LEN_HD, ID_US, LEN_US);
        end

        % ---- velocity data header records: burst starts + noise floor ----
        pVH = find_records(b, ID_VH, LEN_VH);
        noiseVH = zeros(numel(pVH), 3);
        for c = 1:3
            noiseVH(:, c) = double(b(pVH + 11 + c));   % offsets 12,13,14
        end

        % ---- system data records -> SEN ----
        pSY = find_records(b, ID_SY, LEN_SY);
        senCell{ff} = build_SEN(b, pSY);

        % ---- velocity data records -> DAT ----
        pVD = find_records(b, ID_VD, LEN_VD);
        [datCell{ff}, nb] = build_DAT(b, pVD, pVH, noiseVH, burstOffset);
        burstOffset = burstOffset + nb;

        nBadCS = nBadCS + count_bad_sync(b, ID_VD, numel(pVD));

        if verbose
            fprintf('  ->  %d vel, %d sys, %d bursts\n', ...
                numel(pVD), numel(pSY), nb);
        end
        clear b
    end

    if split
        DAT = datCell;
        SEN = senCell;
        nDatRows = sum(cellfun(@(x) size(x, 1), datCell));
        nSenRows = sum(cellfun(@(x) size(x, 1), senCell));
    else
        DAT = vertcat(datCell{:});
        SEN = vertcat(senCell{:});
        clear datCell senCell
        nDatRows = size(DAT, 1);
        nSenRows = size(SEN, 1);
    end

    meta.nFiles       = nFiles;
    meta.files        = vecFiles;
    meta.nBadChecksum = nBadCS;

    if nDatRows == 0
        error('read_VEC:noData', ...
            'No valid velocity records decoded from %s', vecFiles{1});
    end

    % Cross-check the decoded sample ratio against the configured rate. A
    % mismatch means dropped records or a wrong fs, both of which would
    % silently corrupt every downstream timestamp.
    if isfield(meta, 'fs') && ~isempty(meta.fs) && ~isnan(meta.fs) && nSenRows > 0
        ratio = nDatRows / nSenRows;
        if abs(ratio - meta.fs) > 0.05 * meta.fs
            warning('read_VEC:rateMismatch', ...
                ['Decoded %d velocity / %d system records = %.3f samples per second, ' ...
                 'but the User Configuration reports fs = %g Hz. Records may be ' ...
                 'missing or the deployment changed rate mid-record.'], ...
                nDatRows, nSenRows, ratio, meta.fs);
        end
    end
end

% ======================================================================
function files = sort_split_files(files)
% Order split recorder files numerically by their trailing _N index so that
% _10 follows _9 rather than _1 (which lexical sort would do).
    n = numel(files);
    idx = zeros(n, 1);
    for ii = 1:n
        [~, base] = fileparts(files{ii});
        tok = regexp(base, '_(\d+)$', 'tokens', 'once');
        if isempty(tok)
            idx(ii) = 0;      % unsuffixed base file sorts first
        else
            idx(ii) = str2double(tok{1});
        end
    end
    [~, order] = sort(idx);
    files = files(order);
end

% ======================================================================
function p = find_records(b, id, recLen)
% Return start indices of all checksum-valid records of the given id.
%
% 0xA5 occurs freely inside velocity data, so a sync-byte match alone is not
% sufficient. Each candidate is confirmed against the Nortek checksum:
%     checksum = 0xB58C + sum(all 16-bit words preceding the checksum word)
    if numel(b) < recLen
        p = zeros(0, 1);
        return
    end
    cand = find(b(1:end-1) == 165 & b(2:end) == uint8(id));
    cand = cand(cand + recLen - 1 <= numel(b));
    if isempty(cand)
        p = zeros(0, 1);
        return
    end

    % Vectorised checksum over the (recLen/2 - 1) words that precede the trailer
    acc = uint32(hex2dec('B58C')) * ones(numel(cand), 1, 'uint32');
    for w = 0 : (recLen/2 - 2)
        lo  = uint32(b(cand + 2*w));
        hi  = uint32(b(cand + 2*w + 1));
        acc = acc + lo + bitshift(hi, 8);
    end
    acc = uint32(bitand(acc, uint32(65535)));
    cs  = uint32(b(cand + recLen - 2)) + bitshift(uint32(b(cand + recLen - 1)), 8);
    p   = cand(acc == cs);
end

% ======================================================================
function n = count_bad_sync(b, id, nGood)
% Number of sync-byte matches rejected by the checksum test — normally these
% are 0xA5 bytes occurring inside data, not corruption. Reported for context.
    if numel(b) < 2
        n = 0; return
    end
    n = sum(b(1:end-1) == 165 & b(2:end) == uint8(id)) - nGood;
end

% ======================================================================
function v = i16(b, p)
% Little-endian signed 16-bit read at byte index p.
    v = double(b(p)) + 256 * double(b(p + 1));
    v(v > 32767) = v(v > 32767) - 65536;
end

% ======================================================================
function v = u16(b, p)
% Little-endian unsigned 16-bit read at byte index p.
    v = double(b(p)) + 256 * double(b(p + 1));
end

% ======================================================================
function v = bcd(x)
% Nortek clock fields are packed binary-coded decimal.
    x = double(x);
    v = floor(x / 16) * 10 + mod(x, 16);
end

% ======================================================================
function SEN = build_SEN(b, p)
% Vector System Data (0xA5 0x11), 28 bytes, emitted at 1 Hz.
%   off 4..9 clock BCD [min sec day hour year month]
%   off 10 battery (0.1 V)   12 sound speed (0.1 m/s)
%   off 14 heading  16 pitch  18 roll (0.1 deg)   20 temperature (0.01 degC)
%   off 22 error    23 status  24 analogue in
    if isempty(p)
        SEN = zeros(0, 16);
        return
    end
    minute = bcd(b(p + 4));
    second = bcd(b(p + 5));
    day    = bcd(b(p + 6));
    hour   = bcd(b(p + 7));
    yy     = bcd(b(p + 8));
    month  = bcd(b(p + 9));
    year   = yy + 2000;
    year(yy >= 90) = yy(yy >= 90) + 1900;

    SEN = zeros(numel(p), 16);
    SEN(:,  1) = month;
    SEN(:,  2) = day;
    SEN(:,  3) = year;
    SEN(:,  4) = hour;
    SEN(:,  5) = minute;
    SEN(:,  6) = second;
    % The ASCII export prints error and status as 8-digit binary strings, which
    % textscan then reads as decimal numbers (0xFD -> "11111101" -> 11111101).
    % Reproduce that representation so the two ingest paths agree exactly.
    SEN(:,  7) = bits_as_decimal(b(p + 22));
    SEN(:,  8) = bits_as_decimal(b(p + 23));
    SEN(:,  9) = i16(b, p + 10) * 0.1;    % battery, V
    SEN(:, 10) = i16(b, p + 12) * 0.1;    % sound speed, m/s
    SEN(:, 11) = i16(b, p + 14) * 0.1;    % heading, deg
    SEN(:, 12) = i16(b, p + 16) * 0.1;    % pitch, deg
    SEN(:, 13) = i16(b, p + 18) * 0.1;    % roll, deg
    SEN(:, 14) = i16(b, p + 20) * 0.01;   % temperature, degC
    SEN(:, 15) = i16(b, p + 24);          % analogue in 1
    SEN(:, 16) = 0;                       % analogue in 2 (not in this record)
end

% ======================================================================
function d = bits_as_decimal(byteVals)
% Render each byte as the decimal number formed by its 8 binary digits,
% matching how the ASCII .sen export prints error/status flags.
    byteVals = double(byteVals(:));
    d = zeros(size(byteVals));
    for k = 0:7
        d = d + mod(floor(byteVals / 2^k), 2) * 10^k;
    end
end

% ======================================================================
function [DAT, nBurst] = build_DAT(b, p, pVH, noiseVH, burstOffset)
% Vector Velocity Data (0xA5 0x10), 24 bytes, emitted at fs Hz.
%   off 2 AnaIn2LSB   3 count   4 pressureMSB   5 AnaIn2MSB
%   off 6 pressureLSW  8 AnaIn1  10,12,14 vel[3]  16..18 amp[3]  19..21 corr[3]
    if isempty(p)
        DAT = zeros(0, 18);
        nBurst = numel(pVH);
        return
    end
    n = numel(p);
    DAT = zeros(n, 18);

    % Velocity counts are 1 mm/s for these instruments; confirmed bit-exact
    % against the TORREY02 ASCII export in test_read_VEC.m.
    DAT(:, 3) = i16(b, p + 10) / 1000;
    DAT(:, 4) = i16(b, p + 12) / 1000;
    DAT(:, 5) = i16(b, p + 14) / 1000;

    amp = zeros(n, 3);
    for c = 1:3
        amp(:, c)         = double(b(p + 15 + c));   % offsets 16,17,18
        DAT(:, 11 + c)    = double(b(p + 18 + c));   % corr, offsets 19,20,21
    end
    DAT(:, 6:8) = amp;

    % Pressure is a 24-bit unsigned count in 0.001 dBar: MSB byte + 16-bit LSW.
    DAT(:, 15) = (double(b(p + 4)) * 65536 + u16(b, p + 6)) * 0.001;

    DAT(:, 16) = i16(b, p + 8);                                        % ain1
    DAT(:, 17) = double(b(p + 2)) + 256 * double(b(p + 5));            % ain2
    DAT(:, 18) = 0;   % checksum flag: every retained record passed its checksum

    % Assign each velocity record to the burst opened by the most recent
    % velocity-data-header record, then index samples within that burst.
    if isempty(pVH)
        burst = ones(n, 1);
        ens   = (1:n)';
        noise = nan(n, 3);
    else
        burst = discretize(p, [pVH; inf]);
        pre   = isnan(burst);         % records before the first header
        burst(pre) = 1;
        first = zeros(max(burst), 1);
        [ub, ib] = unique(burst, 'first');
        first(ub) = ib;
        ens = (1:n)' - first(burst) + 1;
        noise = nan(n, 3);
        ok = ~pre;
        noise(ok, :) = noiseVH(burst(ok), :);
    end
    DAT(:, 1) = burst + burstOffset;
    DAT(:, 2) = ens;

    % SNR in dB: 0.43 dB per amplitude count above the burst noise floor.
    % Verified against the TORREY02 ASCII export.
    DAT(:, 9:11) = 0.43 * (amp - noise);

    nBurst = numel(pVH);
end

% ======================================================================
function meta = parse_config(b, ID_HW, LEN_HW, ID_HD, LEN_HD, ID_US, LEN_US)
% Pull instrument identity and deployment setup out of the three configuration
% records at the head of the file. This is the metadata that is unavailable
% when the ASCII .hdr export is 0 bytes.
    meta = struct('serialNo', '', 'headSerialNo', '', 'fwVersion', '', ...
                  'coordSystem', '', 'fs', NaN, 'nBeams', NaN, ...
                  'deployName', '', 'clockDeploy', NaT, ...
                  'headFreq_kHz', NaN, 'velScale', 0.001);

    pHW = find_records(b, ID_HW, LEN_HW);
    if ~isempty(pHW)
        q = pHW(1);
        meta.serialNo  = strtrim(clean_ascii(b(q+4  : q+17)));
        meta.fwVersion = strtrim(clean_ascii(b(q+42 : q+45)));
    end

    pHD = find_records(b, ID_HD, LEN_HD);
    if ~isempty(pHD)
        q = pHD(1);
        meta.headFreq_kHz = i16(b, q + 6);
        meta.headSerialNo = strtrim(clean_ascii(b(q+10 : q+21)));
    end

    pUS = find_records(b, ID_US, LEN_US);
    if ~isempty(pUS)
        q = pUS(1);
        meta.nBeams = u16(b, q + 18);
        avgInterval = u16(b, q + 16);
        if avgInterval > 0
            % Vector continuous sampling rate is 512 / AvgInterval.
            meta.fs = 512 / avgInterval;
        end
        switch u16(b, q + 32)
            case 0, meta.coordSystem = 'ENU';
            case 1, meta.coordSystem = 'XYZ';
            case 2, meta.coordSystem = 'BEAM';
            otherwise, meta.coordSystem = 'UNKNOWN';
        end
        meta.deployName = strtrim(clean_ascii(b(q+40 : q+45)));
        c = bcd(b(q+48 : q+53));   % [min sec day hour year month]
        yr = c(5) + 2000;
        if c(5) >= 90, yr = c(5) + 1900; end
        try
            meta.clockDeploy = datetime(yr, c(6), c(3), c(4), c(1), c(2));
        catch
            meta.clockDeploy = NaT;
        end
    end
end

% ======================================================================
function s = clean_ascii(bytes)
% Convert a fixed-width Nortek text field to char.
%
% The firmware packs more than one value into some fields, separated by a
% non-printable byte — the 14-byte hardware serial field, for example, holds
% "VEC15277" then a separator then the firmware string "4.24". Stop at the
% first non-printable byte rather than stripping it, so the two do not get
% concatenated into a bogus serial number.
    v = double(bytes(:)');
    stop = find(v < 32 | v > 126, 1, 'first');
    if ~isempty(stop)
        v = v(1:stop-1);
    end
    s = char(v);
end
