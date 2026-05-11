function L4xs = PUV_L4_xspec(L4list, opts)
% PUV_L4_xspec  Pairwise IG-band cross-spectra across co-deployed instruments.
%
%   L4xs = PUV_L4_xspec(L4list)
%   L4xs = PUV_L4_xspec(L4list, opts)
%
%   For every pair of instruments in a single deployment, identifies time-
%   matched valid L2 segments and estimates the cross-spectrum on the
%   IG-band surface elevation timeseries (L4.eta.eta_ig) using Welch's
%   method with sub-segments. Outputs cross-spectrum S_ij(f), the two
%   auto-spectra S_ii and S_jj, magnitude-squared coherence coh^2(f), and
%   cross-phase phi(f) per pair and per segment. Aggregated time-mean
%   coherence and power-weighted mean phase are also reported, alongside
%   pair geometry (alongshore and cross-shore separation in each pair's
%   mean shore-normal frame).
%
%   INPUTS
%     L4list  - cell array of paths to *_L4.mat files, OR cell array of
%               L4 structs, OR struct array of L4 structs. All entries
%               must belong to the same deployment and share fs.
%     opts    - optional struct
%               .bandIG     [fmin fmax] Hz   (default [0.004 0.04])
%               .nfftSub    Welch sub-segment length (default 1024)
%               .overlap    sub-segment overlap fraction (default 0.5)
%               .window     window handle taking nfft  (default @hann)
%               .minOverlapFrac minimum overlap fraction for a paired
%                                segment to be retained (default 0.5).
%                                Computed relative to the shorter of the
%                                two segLens.
%               .savePerSeg keep per-segment Sij/coh^2/phase (default true)
%
%   OUTPUT (struct L4xs)
%     L4xs.deploymentName
%     L4xs.builtAt
%     L4xs.bandIG, fs, nfftSub, overlap
%     L4xs.fIG          - (nfIG x 1) Welch-grid IG band frequencies (Hz)
%     L4xs.instruments  - struct array (per instrument):
%                         .label, .latlon, .shorenormal, .medDepth
%     L4xs.pairs        - struct array (one per pair i<j):
%       .iIdx, .jIdx                 indices into L4xs.instruments
%       .labels                      {1x2 cellstr}
%       .latlon_i, .latlon_j         [lat, lon]
%       .depth_i_mean, .depth_j_mean median depth over matched segments (m)
%       .sep_crossshore              shorenormal +onshore separation (m), j-i
%       .sep_alongshore              alongshore +north separation (m), j-i
%       .sep_total                   Euclidean separation (m)
%       .shorenormal_pair            mean shorenormal angle used (deg)
%       .time                        (nMatched x 1) segment start datetimes
%       .nMatched                    scalar
%       .edof_per_seg                effective DOF per Welch estimate
%       .S_ii, .S_jj                 (nfIG x nMatched) one-sided PSDs (m^2/Hz)
%       .S_ij                        (nfIG x nMatched) complex cross-PSD
%       .coh2                        (nfIG x nMatched) magnitude-squared
%                                    coherence
%       .phase                       (nfIG x nMatched) cross-phase (rad)
%       .mean_coh2_f                 (nfIG x 1) time-mean coh^2 per freq
%       .mean_coh2_IG                scalar — band-mean of time-mean coh^2
%       .mean_phase_f                (nfIG x 1) power-weighted mean phase (rad)
%       .mean_phase_IG               scalar — band-mean power-weighted phase
%
%   NOTES
%     - eta_ig has already been bandpassed to bandIG inside PUV_L4_eta;
%       coherence is therefore well-defined only inside that band.
%     - cross-phase phi convention: phi = angle(S_ij) = angle(<X* . Y>);
%       phi > 0 means signal j leads signal i.
%     - Geometry: latitudes/longitudes are converted to local (east, north)
%       meters and rotated into the pair's mean shore-normal frame using
%       apply_shorenormal_rotation. sep_crossshore is positive when j is
%       onshore of i, sep_alongshore is positive when j is north of i.
%     - Segment alignment: L2 segmentation is per-instrument and does not
%       in general start at the same wall-clock time. For each A-segment
%       we find the B-segment whose time window overlaps it most, then
%       take only the common overlapping samples from each segment's
%       eta_ig before computing the Welch cross-spectrum. Segments are
%       retained only if the overlap exceeds opts.minOverlapFrac of the
%       shorter segLen (default 50%).
%
%   REQUIRES
%     apply_shorenormal_rotation.m on the MATLAB path. Signal Processing
%     Toolbox (cpsd).
% Author: Holden Leslie-Bole, 2026

