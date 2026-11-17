function V = validate_beam_step_20261113(dumpDir, recs)
% VALIDATE_BEAM_STEP_20261113  Real-data tests T1-T6 of the L1 beam-step correction.
%
%   V = validate_beam_step_20261113(dumpDir, recs)
%
%   Criteria: docs/SPEC_L1_beam_step_correction_2026-11-13.md section 7, fixed
%   before these were run. Reads corrector inputs dumped by PUV_raw_process with
%   cfg.beamStep.dumpInputTo (files <tag>_input.mat in dumpDir: Xrec, valid_vel,
%   fs, headT, headInfo, tRec). Read-only; writes nothing.
%
%   recs  cellstr of tags to include (default: every *_input.mat in dumpDir)
%
%   2026-11-13. EXPLORATORY.

    if nargin < 2 || isempty(recs)
        d = dir(fullfile(dumpDir, '*_input.mat'));
        recs = erase({d.name}, '_input.mat');
    end
    D1 = 1.508;  winDays = 3;
    V = struct();

    % ---------------- T1 head matrix, and per-record counts with the current rule
    fprintf('\n=== T1 head matrix (hdr vs binary, tol 1e-4) and current-rule counts ===\n');
    nBoth = 0; nAgree = 0;
    for r = 1:numel(recs)
        I = load(fullfile(dumpDir, [recs{r} '_input.mat']));
        h = I.headInfo;
        if strcmp(h.source, 'hdr+vec')
            nBoth = nBoth + 1;  nAgree = nAgree + (h.diffHdrVec <= 1e-4);
        end
        [~, bs] = vector_beam_step_correct(I.Xrec, I.valid_vel, I.fs, I.headT);
        c = bs.counts;
        if isempty(fieldnames(c)), c = struct('nRuns', 0, 'nSamples', 0, 'nUnconfirmedRuns', 0, ...
                'nUnconfirmedSamples', 0, 'nLongOffsets', 0, 'nRunsZeroEdge', 0, 'nRunsOneEdge', 0, ...
                'runLenHist', [0 0 0 0], 'longestRun', 0, 'nRunsDouble', 0, 'nRunsMultiBeam', 0); end
        nv = sum(I.valid_vel);
        fprintf(['  %-20s head %-8s %-8s |dT| %.1e | %-13s Delta %.4f (n %4d, IQR %.3f-%.3f) | ' ...
                 'runs %4d (1:%d 2-3:%d 4-10:%d 11-30:%d; 0-edge %d, 1-edge %d, double %d, 2-beam %d) ' ...
                 '%4d samples = %.1f ppm | unconf %d runs %d samples | unclosed %d\n'], ...
            recs{r}, h.source, h.headSerial, h.diffHdrVec, bs.status, bs.Delta, bs.nDeltaEdges, ...
            bs.DeltaIQR(1), bs.DeltaIQR(2), c.nRuns, c.runLenHist, c.nRunsZeroEdge, c.nRunsOneEdge, ...
            c.nRunsDouble, c.nRunsMultiBeam, c.nSamples, 1e6*c.nSamples/nv, ...
            c.nUnconfirmedRuns, c.nUnconfirmedSamples, c.nLongOffsets);
        V.counts.(matlab.lang.makeValidName(recs{r})) = bs;
    end
    fprintf('  T1: %d/%d records with both sources agree within 1e-4 -> %s\n', ...
        nAgree, nBoth, pf(nAgree == nBoth && nBoth > 0));

    % ---------------- choose bases
    fprintf('\n=== T2 base selection ===\n');
    best = struct('calm', [], 'storm', []);
    for r = 1:numel(recs)
        I = load(fullfile(dumpDir, [recs{r} '_input.mat']));
        W = window_stats(I, winDays);
        for w = 1:numel(W)
            W(w).rec = recs{r};
        end
        if strcmp(recs{r}, 'TOR24S_MOP586_5m')
            best.calm = [best.calm, W([W.fvalid] >= 0.90)];
        end
        best.storm = [best.storm, W([W.fvalid] >= 0.70)];
    end
    [calmI, calmW] = pick_clean(best.calm, 'ascend', dumpDir, D1);
    [stormI, stormW] = pick_clean(best.storm, 'descend', dumpDir, D1);
    fprintf('  calm base : %s %s to %s, sea-swell horiz. var %.4f m^2/s^2, valid %.1f%%\n', ...
        calmW.rec, string(calmI.t(1)), string(calmI.t(end)), calmW.var, 100*calmW.fvalid);
    fprintf('  storm base: %s %s to %s, sea-swell horiz. var %.4f m^2/s^2, valid %.1f%%, max |u_h| %.2f m/s\n', ...
        stormW.rec, string(stormI.t(1)), string(stormI.t(end)), stormW.var, 100*stormW.fvalid, ...
        max(hypot(stormI.X(:,1), stormI.X(:,2))));

    % ---------------- T2
    fprintf('\n=== T2 synthetic closure on real bases ===\n');
    R = beam_step_closure(calmI.X, calmI.v, calmI.fs, calmI.T, struct(), struct('Delta', D1), calmI.T, 'calm');
    show('T2a calm, Delta given', R, R.pass_T2a);
    V.T2a_calm = R;
    R = beam_step_closure(calmI.X, calmI.v, calmI.fs, calmI.T, struct(), struct(), calmI.T, 'calm est');
    show(sprintf('T2b calm, Delta estimated %.4f m/s', R.Delta), R, R.pass_T2b);
    V.T2b_calm = R;
    R = beam_step_closure(stormI.X, stormI.v, stormI.fs, stormI.T, struct(), struct('Delta', D1), stormI.T, 'storm');
    show('T2a storm, Delta given (S7 exception)', R, R.pass_T2a_stormS7exception);
    V.T2a_storm = R;
    R = beam_step_closure(stormI.X, stormI.v, stormI.fs, stormI.T, struct(), struct(), stormI.T, 'storm est');
    show(sprintf('T2b storm, Delta estimated %.4f m/s (reported; T2b criterion)', R.Delta), R, R.pass_T2b);
    V.T2b_storm = R;

    % ---------------- T3
    fprintf('\n=== T3 amplified storm flow, no injections (Delta given 1.508 m/s) ===\n');
    for a = [1.0 1.5 2.0]
        [~, bs] = vector_beam_step_correct(a * stormI.X, stormI.v, stormI.fs, stormI.T, struct('Delta', D1));
        n = sum(any(bs.k ~= 0, 2));
        fprintf('  x%.1f: %d corrected samples, %d unconfirmed samples, %d edges -> %s\n', a, n, ...
            bs.counts.nUnconfirmedSamples, bs.counts.nEdges, pf(n == 0));
        V.T3(round(10*a)) = n;
    end

    % ---------------- T5
    fprintf('\n=== T5 break tests on the calm base (each must fire; unbroken T2a above) ===\n');
    T = calmI.T;
    B = {
        'B1 T columns 1,2 swapped', calmI.X, T, struct('Delta', D1), T(:, [2 1 3]), struct()
        'B2 Delta = 1.0 m/s',        calmI.X, T, struct('Delta', 1.0), T, struct()
        'B3 Z sign flipped',         calmI.X .* [1 1 -1], T .* [1; 1; -1], struct('Delta', D1), T, struct()
        'B4 T rows 1,2 swapped',     calmI.X, T, struct('Delta', D1), T([2 1 3], :), struct()
        'B5 1.30 m/s steps, Delta estimated', calmI.X, T, struct(), T, struct('Dinj', 1.30)
    };
    for b = 1:size(B, 1)
        R = beam_step_closure(B{b,2}, calmI.v, calmI.fs, B{b,3}, B{b,6}, B{b,4}, B{b,5}, B{b,1});
        fires = ~R.pass_T2a;
        if b == 5, fires = fires && strcmp(R.status, 'refused_delta'); end
        fprintf('  %-36s status %-13s exact %d/%d, wrong %d -> fires: %s\n', B{b,1}, R.status, ...
            sum([R.cat.exact]), sum([R.cat.n]), sum([R.cat.wrong]), pf(fires));
    end

    % ---------------- T6 criterion 2 (TOR17C)
    tag = 'TOR17C';
    if any(strcmp(recs, tag))
        fprintf('\n=== T6 criterion 2: TOR17C 2018-03-07 00:00-14:00 UTC (filename clock 03-06 16:00 to 03-07 06:00) ===\n');
        I = load(fullfile(dumpDir, [tag '_input.mat']));
        [Xc, ~] = vector_beam_step_correct(I.Xrec, I.valid_vel, I.fs, I.headT);
        v = I.valid_vel & all(isfinite(I.Xrec), 2);
        b0 = (I.headT \ I.Xrec.').';  b1 = (I.headT \ Xc.').';
        h0 = datetime(2018,3,7,0,0,0);  nOK = 0; nH = 0; maxdm = 0;
        for hh = 0:13
            in = v & I.tRec >= h0 + hours(hh) & I.tRec < h0 + hours(hh+1);
            if ~any(in), continue; end
            nH = nH + 1;
            s0 = mean(abs(b0(in,2)) > 0.9);  s1 = mean(abs(b1(in,2)) > 0.9);
            dm = max(abs(median(b1(in,:)) - median(b0(in,:))));
            maxdm = max(maxdm, dm);
            nOK = nOK + (s1 < 1e-3);
            fprintf('  %s  n %5d  |b2|>0.9 m/s: %6.3f%% -> %6.3f%%   max |d median| %.4f m/s\n', ...
                string(h0 + hours(hh), 'MM-dd HH:mm'), sum(in), 100*s0, 100*s1, dm);
        end
        fprintf('  hours below 0.1%%: %d/%d -> %s; max hourly median change %.4f m/s (< 0.005) -> %s\n', ...
            nOK, nH, pf(nOK == nH), maxdm, pf(maxdm < 0.005));
    end
end

% ======================================================================
function W = window_stats(I, winDays)
% 3-day windows stepped by 1 day: valid fraction and sea-swell (25 s high-pass
% ~ 0.04 Hz up to Nyquist 1 Hz) horizontal velocity variance (recorded X, Y).
    fs = I.fs;  N = size(I.Xrec, 1);  n = round(winDays*86400*fs);  st = round(86400*fs);
    W = struct('i0', {}, 'i1', {}, 'fvalid', {}, 'var', {});
    v = I.valid_vel & all(isfinite(I.Xrec), 2);
    for i0 = 1:st:(N - n + 1)
        j = i0:i0+n-1;
        X = I.Xrec(j, 1:2);  X(~v(j), :) = NaN;
        hp = X - movmean(X, round(25*fs), 1, 'omitnan');
        W(end+1) = struct('i0', i0, 'i1', i0+n-1, 'fvalid', mean(v(j)), ...
            'var', sum(var(hp, 0, 1, 'omitnan'))); %#ok<AGROW>
    end
end

function [B, w] = pick_clean(W, order, dumpDir, D1)
% First window, in order of variance, in which the corrector makes 0 corrections
% and 0 unconfirmed flags (Delta given).
    [~, o] = sort([W.var], order);
    cache = struct();
    for q = o
        w = W(q);  f = matlab.lang.makeValidName(w.rec);
        if ~isfield(cache, f), cache.(f) = load(fullfile(dumpDir, [w.rec '_input.mat'])); end
        I = cache.(f);  j = w.i0:w.i1;
        [~, bs] = vector_beam_step_correct(I.Xrec(j,:), I.valid_vel(j), I.fs, I.headT, struct('Delta', D1));
        if ~any(bs.k(:)) && ~any(bs.unconfirmed)
            B = struct('X', I.Xrec(j,:), 'v', I.valid_vel(j), 'fs', I.fs, 'T', I.headT, 't', I.tRec(j));
            return
        end
        fprintf('  (skipped %s window %d: %d corrected, %d unconfirmed)\n', w.rec, w.i0, ...
            sum(any(bs.k ~= 0, 2)), sum(bs.unconfirmed));
    end
    error('validate_beam_step:noBase', 'No clean window.');
end

function show(name, R, pass)
    fprintf('  [%s] %s\n        ', pf(pass), name);
    for c = 1:numel(R.cat)
        fprintf('%s %d/%d', R.cat(c).name, R.cat(c).exact, R.cat(c).n);
        if R.cat(c).unconfirmed, fprintf(' (+%d unconf)', R.cat(c).unconfirmed); end
        if R.cat(c).wrong, fprintf(' (%d WRONG)', R.cat(c).wrong); end
        if R.cat(c).missed, fprintf(' (%d missed)', R.cat(c).missed); end
        fprintf('; ');
    end
    fprintf('\n        false flags %d, untouched bitwise %d, max err %.2e m/s, Delta %.4f, status %s\n', ...
        R.nFalseFlagSamples, R.untouchedBitwise, R.maxErr, R.Delta, R.status);
end

function s = pf(b)
    if b, s = 'PASS'; else, s = 'FAIL'; end
end
