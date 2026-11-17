function R = closure_diff_TBR23_20261113(oldRoot, newRoot)
% CLOSURE_DIFF_TBR23_20261113  Paper 1 closure diff after the beam-step rebuild (HLB decision 5).
%
%   R = closure_diff_TBR23_20261113(oldRoot, newRoot)
%
%   Compares every field of the four TBR23 L2 files, segment by segment:
%     oldRoot  the pre-rebuild snapshot (outputs/_pre_beamstep_TBR23_2026-11-13)
%     newRoot  outputs/ after the rebuild
%   HLB's expectation (2026-11-13): TBR23 L2 matches the current build field for
%   field except MOP586_5m segment 916 and anything the detector adds. The current
%   TBR23 L2 was built 2026-11-12 from 2571829 (swart-amplitude-20261111, dirty
%   tree), so it ALREADY carries T_b and Swart: the bed-stress fields (tau_b,
%   fric_w, Aw, Tb, ...) are judged against IDENTICAL like every other field. A
%   difference outside the allowed segments means the dirty tree differed from
%   2571829 or the merge changed something: a finding, not an expected change.
%   ALLOWED segments are derived from the NEW L1 itself: every L2 segment that
%   holds a sample with qc.vel_beamstep_k ~= 0 or qc.vel_beamstep_unconfirmed.
%
%   For each record and field: number of segments that differ (isequaln per
%   column for [nf x nSeg] arrays, per element for [nSeg x 1]), which segments,
%   and the max absolute difference. Prints a table; returns a struct.
%   Read-only. 2026-11-13.

    if nargin < 1 || isempty(oldRoot)
        oldRoot = '/Users/holden/LocalData/Scripps/Research/PUV_Pipeline/outputs/_pre_beamstep_TBR23_2026-11-13';
    end
    if nargin < 2 || isempty(newRoot)
        newRoot = '/Users/holden/LocalData/Scripps/Research/PUV_Pipeline/outputs';
    end
    BEDSTRESS = {'tau_b', 'fric_w', 'Aw', 'Tb', 'uBed_rms', 'vBed_rms', 'Ub'};   % reported as a family; judged identical
    SKIP = {'prov', 'params'};                 % provenance and option echo: reported only
    labs = {'MOP580_5m', 'MOP580_7m', 'MOP586_5m', 'MOP586_7m'};
    R = struct();
    for i = 1:numel(labs)
        a = load(fullfile(oldRoot, 'L2', 'TBR23', [labs{i} '_L2.mat']), 'L2');  A = a.L2;
        b = load(fullfile(newRoot, 'L2', 'TBR23', [labs{i} '_L2.mat']), 'L2');  B = b.L2;
        nSeg = numel(A.time);
        % allowed segments from the new L1 (0-based, on the L2 time grid)
        q = load(fullfile(newRoot, 'L1', 'TBR23', [labs{i} '_processed.mat']), 'PUV');
        hitS = any(q.PUV.qc.vel_beamstep_k ~= 0, 2) | q.PUV.qc.vel_beamstep_unconfirmed(:);
        th = q.PUV.time(hitS);  clear q
        tA = A.time;  if ~isempty(tA.TimeZone), tA.TimeZone = ''; end
        if ~isempty(th) && ~isempty(th.TimeZone), th.TimeZone = ''; end
        allowed = [];
        for z = 1:numel(th)
            [dt, j] = min(abs(tA - th(z)));
            if dt <= minutes(30), allowed(end+1) = j - 1; end %#ok<AGROW>
        end
        allowed = unique(allowed);
        fprintf('    allowed segments (new L1 corrected/unconfirmed samples): %s\n', seg_list(allowed));
        fprintf('\n=== TBR23 %s: %d segments old, %d new; time grid identical: %d\n', ...
            labs{i}, nSeg, numel(B.time), isequal(A.time, B.time));
        rows = {};
        flat = @(S) flatten(S, '');
        FA = flat(A);  FB = flat(B);
        allf = union(fieldnames(FA), fieldnames(FB));
        for f = allf'
            k = f{1};
            if ~isfield(FA, k), rows(end+1,:) = {k, 'NEW FIELD', NaN, '', NaN, 'new field'}; continue, end %#ok<AGROW>
            if ~isfield(FB, k), rows(end+1,:) = {k, 'REMOVED', NaN, '', NaN, 'UNEXPECTED (removed)'}; continue, end %#ok<AGROW>
            x = FA.(k);  y = FB.(k);
            if any(startsWith(k, SKIP)), continue, end
            [segs, dmax] = seg_diff(x, y, nSeg);
            if isempty(segs) && isequaln(x, y), continue, end
            fam = 'other';
            if any(startsWith(k, BEDSTRESS)), fam = 'bed-stress/orbital'; end
            if isequal(segs, -1)
                verdict = 'UNEXPECTED (whole field)';
            elseif all(ismember(segs, allowed))
                verdict = 'allowed';
            else
                verdict = sprintf('UNEXPECTED (%d outside allowed)', sum(~ismember(segs, allowed)));
            end
            rows(end+1,:) = {k, fam, numel(segs), seg_list(segs), dmax, verdict}; %#ok<AGROW>
        end
        nF = numel(allf);  nU = 0;
        for r = 1:size(rows, 1)
            fprintf('  %-28s %-20s %4g/%d segments differ  %-30s max|d| %-9.3g %s\n', ...
                rows{r,1}, rows{r,2}, rows{r,3}, nSeg, rows{r,4}, rows{r,5}, rows{r,6});
            nU = nU + startsWith(rows{r,6}, 'UNEXPECTED');
        end
        % per-family identical counts for the bed-stress fields
        for b = BEDSTRESS
            if isfield(FA, b{1}) && isfield(FB, b{1})
                [sg, ~] = seg_diff(FA.(b{1}), FB.(b{1}), nSeg);
                if ~isequal(sg, -1), fprintf('    %-10s %d/%d segments identical\n', b{1}, nSeg - numel(sg), nSeg); end
            end
        end
        fprintf('  SUMMARY %s: %d fields compared (prov, params skipped), %d differ, %d UNEXPECTED\n', ...
            labs{i}, nF, size(rows, 1), nU);
        R.(labs{i}) = rows;
    end
