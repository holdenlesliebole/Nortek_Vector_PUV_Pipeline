function L4pdf = PUV_L4_velocity_pdf(PUV, L2, opts)
% PUV_L4_velocity_pdf  Pooled onshore/offshore velocity histograms.
%
%   L4pdf = PUV_L4_velocity_pdf(PUV, L2)
%   L4pdf = PUV_L4_velocity_pdf(PUV, L2, opts)
%
%   Implements Bill O'Reilly's MOP511 Fig. 10 distributional anatomy:
%   pool all 2-Hz cross-shore velocity samples from valid hourly
%   segments after hourly detrending, separate onshore (u>0) and
%   offshore (u<0) absolute values, and find the |u| at which N_on
%   crosses N_off. This crossover sits above <|u|> and may carry
%   climatological significance for transport thresholds (cf. Shields
%   for medium sand at ~0.25 mm).
%
%   INPUTS
%     PUV   - L1 struct with .BuoyCoord.U, .BuoyCoord.V, .time, .fs
%     L2    - L2 struct with .time, .segValid, .shorenormal,
%             .params.segLen (samples per segment)
%     opts  - optional struct
%             .edgesAbs   |u| histogram edges (default 0:0.01:2)
%             .detrend    detrend each segment before pooling (default true)
%
%   OUTPUT (struct L4pdf)
%     .edges            (1 x nE) |u| bin edges
%     .centers          (1 x nE-1)
%     .N_on, .N_off     pooled counts
%     .diff             N_on - N_off
%     .weighted         centers .* diff   (Fig 10 right panel)
%     .cum              cumsum(weighted)  (should end ~0 by detrending)
%     .crossover_u      |u| where N_on first exceeds N_off above mean(|u|)
%     .mean_absU        mean of pooled |u|
%     .n_segments_used  number of valid hourly segments contributing
%     .opts             resolved options
%
%   Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
if ~isfield(opts, 'edgesAbs'), opts.edgesAbs = 0:0.01:2; end
if ~isfield(opts, 'detrend'),  opts.detrend  = true;    end

edges   = opts.edgesAbs;
centers = 0.5 * (edges(1:end-1) + edges(2:end));
nBins   = numel(centers);

% --- rotate full L1 timeseries to shore-normal once ---
[u, ~] = apply_shorenormal_rotation(PUV.BuoyCoord.U, PUV.BuoyCoord.V, L2.shorenormal);

% --- align L2 segment indexing with L1 samples (matches PUV_L2_spectral) ---
fs     = PUV.fs;
segLen = L2.params.segLen;
N      = numel(u);

% Find the start offset so segment centers land on HH:00:00 — replicate
% the L2 alignment by snapping the first segment to start at the first
% sample whose time is on the hour.
startOffset = local_align_start(PUV.time, fs, segLen);

nSegMax = floor((N - startOffset) / segLen);
nSeg    = min(nSegMax, numel(L2.segValid));
valid   = L2.segValid(1:nSeg);

% --- accumulate pooled counts ---
Non  = zeros(1, nBins);
Noff = zeros(1, nBins);
nUsed = 0;

for i = 1:nSeg
    if ~valid(i), continue; end
    idx = startOffset + ((i-1)*segLen + 1 : i*segLen);
    seg = u(idx);
    if any(isnan(seg)), continue; end
    if opts.detrend, seg = detrend(seg); end

    pos =  seg(seg > 0);
    neg = -seg(seg < 0);          % absolute value
    Non  = Non  + histcounts(pos, edges);
    Noff = Noff + histcounts(neg, edges);
    nUsed = nUsed + 1;
end

% --- derived quantities ---
diffN     = Non - Noff;
weighted  = centers .* diffN;
cum       = cumsum(weighted);

totalCounts = Non + Noff;
meanAbsU = sum(centers .* totalCounts) / max(sum(totalCounts), 1);

% Crossover: first |u| above meanAbsU where diffN transitions from <0 to >0.
crossover = NaN;
iMean = find(centers >= meanAbsU, 1, 'first');
if ~isempty(iMean)
    sgn = sign(diffN(iMean:end));
    zc  = find(sgn(1:end-1) < 0 & sgn(2:end) > 0, 1, 'first');
    if ~isempty(zc), crossover = centers(iMean + zc - 1); end
end

% --- pack ---
L4pdf = struct();
L4pdf.edges            = edges;
L4pdf.centers          = centers;
L4pdf.N_on             = Non;
L4pdf.N_off            = Noff;
L4pdf.diff             = diffN;
L4pdf.weighted         = weighted;
L4pdf.cum              = cum;
L4pdf.crossover_u      = crossover;
L4pdf.mean_absU        = meanAbsU;
L4pdf.n_segments_used  = nUsed;
L4pdf.opts             = opts;
end

% ============================================================
function startOffset = local_align_start(timeVec, fs, ~)
% Mirror PUV_L2_spectral segment alignment so the same hourly segments
% are sampled here. Track if L2 logic changes.
if isempty(timeVec)
    startOffset = 0; return
end
if isempty(timeVec.TimeZone), timeVec.TimeZone = 'UTC'; end
nextHr    = dateshift(timeVec(1), 'end', 'hour');
offsetSec = seconds(nextHr - timeVec(1));
if offsetSec < 1/(2*fs)
    startOffset = 0;
else
    startOffset = round(offsetSec * fs);
end
end
