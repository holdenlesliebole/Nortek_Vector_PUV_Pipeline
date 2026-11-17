function T = audit_depth_neighbor_velocity(outCsv, inject)
%AUDIT_DEPTH_NEIGHBOR_VELOCITY  Flag velocity failures that per-channel L1 QC passes,
%   by comparing each instrument's hourly orbital velocity Ub with every other
%   instrument in the same deployment. EXPLORATORY audit (2026-11-17), report-only.
%
%   Motivation: TOR23W MOP586_10m read Ub about 3.5x low for its last 472 segments
%   (2023-12-30 on; Ub10/Ub15 fell from 1.38 to 0.39) while passing L1 QC.
%
%   Rule (fixed before running):
%     - pairs: every pair of records in a deployment's L2 folder;
%     - hourly matched segments where both have segValid_vel and finite Ub > 0.02 m/s;
%     - r = log(Ub_a / Ub_b); pair baseline = median r over all matched hours;
%     - a pair-day is ANOMALOUS when it has >= 12 matched hours and its daily median r
%       departs from the baseline by more than log(1.5);
%     - a FINDING is a run of >= 2 consecutive anomalous pair-days.
%   Sensitivity check (injected signal): the real TOR23W MOP586_10m failure is now
%   gapped in L2 (velInvalidFrom), so it cannot serve as the positive control. With
%   inject = true, the audit multiplies TOR24S MOP586_7m's Ub by 0.3 for 2024-05-01 to
%   2024-05-06 in memory and must report that stretch; the uninjected run must not.
%
%   Output: table of findings (deployment, a, b, first day, last day, n days,
%   median daily ratio vs baseline), written to outCsv if given.

if nargin < 1, outCsv = ''; end
if nargin < 2, inject = false; end
root = fileparts(fileparts(mfilename('fullpath')));
L2root = fullfile(root, 'outputs', 'L2');
deps = dir(L2root); deps = deps([deps.isdir] & ~startsWith({deps.name}, {'.', '_'}));
thr = log(1.5); minHr = 12; minRun = 2;
rows = {};
nPairs = 0;
for d = 1:numel(deps)
    F = dir(fullfile(L2root, deps(d).name, '*_L2.mat'));
    if numel(F) < 2, continue; end
    R = struct('label', {}, 'time', {}, 'Ub', {});
    for f = 1:numel(F)
        S = load(fullfile(F(f).folder, F(f).name), 'L2');
        t = S.L2.time(:); if ~isempty(t.TimeZone), t.TimeZone = 'UTC'; t.TimeZone = ''; end
        ok = S.L2.segValid_vel(:) & isfinite(S.L2.Ub(:)) & S.L2.Ub(:) > 0.02;
        lab = erase(F(f).name, '_L2.mat');
        Ub = S.L2.Ub(:);
        if inject && strcmp(deps(d).name, 'TOR24S') && strcmp(lab, 'MOP586_7m')
            w = t >= datetime(2024,5,1) & t < datetime(2024,5,7);
            Ub(w) = 0.3 * Ub(w);
            fprintf('  INJECTED: TOR24S MOP586_7m Ub x 0.3 on %d segments\n', sum(w));
        end
        R(end+1) = struct('label', erase(F(f).name, '_L2.mat'), 'time', dateshift(t(ok), 'start', 'hour'), ...
                          'Ub', Ub(ok)); %#ok<AGROW>
    end
    for a = 1:numel(R)-1
        for b = a+1:numel(R)
            [tt, ia, ib] = intersect(R(a).time, R(b).time);
            if numel(tt) < 48, continue; end
            nPairs = nPairs + 1;
            r = log(R(a).Ub(ia) ./ R(b).Ub(ib));
            base = median(r);
            nFindBefore = size(rows, 1);
            day = dateshift(tt, 'start', 'day');
            [ud, ~, g] = unique(day);
            dm = accumarray(g, r, [], @median);
            dn = accumarray(g, 1);
            anom = dn >= minHr & abs(dm - base) > thr;
            % runs of consecutive calendar days
            k = 1;
            while k <= numel(ud)
                if ~anom(k), k = k + 1; continue; end
                j = k;
                while j < numel(ud) && anom(j+1) && days(ud(j+1) - ud(j)) == 1, j = j + 1; end
                if j - k + 1 >= minRun
                    rows(end+1, :) = {deps(d).name, R(a).label, R(b).label, ud(k), ud(j), j-k+1, ...
                        exp(base), exp(median(dm(k:j)))}; %#ok<AGROW>
                end
                k = j + 1;
            end
            fprintf('  %-7s %-12s / %-12s  %5d matched h  baseline ratio %.2f  anomalous days %3d  findings %d\n', ...
                deps(d).name, R(a).label, R(b).label, numel(tt), exp(base), sum(anom), size(rows,1) - nFindBefore);
        end
    end
end
if isempty(rows), rows = cell(0, 8); end
T = cell2table(rows, 'VariableNames', {'deployment','a','b','first_day','last_day','n_days', ...
    'baseline_ratio_a_over_b','run_ratio_a_over_b'});
fprintf('audit_depth_neighbor_velocity: %d pairs checked, %d findings\n', nPairs, height(T));
if ~isempty(outCsv), writetable(T, outCsv); end
end