end

% ----------------------------------------------------------------------
function F = flatten(S, pre)
% Struct -> flat struct of non-struct leaves, names joined by '__'.
    F = struct();
    for f = fieldnames(S)'
        v = S.(f{1});  k = [pre f{1}];
        if isstruct(v) && isscalar(v)
            G = flatten(v, [k '__']);
            for g = fieldnames(G)', F.(g{1}) = G.(g{1}); end
        else
            F.(k) = v;
        end
    end
end

function [segs, dmax] = seg_diff(x, y, nSeg)
    segs = [];  dmax = NaN;
    if ~isequal(size(x), size(y)) || ~(isnumeric(x) || islogical(x) || isdatetime(x)) || ...
            ~(isnumeric(y) || islogical(y) || isdatetime(y))
        if ~isequaln(x, y), segs = -1; end    % non-numeric or reshaped: flagged whole
        return
    end
    if isdatetime(x), x = posixtime(x); y = posixtime(y); end
    x = double(x);  y = double(y);
    if size(x, 1) == nSeg && size(x, 2) ~= nSeg, x = x.'; y = y.'; end
    if size(x, 2) ~= nSeg
        if ~isequaln(x, y), segs = -1; dmax = max(abs(x(:) - y(:)), [], 'omitnan'); end
        return
    end
    d = ~(x == y | (isnan(x) & isnan(y)));
    segs = find(any(d, 1)) - 1;               % 0-based segment indices
    if ~isempty(segs), dmax = max(abs(x(d) - y(d)), [], 'omitnan'); end
end

function s = seg_list(segs)
    if isempty(segs), s = ''; elseif isequal(segs, -1), s = '(whole field)';
    elseif numel(segs) <= 6, s = ['0-based: ' char(strjoin(string(segs), ' '))];
    else, s = sprintf('0-based: %d ... %d (%d)', segs(1), segs(end), numel(segs)); end
end