if nargin < 2, opts = struct(); end
if ~isfield(opts, 'bandIG'),     opts.bandIG     = [0.004, 0.04]; end
if ~isfield(opts, 'nfftSub'),    opts.nfftSub    = 1024;          end
if ~isfield(opts, 'overlap'),    opts.overlap    = 0.5;           end
if ~isfield(opts, 'window'),     opts.window     = @hann;         end
if ~isfield(opts, 'minOverlapFrac'), opts.minOverlapFrac = 0.5;  end
if ~isfield(opts, 'savePerSeg'),     opts.savePerSeg     = true; end

% --- Load L4 structs ---
L4s = normalize_L4list(L4list);
nInstr = numel(L4s);
if nInstr < 2
    error('PUV_L4_xspec:tooFewInstruments', ...
        'Need at least 2 instruments; got %d.', nInstr);
end

% --- Sanity: same deployment, same fs ---
fs = L4s{1}.eta.fs;
depName = L4s{1}.deploymentName;
for k = 2:nInstr
    if L4s{k}.eta.fs ~= fs
        error('PUV_L4_xspec:fsMismatch', ...
            'fs mismatch: %s=%g Hz vs %s=%g Hz', ...
            L4s{1}.label, fs, L4s{k}.label, L4s{k}.eta.fs);
    end
    if ~strcmp(L4s{k}.deploymentName, depName)
        warning('PUV_L4_xspec:deployMix', ...
            'Instruments span multiple deployments: %s vs %s', ...
            depName, L4s{k}.deploymentName);
    end
end

% --- Welch frequency grid (one-sided) ---
nfftSub = opts.nfftSub;
fAll    = (0:nfftSub/2)' * fs / nfftSub;
igMask  = (fAll >= opts.bandIG(1)) & (fAll <= opts.bandIG(2));
fIG     = fAll(igMask);
nfIG    = numel(fIG);
if nfIG == 0
    error('PUV_L4_xspec:emptyBand', ...
        'Welch grid (df=%.4g Hz) contains no bins in band [%.4g, %.4g] Hz.', ...
        fs/nfftSub, opts.bandIG(1), opts.bandIG(2));
end

win   = opts.window(nfftSub);
nover = round(opts.overlap * nfftSub);

% --- Output skeleton ---
L4xs.deploymentName = depName;
L4xs.builtAt        = datetime('now');
L4xs.bandIG         = opts.bandIG;
L4xs.fs             = fs;
L4xs.nfftSub        = nfftSub;
L4xs.overlap        = opts.overlap;
L4xs.fIG            = fIG;
L4xs.savePerSeg     = opts.savePerSeg;

L4xs.instruments = repmat(struct('label', '', 'latlon', [], ...
                                 'shorenormal', NaN, 'medDepth', NaN), nInstr, 1);
for k = 1:nInstr
    L4xs.instruments(k).label       = L4s{k}.label;
    L4xs.instruments(k).latlon      = L4s{k}.LATLON;
    L4xs.instruments(k).shorenormal = L4s{k}.shorenormal;
    L4xs.instruments(k).medDepth    = median(L4s{k}.eta.depth, 'omitnan');
end

% --- Pair loop ---
nPairs = nInstr * (nInstr - 1) / 2;
pairs  = cell(nPairs, 1);
p      = 0;

