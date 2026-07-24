function [offsetSec, diag] = vec_clock_from_filenames(vecFiles, SEN_bursts, opts)
% VEC_CLOCK_FROM_FILENAMES  Recover true time for a Vector with a wrong RTC epoch.
%
%   [offsetSec, diag] = vec_clock_from_filenames(vecFiles, SEN_bursts, opts)
%
%   Several pre-2019 Vectors in the archive recorded with their real-time clock
%   set to a nonsense epoch — Torrey0806_2018 stamps its first sample
%   2002-01-01, Torrey1053_2016 stamps 2000-01-01. The clock is not frozen: it
%   RUNS correctly, just from the wrong start. Torrey1181's RTC advances
%   10 d 12:59:40 while its filenames advance 10 d 13:00:00.
%
%   Meanwhile the recorder names each hourly file for the wall-clock hour it
%   opened, as MMDDHHMM (month, day, hour, minute) — 03200700.VEC is 20 March,
%   07:00. So the filenames carry the true time and the RTC carries the true
%   sample spacing, and the two are reconciled by a single constant offset.
%
%   This returns that offset, in seconds, to be ADDED to the decoded RTC. It is
%   the median over every file, so one mis-parsed name cannot move it.
%
%   VALIDATION. The offset must be near-constant across files; if it is not, the
%   filename/RTC relationship is not what is assumed here and the result would be
%   silently wrong, so this errors rather than returning. The residual spread is
%   the instrument's own clock drift over the deployment and is reported in
%   `diag.driftSec` — feed it to instr.clockDrift to have L1 remove it linearly.
%
%   The method is checkable against a control: Cardiff1049_2015-2016 is the one
%   instrument in this group whose RTC was set correctly, and there the offset
%   comes out at 33 s — i.e. filename time and a good clock agree, which is what
%   makes the convention trustworthy on the instruments whose clocks were not.
%
%   INPUTS
%     vecFiles   - cellstr of raw file paths, in the order read_VEC returned them
%     SEN_bursts - cell array of per-file SEN matrices from read_VEC(...,'Split',true)
%     opts       - struct:
%                    startYear   (required) calendar year of the FIRST file
%                    maxSpreadSec (optional, default 900) reject beyond this
%
%   OUTPUTS
%     offsetSec  - scalar seconds to add to every decoded timestamp
%     diag       - struct: nFiles, medianOffsetSec, maxDevSec, driftSec,
%                  firstTime, lastTime (datetime, reconstructed)
%
%   NOTE ON TIME ZONE. This recovers the clock the instrument was SET to; it
%   cannot tell you whether that was UTC or local. Confirm against the L3 tidal
%   comparison (a whole-hours phase error against the NOAA gauge means the
%   deployment was logged in local time) before trusting absolute timing.
%
% Author: Holden Leslie-Bole, 2026

    if ~isfield(opts, 'startYear') || isempty(opts.startYear)
        error('vec_clock_from_filenames:noStartYear', ...
            'opts.startYear is required — the filenames carry no year.');
    end
    maxSpread = 900;
    if isfield(opts, 'maxSpreadSec') && ~isempty(opts.maxSpreadSec)
        maxSpread = opts.maxSpreadSec;
    end

    nF = numel(vecFiles);
    if nF ~= numel(SEN_bursts)
        error('vec_clock_from_filenames:sizeMismatch', ...
            '%d files but %d SEN bursts.', nF, numel(SEN_bursts));
    end

    % ---- first RTC timestamp of each file ----
    rtc  = NaT(nF, 1);
    mmddhhmm = nan(nF, 4);
    for k = 1:nF
        S = SEN_bursts{k};
        if isempty(S), continue; end
        rtc(k) = datetime(S(1,3), S(1,1), S(1,2), S(1,4), S(1,5), S(1,6));

        [~, base] = fileparts(vecFiles{k});
        tok = regexp(base, '^(\d{2})(\d{2})(\d{2})(\d{2})$', 'tokens', 'once');
        if isempty(tok), continue; end
        mmddhhmm(k, :) = [str2double(tok{1}) str2double(tok{2}) ...
                          str2double(tok{3}) str2double(tok{4})];
    end

    use = ~isnat(rtc) & ~any(isnan(mmddhhmm), 2);
    if nnz(use) < 3
        error('vec_clock_from_filenames:tooFewFiles', ...
            ['Only %d files have both a decodable RTC and an MMDDHHMM name. ' ...
             'These raw files are not named the way this recovery assumes.'], nnz(use));
    end

    % ---- order by RTC, which is monotonic even from a wrong epoch ----
    idx = find(use);
    [~, ord] = sort(rtc(idx));
    idx = idx(ord);

    % ---- walk the calendar, rolling the year over when the month jumps back ----
    yr = opts.startYear;
    prevMonth = mmddhhmm(idx(1), 1);
    fnameTime = NaT(numel(idx), 1);
    for j = 1:numel(idx)
        mo = mmddhhmm(idx(j), 1);
        if mo < prevMonth - 6      % Dec -> Jan, not an out-of-order file
            yr = yr + 1;
        end
        prevMonth = mo;
        try
            fnameTime(j) = datetime(yr, mo, mmddhhmm(idx(j), 2), ...
                                    mmddhhmm(idx(j), 3), mmddhhmm(idx(j), 4), 0);
        catch
            fnameTime(j) = NaT;    % e.g. 02/30 from a corrupt name
        end
    end

    ok = ~isnat(fnameTime);
    offsets = seconds(fnameTime(ok) - rtc(idx(ok)));
    med = median(offsets);
    dev = abs(offsets - med);

    if max(dev) > maxSpread
        error('vec_clock_from_filenames:inconsistentOffset', ...
            ['Filename-to-RTC offset is not constant: median %.0f s but spread ' ...
             'up to %.0f s across %d files (limit %.0f s). The filenames do not ' ...
             'track this clock, so the reconstruction would be wrong — inspect ' ...
             'the raw file names before processing this deployment.'], ...
            med, max(dev), numel(offsets), maxSpread);
    end

    offsetSec = med;
    diag = struct( ...
        'nFiles',          numel(offsets), ...
        'medianOffsetSec', med, ...
        'maxDevSec',       max(dev), ...
        'driftSec',        offsets(end) - offsets(1), ...
        'firstTime',       rtc(idx(find(ok, 1, 'first'))) + seconds(med), ...
        'lastTime',        rtc(idx(find(ok, 1, 'last'))) + seconds(med));
end
