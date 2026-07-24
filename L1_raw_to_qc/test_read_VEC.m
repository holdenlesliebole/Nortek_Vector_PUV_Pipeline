function test_read_VEC(vecDir)
% TEST_READ_VEC  Verify the .VEC binary decoder against a Nortek ASCII export.
%
%   test_read_VEC()
%   test_read_VEC(vecDir)
%
%   The TORREY02 (Torrey Pines MOP582 10 m, 2019-2020) deployment is the one
%   place in the archive where a Nortek ExploreV ASCII export and the raw
%   binary both exist, so it is the ground truth for the decoder. The export
%   covers only the first ~5.1 days of the 174-day record and its final line is
%   truncated mid-record, so the comparison is made over the overlap only, with
%   the last line of each ASCII file discarded.
%
%   Checks, all required to be exact rather than approximate:
%     1. Configuration metadata decodes (serial, coordinate system, fs).
%     2. DAT velocity/amplitude/correlation/pressure match the .dat columns.
%     3. SEN clock/attitude/temperature match the .sen columns.
%     4. Derived SNR matches to the ASCII print precision (1 decimal).
%
%   Run from the repo root with startup_puv on the path.
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 1 || isempty(vecDir)
        vecDir = ['/Volumes/group/PUV_data/Vector/recopied/' ...
                  'TorreyPines2019-2020MOP582_10meter'];
    end

    datFile = fullfile(vecDir, 'TORREY02_1.dat');
    senFile = fullfile(vecDir, 'TORREY02_1.sen');
    vecFile = fullfile(vecDir, 'TORREY02_1.VEC');
    for f = {vecFile, datFile, senFile}
        assert(isfile(f{1}), 'test_read_VEC:missing', 'Not found: %s', f{1});
    end

    fprintf('=== test_read_VEC ===\n');
    fprintf('Ground truth: %s\n', datFile);

    %% ---- decode the binary ----
    t0 = tic;
    [DAT, SEN, meta] = read_VEC(vecFile);
    fprintf('Decoded in %.1f s: %d velocity, %d system records\n', ...
        toc(t0), size(DAT,1), size(SEN,1));

    %% ---- 1. metadata ----
    fprintf('\n-- metadata --\n');
    fprintf('  serial       : %s\n', meta.serialNo);
    fprintf('  head serial  : %s\n', meta.headSerialNo);
    fprintf('  firmware     : %s\n', meta.fwVersion);
    fprintf('  coord system : %s\n', meta.coordSystem);
    fprintf('  fs           : %g Hz\n', meta.fs);
    fprintf('  nBeams       : %g\n', meta.nBeams);
    fprintf('  deploy clock : %s\n', string(meta.clockDeploy));
    fprintf('  rejected sync matches (0xA5 in data): %d\n', meta.nBadChecksum);

    assert(~isempty(meta.coordSystem) && ~strcmp(meta.coordSystem,'UNKNOWN'), ...
        'test_read_VEC:coord', 'Coordinate system did not decode.');
    assert(meta.fs > 0, 'test_read_VEC:fs', 'Sampling rate did not decode.');

    %% ---- read the ASCII export ----
    fid = fopen(datFile, 'r');
    raw = textscan(fid, repmat('%f', 1, 18), 'CollectOutput', true);
    fclose(fid);
    datA = raw{1};
    fid = fopen(senFile, 'r');
    raw = textscan(fid, repmat('%f', 1, 16), 'CollectOutput', true);
    fclose(fid);
    senA = raw{1};

    % Both ASCII files end mid-line (interrupted export); drop the last row.
    datA(end, :) = [];
    senA(end, :) = [];

    nD = min(size(datA,1), size(DAT,1));
    nS = min(size(senA,1), size(SEN,1));
    fprintf('\nComparing %d velocity rows, %d system rows\n', nD, nS);
    assert(nD > 1e5, 'test_read_VEC:tooFewRows', ...
        'Only %d overlapping velocity rows — decode likely failed.', nD);

    % Tolerances. Columns that are integers in the binary (velocity counts,
    % amplitude, correlation, clock fields, flags) must agree EXACTLY — that is
    % the real test of the decoder. Columns the firmware stores as an integer
    % count times a fixed scale (0.1, 0.01, 0.001) are compared at 1e-9, which
    % only allows for the binary representation of that scaling. SNR is derived
    % as 0.43*(amp - noise) and the export prints it to one decimal, so the
    % binary value can legitimately sit up to half a printed digit from the
    % ASCII rendering.
    EXACT  = 0;
    SCALED = 1e-9;
    PRINT1 = 0.0501;

    %% ---- 2. DAT columns ----
    fprintf('\n-- DAT (.dat) --\n');
    ok = true;
    ok = check_col(DAT, datA, nD,  3, 'u (m/s)',    EXACT,  ok);
    ok = check_col(DAT, datA, nD,  4, 'v (m/s)',    EXACT,  ok);
    ok = check_col(DAT, datA, nD,  5, 'w (m/s)',    EXACT,  ok);
    ok = check_col(DAT, datA, nD,  6, 'amp1',       EXACT,  ok);
    ok = check_col(DAT, datA, nD,  7, 'amp2',       EXACT,  ok);
    ok = check_col(DAT, datA, nD,  8, 'amp3',       EXACT,  ok);
    ok = check_col(DAT, datA, nD, 12, 'corr1',      EXACT,  ok);
    ok = check_col(DAT, datA, nD, 13, 'corr2',      EXACT,  ok);
    ok = check_col(DAT, datA, nD, 14, 'corr3',      EXACT,  ok);
    ok = check_col(DAT, datA, nD, 15, 'pressure',   SCALED, ok);
    ok = check_col(DAT, datA, nD,  9, 'snr1',       PRINT1, ok);
    ok = check_col(DAT, datA, nD, 10, 'snr2',       PRINT1, ok);
    ok = check_col(DAT, datA, nD, 11, 'snr3',       PRINT1, ok);

    %% ---- 3. SEN columns ----
    fprintf('\n-- SEN (.sen) --\n');
    names = {'month','day','year','hour','minute','second', ...
             'error','status','battery','soundspeed', ...
             'heading','pitch','roll','temperature'};
    tols  = [repmat(EXACT, 1, 8), repmat(SCALED, 1, 6)];
    for c = 1:14
        ok = check_col(SEN, senA, nS, c, names{c}, tols(c), ok);
    end

    %% ---- verdict ----
    fprintf('\n=== %s ===\n', ternary(ok, 'PASS', 'FAIL'));
    if ~ok
        error('test_read_VEC:mismatch', ...
            'Decoder output does not match the ASCII export.');
    end
end

% ======================================================================
function ok = check_col(X, A, n, c, name, tol, ok)
% Compare one column over the first n rows, treating NaN in both as agreement.
    a = X(1:n, c);
    b = A(1:n, c);
    both = isnan(a) & isnan(b);
    d = abs(a - b);
    d(both) = 0;
    bad = ~(d <= tol) & ~both;
    nBad = sum(bad);
    if nBad == 0
        fprintf('  %-12s OK        (max |diff| = %.3g)\n', name, max(d));
    else
        [worst, iw] = max(d);
        fprintf('  %-12s MISMATCH  %d/%d rows, worst %.6g at row %d (bin %.6g vs ascii %.6g)\n', ...
            name, nBad, n, worst, iw, a(iw), b(iw));
        ok = false;
    end
end

% ======================================================================
function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