for i = 1:nInstr-1
    for j = i+1:nInstr
        p = p + 1;
        L4i = L4s{i};
        L4j = L4s{j};

        % Segment validity = L2 segValid AND no NaN in eta_ig column
        vi = L4i.eta.segValid(:) & ~any(isnan(L4i.eta.eta_ig), 1).';
        vj = L4j.eta.segValid(:) & ~any(isnan(L4j.eta.eta_ig), 1).';

        idxVi = find(vi);
        idxVj = find(vj);

        segLenI = L4i.eta.segLen;
        segLenJ = L4j.eta.segLen;
        if L4i.eta.fs ~= L4j.eta.fs
            error('PUV_L4_xspec:fsMismatch', 'pair %d fs mismatch', p);
        end
        fsPair = L4i.eta.fs;

        [mi, mj, startI, startJ, lenOv] = match_overlapping_segments(...
            L4i.eta.time(idxVi), segLenI, ...
            L4j.eta.time(idxVj), segLenJ, ...
            fsPair, opts.minOverlapFrac, nfftSub);

        idx_i    = idxVi(mi);
        idx_j    = idxVj(mj);
        nMatched = numel(idx_i);

        % --- Pair geometry: latlon → east/north → shorenormal frame ---
        latI = L4i.LATLON(1); lonI = L4i.LATLON(2);
        latJ = L4j.LATLON(1); lonJ = L4j.LATLON(2);
        meanLat   = (latI + latJ) / 2;
        dx_east   = (lonJ - lonI) * cosd(meanLat) * 111320;
        dy_north  = (latJ - latI) * 111320;
        snVals    = [L4i.shorenormal, L4j.shorenormal];
        snPair    = mean(snVals(~isnan(snVals)));
        if isnan(snPair), snPair = 0; end
        % apply_shorenormal_rotation expects (+x WEST, +y NORTH) input
        [sepCross, sepAlong] = apply_shorenormal_rotation(-dx_east, dy_north, snPair);
        sepTotal  = hypot(sepCross, sepAlong);

        % --- Allocate per-segment outputs ---
        S_ii  = NaN(nfIG, nMatched);
        S_jj  = NaN(nfIG, nMatched);
        S_ij  = complex(NaN(nfIG, nMatched));
        coh2  = NaN(nfIG, nMatched);
        phase = NaN(nfIG, nMatched);

        % --- Per-segment Welch cross-spectrum ---
        for m = 1:nMatched
            iA = startI(m);
            iB = startJ(m);
            L  = lenOv(m);
            x  = L4i.eta.eta_ig(iA:iA+L-1, idx_i(m));
            y  = L4j.eta.eta_ig(iB:iB+L-1, idx_j(m));

            % cpsd returns one-sided cross-PSD (units m^2/Hz) and freq grid
            Pij = cpsd(x, y, win, nover, nfftSub, fs);
            Pii = cpsd(x, x, win, nover, nfftSub, fs);
            Pjj = cpsd(y, y, win, nover, nfftSub, fs);

            S_ii(:, m) = real(Pii(igMask));
            S_jj(:, m) = real(Pjj(igMask));
            S_ij(:, m) = Pij(igMask);

            denom = S_ii(:, m) .* S_jj(:, m);
            ok    = denom > 0;
            coh2(ok, m)  = abs(S_ij(ok, m)).^2 ./ denom(ok);
            phase(:, m)  = angle(S_ij(:, m));
        end

        % --- Aggregates ---
        mean_coh2_f = mean(coh2, 2, 'omitnan');
        % Band-mean of time-mean coh^2 (linear average over IG bins)
        mean_coh2_IG = mean(mean_coh2_f, 'omitnan');

        % Power-weighted mean phase per freq: angle of <S_ij> over time
        complex_sum_t = sum(S_ij, 2, 'omitnan');
        mean_phase_f  = angle(complex_sum_t);

        % Band-aggregated power-weighted mean phase
        complex_sum_all = sum(S_ij(:), 'omitnan');
        mean_phase_IG   = angle(complex_sum_all);

        % --- EDOF estimate per Welch segment (rule of thumb) ---
        segLen        = L4i.eta.segLen;
        K_sub         = floor((segLen - nfftSub) / (nfftSub - nover)) + 1;
        edof_per_seg  = 2 * K_sub;

        % --- Pack ---
        thisPair.iIdx              = i;
        thisPair.jIdx              = j;
        thisPair.labels            = {L4i.label, L4j.label};
        thisPair.latlon_i          = L4i.LATLON;
        thisPair.latlon_j          = L4j.LATLON;
        if nMatched > 0
            thisPair.depth_i_mean = median(L4i.eta.depth(idx_i), 'omitnan');
            thisPair.depth_j_mean = median(L4j.eta.depth(idx_j), 'omitnan');
            % overlap window midpoint (in i's clock; j is within timeTol)
            overlapMid = L4i.eta.time(idx_i) + seconds((startI - 1 + lenOv/2) / fsPair);
            thisPair.time = overlapMid;
            thisPair.overlap_len = lenOv;
        else
            thisPair.depth_i_mean = NaN;
            thisPair.depth_j_mean = NaN;
            thisPair.time         = NaT(0,1);
            thisPair.overlap_len  = zeros(0,1);
        end
        thisPair.sep_crossshore   = sepCross;
        thisPair.sep_alongshore   = sepAlong;
        thisPair.sep_total        = sepTotal;
        thisPair.shorenormal_pair = snPair;
        thisPair.nMatched         = nMatched;
        thisPair.edof_per_seg     = edof_per_seg;

        if opts.savePerSeg
            thisPair.S_ii  = S_ii;
            thisPair.S_jj  = S_jj;
            thisPair.S_ij  = S_ij;
            thisPair.coh2  = coh2;
            thisPair.phase = phase;
        end
        thisPair.mean_coh2_f   = mean_coh2_f;
        thisPair.mean_coh2_IG  = mean_coh2_IG;
        thisPair.mean_phase_f  = mean_phase_f;
        thisPair.mean_phase_IG = mean_phase_IG;

        pairs{p} = thisPair;
    end
end

L4xs.pairs = [pairs{:}].';
end


%% ---------- helpers ----------

function L4s = normalize_L4list(L4list)
% Accept cell of paths/structs OR struct array of L4 structs; return cell of structs.
if iscell(L4list)
    L4s = cell(numel(L4list), 1);
    for k = 1:numel(L4list)
        item = L4list{k};
        if isstruct(item)
            L4s{k} = item;
        elseif ischar(item) || isstring(item)
            loaded = load(char(item), 'L4');
            L4s{k} = loaded.L4;
        else
            error('PUV_L4_xspec:badInput', ...
                'L4list{%d} is neither struct nor path.', k);
        end
    end
elseif isstruct(L4list)
    L4s = num2cell(L4list);
    L4s = L4s(:);
else
    error('PUV_L4_xspec:badInput', ...
        'L4list must be a cell array or struct array.');
end
end


function [mi, mj, startI, startJ, lenOv] = match_overlapping_segments(...
    ti, segLenI, tj, segLenJ, fs, minOverlapFrac, nfftMin)
% For each i-segment (start time ti, length segLenI samples at fs Hz),
% find the j-segment with greatest temporal overlap. Return retained
% pair indices and the sub-window indices/length within each segment.
%
%   minOverlapFrac : minimum overlap fraction relative to shorter segment
%   nfftMin        : minimum allowed overlap length (samples)
ti = ti(:);
tj = tj(:);

if isempty(ti) || isempty(tj)
    mi = zeros(0,1); mj = zeros(0,1);
    startI = zeros(0,1); startJ = zeros(0,1); lenOv = zeros(0,1);
    return
end

tiStart_s = posixtime(ti);
tiEnd_s   = tiStart_s + segLenI / fs;
tjStart_s = posixtime(tj);
tjEnd_s   = tjStart_s + segLenJ / fs;

minLen   = min(segLenI, segLenJ);
minSamp  = max(nfftMin, ceil(minOverlapFrac * minLen));

mi = zeros(numel(ti), 1);
mj = zeros(numel(ti), 1);
startI = zeros(numel(ti), 1);
startJ = zeros(numel(ti), 1);
lenOv  = zeros(numel(ti), 1);
n      = 0;

for k = 1:numel(ti)
    % overlap with every j-segment
    ovStart = max(tiStart_s(k), tjStart_s);
    ovEnd   = min(tiEnd_s(k),   tjEnd_s);
    ovDur   = max(0, ovEnd - ovStart);
    [bestDur, jbest] = max(ovDur);
    if bestDur <= 0, continue, end

    ovStart_best = max(tiStart_s(k), tjStart_s(jbest));
    ovEnd_best   = min(tiEnd_s(k),   tjEnd_s(jbest));

    % sample indices (1-based) within each segment
    siA = round((ovStart_best - tiStart_s(k))     * fs) + 1;
    siB = round((ovStart_best - tjStart_s(jbest)) * fs) + 1;
    L   = round((ovEnd_best   - ovStart_best)     * fs);

    % clip to segment bounds
    siA = max(siA, 1);
    siB = max(siB, 1);
    L   = min(L, segLenI - siA + 1);
    L   = min(L, segLenJ - siB + 1);

    if L < minSamp, continue, end

    n = n + 1;
    mi(n) = k;
    mj(n) = jbest;
    startI(n) = siA;
    startJ(n) = siB;
    lenOv(n)  = L;
end

mi = mi(1:n);
mj = mj(1:n);
startI = startI(1:n);
startJ = startJ(1:n);
lenOv  = lenOv(1:n);
end
