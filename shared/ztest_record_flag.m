% ZTEST_RECORD_FLAG  Record-level pressure/velocity consistency check from Z.
%
% function qc = ztest_record_flag(ztest, segValid, opts)
%
% The per-segment Z diagnostic (Elgar, Raubenheimer & Guza 2005, MST 16) is the
% ratio of the measured pressure spectrum to the pressure spectrum predicted
% from velocity, energy-weighted over a band:
%
%     Z = sum(Spp .* S_eta) / sum(Spp_from_vel .* S_eta),
%     Spp_from_vel = (Suu + Svv) .* (omega/(g k)).^2
%
% For a clean linear wave field Z = 1 (asserted at six depths by
% L2_spectral/test_ztest_linear.m). On real data the catalog sits at a median
% of ~0.97 with no depth dependence: velocity noise inflates Suu+Svv, which
% inflates the predicted pressure and pushes Z a few per cent below one.
%
% WHY A RECORD-LEVEL FLAG. Z has been computed and stored per segment since
% 2026-06 but never consumed, so a whole record could fail it silently.
% RUBY22/MOP582_30m is the case in point: its pressure transducer is dead
% (median Hs 6 mm across 2578 "valid" segments at a 30.6 m open-coast site) and
% nothing in L2 QC catches it -- but its median Z is 1e-4, four orders of
% magnitude clear of every other record in the catalog, which all fall in
% 0.85-1.04. One number separates it cleanly.
%
% This is deliberately a FLAG, not a gate. It marks the record and warns; it
% never drops segments. A per-segment hard gate on Z would silently discard
% data on the strength of a diagnostic that is itself sensitive to velocity
% noise, which is the opposite of what this is for.
%
% INPUTS
%   ztest    - (nSeg x 1) per-segment Z (e.g. L2.ztest_SS)
%   segValid - (nSeg x 1) logical; only these segments are considered
%   opts     - optional struct
%              .window  [lo hi] acceptable median Z (default [0.5 2], the
%                       published retention window)
%              .minSeg  minimum valid segments for the median to mean
%                       anything (default 20)
%
% OUTPUT (struct qc)
%   .median   median Z over valid, finite segments (NaN if too few)
%   .n        number of valid, finite segments the median is taken over
%   .window   the window applied
%   .status   'ok' | 'FLAG' | 'insufficient'
%   .flag     true only when status is 'FLAG' -- i.e. enough segments AND the
%             median falls outside the window. 'insufficient' is NOT a flag:
%             too little data is not evidence of a bad sensor.
%   .reason   human-readable one-liner for logs
%
% Author: Holden Leslie-Bole, 2026

function qc = ztest_record_flag(ztest, segValid, opts)

if nargin < 3, opts = struct(); end
if ~isfield(opts, 'window'), opts.window = [0.5 2]; end
if ~isfield(opts, 'minSeg'), opts.minSeg = 20;      end

z = ztest(:);
v = logical(segValid(:));
if numel(v) ~= numel(z)
    error('ztest_record_flag:sizeMismatch', ...
        'ztest (%d) and segValid (%d) must be the same length.', numel(z), numel(v));
end

use = v & isfinite(z);
qc = struct();
qc.window = opts.window;
qc.n      = sum(use);

if qc.n < opts.minSeg
    qc.median = NaN;
    qc.status = 'insufficient';
    qc.flag   = false;
    qc.reason = sprintf('only %d valid finite Z segments (< %d); no record-level verdict', ...
                        qc.n, opts.minSeg);
    return
end

qc.median = median(z(use));
if qc.median < opts.window(1) || qc.median > opts.window(2)
    qc.status = 'FLAG';
    qc.flag   = true;
    qc.reason = sprintf(['median Z = %.4g over %d valid segments, outside [%g %g] -- ' ...
                         'pressure and velocity disagree at record level; suspect a ' ...
                         'dead or mis-scaled sensor'], ...
                        qc.median, qc.n, opts.window(1), opts.window(2));
else
    qc.status = 'ok';
    qc.flag   = false;
    qc.reason = sprintf('median Z = %.4f over %d valid segments, inside [%g %g]', ...
                        qc.median, qc.n, opts.window(1), opts.window(2));
end
end
