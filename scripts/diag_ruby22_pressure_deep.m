% DIAG_RUBY22_PRESSURE_DEEP  Deeper look at why our L1 P median = 48.7 dBar
% when raw .dat column 15 median is ~6.75 dBar.
%
% Hypothesis space:
%   (a) DAT array is filling gaps with non-NaN garbage
%   (b) QC is preferentially keeping high-pressure outliers
%   (c) Burst alignment is double-writing the same indices
%   (d) The .dat parser is reading wrong columns
% Author: Holden Leslie-Bole, 2026

%% Load our L1 directly
fprintf('=== Our L1 P field ===\n');
S = load('outputs/L1/RUBY22/MOP579_6m_processed.mat');
PUV = S.PUV;
P = PUV.P;
pV = P(~isnan(P));
fprintf('total samples = %d\n', numel(P));
fprintf('valid (non-NaN) = %d  (%.1f%%)\n', numel(pV), 100*numel(pV)/numel(P));
fprintf('histogram of valid P:\n');
edges = [0 0.5 1 2 3 5 7 10 15 20 30 50 75 100 200];
h = histcounts(pV, edges);
for k = 1:numel(h)
    fprintf('  [%6.2f, %6.2f) : %10d  (%5.1f%%)\n', ...
        edges(k), edges(k+1), h(k), 100*h(k)/numel(pV));
end
fprintf('quantiles:\n');
qs = [0.01 0.05 0.10 0.25 0.50 0.75 0.90 0.95 0.99];
qv = quantile(pV, qs);
for k = 1:numel(qs)
    fprintf('  q%.0f = %.2f dBar\n', 100*qs(k), qv(k));
end

%% Directly load one raw .dat and parse column 15
fprintf('\n=== Raw .dat column 15 (file 1) ===\n');
df = '/Volumes/group/PUV_data/Vector/recopied/Ruby2D_2021-2022/16737_MOP579_6m/TORREY16737_1.dat';
fid = fopen(df,'r');
raw = textscan(fid, repmat('%f',1,18), 'CollectOutput', true);
fclose(fid);
M = raw{1};
fprintf('size(M) = [%d, %d]\n', size(M,1), size(M,2));
P_raw = M(:,15);
fprintf('column 15: min=%.3f, q25=%.3f, median=%.3f, q75=%.3f, max=%.3f\n', ...
    min(P_raw), quantile(P_raw,0.25), median(P_raw), quantile(P_raw,0.75), max(P_raw));
fprintf('column 15 > 100: count = %d\n', sum(P_raw>100));
fprintf('column 15 > 50:  count = %d\n', sum(P_raw>50));

%% Check time array of L1 P
if isfield(PUV,'time')
    t = PUV.time;
    fprintf('\n=== Our L1 time array ===\n');
    fprintf('n = %d, %s to %s\n', numel(t), char(t(1)), char(t(end)));
    fprintf('span = %.2f days\n', days(t(end) - t(1)));
end

%% Check the underlying QC process by reloading raw and partially replicating
% Load raw + apply just the basic pressure-domain checks WITHOUT QC
fprintf('\n=== Reloading all 4 raw .dat files, concatenate column 15 ===\n');
allP = [];
for ii = 1:4
    df = sprintf('/Volumes/group/PUV_data/Vector/recopied/Ruby2D_2021-2022/16737_MOP579_6m/TORREY16737_%d.dat', ii);
    if ~isfile(df), continue; end
    fid = fopen(df,'r');
    raw = textscan(fid, repmat('%f',1,18), 'CollectOutput', true);
    fclose(fid);
    M = raw{1};
    fprintf('  burst %d: %d samples, col-15 median %.3f, max %.3f\n', ...
        ii, size(M,1), median(M(:,15)), max(M(:,15)));
    allP = [allP; M(:,15)]; %#ok<AGROW>
end
fprintf('Concat: n=%d, min=%.3f, median=%.3f, max=%.3f\n', ...
    numel(allP), min(allP), median(allP), max(allP));
qs = [0.01 0.05 0.10 0.25 0.50 0.75 0.90 0.95 0.99];
qv = quantile(allP, qs);
for k = 1:numel(qs)
    fprintf('  q%.0f = %.2f dBar\n', 100*qs(k), qv(k));
end
