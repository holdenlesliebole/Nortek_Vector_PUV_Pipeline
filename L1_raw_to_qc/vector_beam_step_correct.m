function [Xc, bs] = vector_beam_step_correct(X, valid, fs, T, opts)
% VECTOR_BEAM_STEP_CORRECT  Remove one-beam velocity steps of a Nortek Vector, in beam space.
%
%   [Xc, bs] = vector_beam_step_correct(X, valid, fs, T, opts)
%
%   The Vector occasionally reports one beam offset by an integer multiple of a
%   fixed step Delta (about 1.51 m/s along the beam), for a single sample or a
%   short run, at high correlation. In XYZ this is a jump of about 4 m/s along
%   one column of T. See docs/DIAGNOSIS_L1_velocity_spikes_2026-11-13.md and the
%   rule, its parameters and its tests in
%   docs/SPEC_L1_beam_step_correction_2026-11-13.md.
%
%   INPUTS
%     X      N x 3 velocity in the RECORDED instrument XYZ frame (m/s): as the
%            Vector wrote it, before L1's W = -W flip, sound-speed factor and
%            tilt rotation. Samples with valid == false are ignored and never
%            changed.
%     valid  N x 1 logical (L1 qc.valid_vel). N samples on a regular grid at fs.
%     fs     sampling rate (Hz)
%     T      3 x 3 head transformation matrix, x = T*b (vector_head_matrix)
%     opts   struct, all optional (defaults are the spec's fixed values):
%       .Delta        step size (m/s). NaN (default) = estimate from this record.
%       .DeltaWindow  [1.40 1.60] m/s acceptance window for Delta
%       .Delta0       1.50 m/s, search value for the estimation pass
%       .tolEdge      0.35 m/s, residual tolerance on EVERY beam at an edge
%       .kMax         2, largest |k| per beam per edge and per sample
%       .gapMaxSec    10.0 s, longest QC gap an edge may bridge
%       .gapShortSec  2.0 s; a run with an edge across a longer gap must also
%                     pass the level check
%       .runMaxSec    15.0 s, longest run that may be corrected
%       .refHalfSec   30.0 s, half-width (in valid samples x fs) of the moving
%                     median that anchors the absolute level
%       .nFit         3, clean samples on each side for the level check's
%                     local quadratic (within gapMaxSec of the run)
%       .tolLevel     0.35 m/s, level-check tolerance on every beam
%       .flagWhenNoDelta  false. true (per record, by ruling): when Delta is not
%                     estimable, flag the runs the Delta0 pass confirmed as
%                     unconfirmed (status 'no_delta_flagged'); values unchanged
%
%   RULE (summary; the spec is authoritative)
%   1. Beams b = T \ x on valid samples.
%   2. Valid samples are chained into segments; consecutive valid samples with
%      more than gapMaxSec of missing samples between them start a new segment.
%   3. An EDGE between consecutive chained samples is a change d (3 beams),
%      detrended by the local flow slope (median rate over the 2 neighboring
%      intervals each side, leaving out step-sized ones; not across gaps >
%      gapShortSec), with
%      k = round(d/Delta) nonzero on at least one beam, |k| <= kMax, and
%      |d - k*Delta| < tolEdge on ALL THREE beams.
%   4. Absolute anchoring: within a segment, K = cumulative edge k; the
%      unwrapped beam u = b - K*Delta; C = round(moving median of u over
%      +-refHalfSec / Delta); offset OFF = K + C. A candidate run is a maximal
%      stretch with OFF ~= 0, no longer than runMaxSec, whose internal offset
%      changes are all edges; its two bounding transitions are counted as edges
%      (two-edge, one-edge or zero-edge run) if they are edges of the right k.
%   5. A candidate run is corrected only if CONFIRMED: |OFF| <= kMax on every
%      beam, and unless it is a two-edge run whose edges both join adjacent
%      samples, every run sample satisfies |b - fit - OFF*Delta| < tolLevel on
%      every beam (LEVEL CHECK; fit = quadratic in time through the nFit nearest
%      samples on EACH side that are in no candidate, within gapMaxSec).
%      b' = b - OFF*Delta. A failing two-edge run, or one-edge run whose edge
%      joins adjacent samples, is flagged unconfirmed and left unchanged; other
%      failing candidates are only counted (nRejectedOneZeroEdge).
%   5b. ZERO-EDGE runs: a contiguous stretch <= runMaxSec isolated by QC gaps of
%      1 to gapShortSec missing samples on both sides, neither crossed by an
%      edge, whose level residual rounds to the same nonzero k on every sample;
%      confirmed by the level check alone (fit within gapShortSec).
%   6. Delta: if not given, a first pass with Delta0 collects the single-beam,
%      |k| = 1 edges between adjacent samples (no gap) of confirmed runs;
%      Delta = median |d| on the stepped beam.
%      Refused (no correction) if outside DeltaWindow.
%   Only flagged samples are written: Xc = X - T*(k*Delta) there, Xc = X
%   elsewhere, bit for bit.
%
%   OUTPUTS
%     Xc   N x 3 corrected velocity, same frame as X
%     bs   struct:
%       .k            N x 3 int8, offset removed, in units of Delta, per beam
%       .unconfirmed  N x 1 logical, sample in an unconfirmed run (unchanged)
%       .status       'corrected' | 'no_steps' | 'refused_delta' | 'no_delta_flagged'
%       .Delta, .DeltaSource ('estimated'|'given'), .nDeltaEdges,
%       .DeltaIQR     [p25 p75] of the estimation edges (m/s)
%       .counts       nSamples, nRuns, nRunsLevelChecked, nRunsZeroEdge,
%                     nRunsOneEdge, nRunsDouble (|k| = 2),
%                     nRunsMultiBeam, runLenHist (1, 2-3, 4-10, 11-30 samples),
%                     longestRun, nUnconfirmedRuns, nUnconfirmedSamples
%                     (step-length spans that failed confirmation, flagged),
%                     nLongOffsets (offset stretches longer than runMaxSec or
%                     with a non-edge change inside: counted, not flagged),
%                     nEdges, nSegments
%       .opts         options used
%
%   Units: m/s throughout; k dimensionless. Added 2026-11-13.

    if nargin < 5, opts = struct(); end
    def = struct('Delta', NaN, 'DeltaWindow', [1.40 1.60], 'Delta0', 1.50, ...
        'tolEdge', 0.35, 'kMax', 2, 'gapMaxSec', 10.0, 'gapShortSec', 2.0, ...
        'runMaxSec', 15.0, 'refHalfSec', 30.0, 'nFit', 3, 'tolLevel', 0.35, ...
        'flagWhenNoDelta', false);
    f = fieldnames(def);
    for i = 1:numel(f)
        if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = def.(f{i}); end
    end

    N = size(X, 1);
    valid = logical(valid(:)) & all(isfinite(X), 2);
    idx = find(valid);
    B = (T \ X(idx, :).').';          % M x 3 beam velocities (m/s)

    bs = struct('k', zeros(N, 3, 'int8'), 'unconfirmed', false(N, 1), ...
        'status', '', 'Delta', NaN, 'DeltaSource', '', 'nDeltaEdges', 0, ...
        'DeltaIQR', [NaN NaN], 'counts', struct(), 'opts', opts);

    % ---- Delta
    if isnan(opts.Delta)
        r0 = detect(B, idx, fs, opts.Delta0, opts);
        s = r0.singleEdgeSizes;
        bs.nDeltaEdges = numel(s);
        bs.DeltaSource = 'estimated';
        if isempty(s)
            bs.status = 'no_steps';
            bs.counts = r0.counts;
            Xc = X;
            % Opt-in (per record): runs the Delta0 pass confirmed, left uncorrected
            % because Delta is not estimable (e.g. only |k| = 2 edges), are flagged
            % unconfirmed so L2 treats them as gaps. Values stay as recorded.
            if opts.flagWhenNoDelta
                fl = any(r0.K ~= 0, 2);   % confirmed runs only (the ruling); r0.unconf is reported, not flagged
                bs.unconfirmed(idx(fl)) = true;
                if any(fl), bs.status = 'no_delta_flagged'; end
            end
            return
        end
        bs.Delta = median(s);
        bs.DeltaIQR = [prctile(s, 25) prctile(s, 75)];
    else
        bs.Delta = opts.Delta;
        bs.DeltaSource = 'given';
    end
    if bs.Delta < opts.DeltaWindow(1) || bs.Delta > opts.DeltaWindow(2)
        bs.status = 'refused_delta';
        Xc = X;
        return
    end

    % ---- correction pass
    r = detect(B, idx, fs, bs.Delta, opts);
    bs.counts = r.counts;
    Xc = X;
    hit = any(r.K ~= 0, 2);
    if any(hit)
        rows = idx(hit);
        Kh = double(r.K(hit, :));
        Xc(rows, :) = X(rows, :) - (T * (Kh.' * bs.Delta)).';
        bs.k(rows, :) = int8(Kh);
    end
    bs.unconfirmed(idx(r.unconf)) = true;
    if any(hit), bs.status = 'corrected'; else, bs.status = 'no_steps'; end
end

% ======================================================================
function r = detect(B, idx, fs, Delta, opts)
% Edges, segments, runs. Returns per-valid-sample offsets K (M x 3, in units of
% Delta, zero outside confirmed runs) and the unconfirmed mask.
    M = numel(idx);
    gapMax   = round(opts.gapMaxSec * fs);
    gapShort = round(opts.gapShortSec * fs);
    runMax   = round(opts.runMaxSec * fs);
    K = zeros(M, 3);
    unconf = false(M, 1);
    sizes = [];
    c = struct('nSamples', 0, 'nRuns', 0, 'nRunsLevelChecked', 0, 'nRunsZeroEdge', 0, ...
        'nRunsOneEdge', 0, 'nRunsDouble', 0, ...
        'nRunsMultiBeam', 0, 'runLenHist', zeros(1, 4), 'longestRun', 0, ...
        'nUnconfirmedRuns', 0, 'nUnconfirmedSamples', 0, 'nLongOffsets', 0, ...
        'nRejectedOneZeroEdge', 0, ...
        'nEdges', 0, 'nSegments', 0);
    if M < 2
        r = struct('K', K, 'unconf', unconf, 'singleEdgeSizes', sizes, 'counts', c);
        return
    end

    gap = diff(idx) - 1;                       % MISSING samples between neighbors
    Draw = diff(B, 1, 1);                      % (M-1) x 3 raw beam changes
    % Detrend each change by the local flow slope: the median rate of change over
    % the 2 neighboring intervals on each side (same segment, gaps <= gapShort,
    % not step-sized), times the interval length. Smooth wave flow then leaves
    % only its curvature.
    nI = M - 1;
    seg = cumsum([1; gap > gapMax]);           % segment id of each interval
    seg = seg(1:nI);
    rate = Draw ./ (gap + 1);
    % Neighbors that are not flow slopes: across long gaps, or step-sized (any
    % beam changing by more than Delta/2 in one interval; real flow at 2 Hz
    % does not, and leaving them in biases the median toward the step).
    rate(gap > gapShort | any(abs(Draw) > Delta/2, 2), :) = NaN;
    nb = NaN(nI, 3, 4);
    col = 0;
    for sh = [-2 -1 1 2]
        col = col + 1;
        j = (1:nI).' + sh;
        okj = j >= 1 & j <= nI;
        okj(okj) = seg(j(okj)) == seg(okj);
        tmp = NaN(nI, 3);
        tmp(okj, :) = rate(j(okj), :);
        nb(:, :, col) = tmp;
    end
    slope = median(nb, 3, 'omitnan');
    nNb = sum(~isnan(nb(:, 1, :)), 3);
    slope(nNb < 2, :) = 0;                     % too few neighbors: no detrend
    slope(gap > gapShort, :) = 0;              % across a long gap a slope times the gap
                                               % is a worse predictor than none; those
                                               % runs face the level check instead
    D = Draw - slope .* (gap + 1);
    kk = round(D / Delta);
    ee = D - kk * Delta;
    isEdge = any(kk ~= 0, 2) & all(abs(kk) <= opts.kMax, 2) & ...
             all(abs(ee) < opts.tolEdge, 2) & gap <= gapMax;
    kk(~isEdge, :) = 0;
    c.nEdges = sum(isEdge);

    % ---- pass A: candidate runs from ABSOLUTELY anchored offsets.
    % Within a segment the edges give the RELATIVE level K (cumulative k). The
    % absolute level comes from the data: the unwrapped beam u = b - K*Delta is
    % the true beam velocity plus an unknown multiple of Delta, and the true beam
    % velocity's local median lies within +-Delta/2 of zero (that needs only a
    % mean beam velocity under 0.75 m/s, i.e. a mean horizontal current under
    % about 3 m/s). So C = round(movmedian(u, +-refHalf)/Delta) and the offset of
    % each sample is OFF = K + C. A run is a maximal stretch with OFF ~= 0. Its
    % bounding transitions are classified as edges or not, and every offset
    % change inside it must be an edge. A missed or flow-made edge makes C flip
    % somewhere without an edge, which the classification and the level check
    % then refuse; it never moves the baseline for the rest of the segment.
    % (Replaces forward pairing, which took an offset level as baseline in
    % TOR17C's dense three-level flicker and changed true samples; spec sec. 9.)
    W = round(opts.refHalfSec * fs);
    brkS = [0; find(gap > gapMax); M];
    c.nSegments = numel(brkS) - 1;
    % PIECES: split at segment breaks AND at every gap the edge test could not
    % cross. Inside a piece the edges make the unwrap exact, so even a one-sample
    % piece is anchored correctly (a spike whose entry crossing failed is its
    % own piece, or shares one with the samples after its exit edge).
    uncrossed = gap > gapMax | (gap >= 1 & ~isEdge);
    brk = [0; find(uncrossed); M];
    cand = zeros(0, 4);                        % [g1 g2 nEdges (2,1,0) edgeIdx(1-edge)]
    REL = zeros(M, 3);
    for s = 1:numel(brk) - 1
        a = brk(s) + 1;  z = brk(s + 1);
        hasEdge = z > a && any(isEdge(a:z-1));
        % a long piece without edges cannot hold a step (C = 0 there): skip
        if ~hasEdge && idx(z) - idx(a) + 1 > runMax, continue; end
        L = z - a + 1;
        if L > 1
            Kc = [0 0 0; cumsum(kk(a:z-1, :), 1)];
        else
            Kc = [0 0 0];
        end
        U = B(a:z, :) - Kc * Delta;
        Cc = round(movmedian(U, [W W], 1) / Delta);
        OFF = Kc + Cc;
        R = runs_of(any(OFF ~= 0, 2));
        for q = 1:size(R, 1)
            p1 = R(q,1);  p2 = R(q,2);
            g1 = a - 1 + p1;  g2 = a - 1 + p2;
            if idx(g2) - idx(g1) + 1 > runMax
                c.nLongOffsets = c.nLongOffsets + 1;
                continue
            end
            inner = p1:p2-1;
            dOFF = OFF(inner + 1, :) - OFF(inner, :);
            if any(any(dOFF ~= kk(a - 1 + inner, :), 2))
                c.nLongOffsets = c.nLongOffsets + 1;   % anchor flipped inside: not a step run
                continue
            end
            eIn  = p1 > 1 && isEdge(g1 - 1) && isequal(kk(g1 - 1, :), OFF(p1, :) - OFF(p1 - 1, :));
            eOut = p2 < L && isEdge(g2)     && isequal(kk(g2, :), OFF(p2 + 1, :) - OFF(p2, :));
            nE = eIn + eOut;
            if nE == 0
                % zero-edge: only an isolated stretch between short QC gaps
                % (1 to gapShortSec missing samples on each side), i.e. the whole
                % piece, inside a segment
                if ~(p1 == 1 && p2 == L && g1 > 1 && g2 < M && ...
                        gap(g1 - 1) >= 1 && gap(g1 - 1) <= gapShort && ...
                        gap(g2) >= 1 && gap(g2) <= gapShort)
                    c.nRejectedOneZeroEdge = c.nRejectedOneZeroEdge + 1;
                    continue
                end
            end
            eIdx = 0;
            if eIn && ~eOut, eIdx = g1 - 1; elseif eOut && ~eIn, eIdx = g2; end
            REL(g1:g2, :) = OFF(p1:p2, :);
            cand(end+1, :) = [g1, g2, nE, eIdx]; %#ok<AGROW>
        end
    end

    % ---- samples usable for the level check's local fit: not in any candidate
    inCand = false(M, 1);
    for q = 1:size(cand, 1), inCand(cand(q,1):cand(q,2)) = true; end

    % ---- pass B: confirm
    for q = 1:size(cand, 1)
        g1 = cand(q,1);  g2 = cand(q,2);
        span = idx(g2) - idx(g1) + 1;          % samples, including gaps
        relq = REL(g1:g2, :);
        twoEdge = cand(q,3) == 2;
        ok = span <= runMax && all(abs(relq(:)) <= opts.kMax) && any(relq(:) ~= 0);
        levelChecked = false;
        if ok && (~twoEdge || gap(g1 - 1) > 0 || gap(g2) > 0)
            % One-edge or zero-edge run, or an edge across any QC gap:
            % every run sample must sit k*Delta from a local quadratic through
            % the nFit nearest clean samples on EACH side (within gapMaxSec of
            % the run), on every beam.
            win = gapMax;  if cand(q,3) == 0, win = gapShort; end
            lev = level_residual(B, idx, inCand, g1, g2, relq, Delta, opts.nFit, win);
            ok = all(isfinite(lev(:))) && all(abs(lev(:)) < opts.tolLevel);
            levelChecked = true;
        end
        if ok
            K(g1:g2, :) = relq;
            c.nRuns = c.nRuns + 1;
            c.nRunsLevelChecked = c.nRunsLevelChecked + levelChecked;
            c.nRunsZeroEdge = c.nRunsZeroEdge + (cand(q,3) == 0);
            c.nRunsOneEdge  = c.nRunsOneEdge  + (cand(q,3) == 1);
            c.nSamples = c.nSamples + (g2 - g1 + 1);
            c.longestRun = max(c.longestRun, span);
            c.runLenHist = c.runLenHist + histcounts(span, [1 2 4 11 31]);
            c.nRunsDouble = c.nRunsDouble + any(abs(relq(:)) >= 2);
            c.nRunsMultiBeam = c.nRunsMultiBeam + (sum(any(relq ~= 0, 1)) > 1);
            % Step sizes for Delta: single-beam |k| = 1 bounding edges across
            % short gaps only (a long gap adds flow change to the edge).
            for e = [g1 - 1, g2]               % edge index into D (between e, e+1)
                if e < 1 || e > nI || ~isEdge(e), continue; end
                ke = kk(e, :);
                if gap(e) == 0 && sum(ke ~= 0) == 1 && sum(abs(ke)) == 1
                    sizes(end+1, 1) = abs(D(e, ke ~= 0)); %#ok<AGROW>
                end
            end
        elseif twoEdge || (cand(q,3) == 1 && gap(cand(q,4)) == 0)
            % closed by two edges, or one edge between adjacent samples, but not
            % confirmed: step-like, flag it (values unchanged)
            [unconf, c] = mark_unconfirmed(unconf, c, idx, g1, g2, runMax);
        else
            c.nRejectedOneZeroEdge = c.nRejectedOneZeroEdge + 1;
        end
    end
    c.nUnconfirmedSamples = sum(unconf);
    r = struct('K', K, 'unconf', unconf, 'singleEdgeSizes', sizes, 'counts', c);
end

% ======================================================================
function lev = level_residual(B, idx, inCand, g1, g2, relq, Delta, nFit, gapMax)
% Residual of run samples g1..g2 against a quadratic (per beam, in time) through
% the nFit nearest clean samples before and after the run. NaN (= fail) when
% either side has fewer than 2 clean samples within gapMax missing samples.
    M = numel(idx);
    pre = []; j = g1 - 1;
    while j >= 1 && numel(pre) < nFit && idx(g1) - idx(j) - 1 <= gapMax + nFit
        if ~inCand(j), pre(end+1) = j; end %#ok<AGROW>
        j = j - 1;
    end
    post = []; j = g2 + 1;
    while j <= M && numel(post) < nFit && idx(j) - idx(g2) - 1 <= gapMax + nFit
        if ~inCand(j), post(end+1) = j; end %#ok<AGROW>
        j = j + 1;
    end
    if numel(pre) < 2 || numel(post) < 2
        lev = NaN(g2 - g1 + 1, 3);
        return
    end
    use = [fliplr(pre) post];
    t0 = idx(g1);
    tt = double(idx(use) - t0);
    tr = double(idx(g1:g2) - t0);
    A  = [ones(numel(tt),1) tt(:) tt(:).^2];
    Ar = [ones(numel(tr),1) tr(:) tr(:).^2];
    coef = A \ B(use, :);
    lev = B(g1:g2, :) - Ar * coef - relq * Delta;
end

% ======================================================================
function [unconf, c] = mark_unconfirmed(unconf, c, idx, g1, g2, runMax)
% A step-length span that failed confirmation is flagged (values unchanged).
% A longer offset stretch is the wake of an unclosed edge (usually real flow
% that happened to pass the edge test once); it is counted, not flagged.
    if idx(g2) - idx(g1) + 1 <= runMax
        unconf(g1:g2) = true;
        c.nUnconfirmedRuns = c.nUnconfirmedRuns + 1;
    else
        c.nLongOffsets = c.nLongOffsets + 1;
    end
end

% ======================================================================
function R = runs_of(m)
% [start end] of each run of true in logical column m.
    m = m(:);
    d = diff([false; m; false]);
    R = [find(d == 1), find(d == -1) - 1];
end
