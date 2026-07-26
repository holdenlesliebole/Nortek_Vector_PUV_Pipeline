function L4bisp = PUV_L4_bispectra(eta, L2, opts)
% PUV_L4_bispectra  Per-segment bispectrum, bicoherence, and coupling metrics.
%
%   L4bisp = PUV_L4_bispectra(eta, L2)
%   L4bisp = PUV_L4_bispectra(eta, L2, opts)
%
%   For each L2 segment, splits the segLen-sample eta record into K
%   overlapping sub-segments of length opts.nfft (default 2048, 50%
%   overlap), runs bispectrum.m on each sub-segment, and averages the
%   complex bispectrum and the PSD across sub-segments. Bicoherence and
%   biphase are recomputed from the averaged quantities so the
%   normalisation is consistent.
%
%   Sub-segment averaging dramatically inflates the effective DOF
%   (edof_total = K * mg * 2 ≈ 60 for the defaults) without paying the
%   memory cost of running bispectrum on the full segLen=7200 record
%   (which allocates 52M-entry index matrices).
%
%   Inputs default to processing eta_total from PUV_L4_eta. Standard
%   coastal-bispectrum analyses (Elgar & Guza 1985; Ruessink et al.
%   2012) use the broadband total eta, not the Sheremet incident
%   component, because the Sheremet split misallocates bound IG (see
%   PUV_L4_reflection caveat).
%
%   INPUTS
%     eta   - (segLen x nSeg) eta timeseries per L2 segment
%     L2    - L2 struct with .time, .segValid, .params.segLen, .fs
%     opts  - optional struct
%             .nfft       sub-segment FFT length (default 2048)
%             .overlap    sub-segment overlap fraction (default 0.5)
%             .mg         frequency-merge bandwidth in bins (default 5)
%             .fOut       upper bispectrum frequency cutoff (Hz; default 0.3)
%             .bandSwell  [fLow fHigh] (default [0.04 0.25])
%             .bandIG     [fLow fHigh] (default [0.004 0.04])
%             .bandSea    [fLow fHigh] (default [0.10 0.25])
%             .saveAll    save per-segment full B/Bic/Bip (default false)
%             .useParallel run the per-segment bispectrum calls under
%                         parfor (default false; needs Parallel Computing
%                         Toolbox and an open pool to actually go faster).
%                         Results are BIT-IDENTICAL to the serial path:
%                         only the K bispectrum calls are parallelised,
%                         while every derived quantity and the time-mean
%                         accumulation are done afterwards in index order.
%
%   OUTPUT (struct L4bisp)
%     L4bisp.time              - (nSeg x 1) datetime, copied from L2.time
%     L4bisp.fs, segLen, segValid
%     L4bisp.f                 - (nf x 1) merged frequency grid (Hz)
%     L4bisp.df                - merged bin spacing (Hz)
%     L4bisp.bandSwell, bandIG, bandSea
%
%     Per-segment scalars (each nSeg x 1):
%       .skewness              - bispectral skewness (Elgar & Guza 1985)
%       .asymmetry             - bispectral asymmetry (Elgar & Guza 1985)
%       .b95                   - significance threshold sqrt(6/edof_total)
%       .edof                  - effective DOF (sub-seg averaged)
%       .bic_max_overall       - max bicoherence over all (f1,f2) cells
%       .bic_swell_self        - max Bic on diagonal cells (f,f) with f in swell
%                                (Stokes second-harmonic generation)
%       .bic_swell_ig_diff     - max Bic on cells (f1 in swell, f2 in IG,
%                                 f1+f2 in swell) — bound-wave / swell-IG
%                                 difference coupling signature
%
%     Time-mean grids (nf x nf):
%       .B_mean                - <B> averaged across valid segments
%       .Bic_mean              - bicoherence derived from <B> and <P>
%       .Bip_mean              - biphase derived from <B>
%
%     Optional per-segment grids (only if opts.saveAll):
%       .B    .Bic  .Bip       - (nf x nf x nSeg) full per-segment grids
%
%   PERFORMANCE
%     With defaults (nfft=2048, K~6, mg=5) one L2 segment takes ~2.3 s and
%     a full deployment (~1600 segments) ~60 min on Apple Silicon. With
%     nfft=1024 one segment takes ~1 s (~30 min/deployment) at the cost
%     of coarser frequency resolution. The merging loop inside
%     bispectrum.m is the bottleneck; vectorising it is a candidate
%     optimisation if batch runtime becomes painful.
%
%     opts.useParallel spreads the segments over a parallel pool, which is
%     the cheaper win for batch work: ~8x on a 10-core machine, with
%     identical output (see the option note above).
%
%   REQUIRES
%     bispectrum.m on the MATLAB path.
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
if ~isfield(opts, 'nfft'),      opts.nfft      = 2048;       end
if ~isfield(opts, 'overlap'),   opts.overlap   = 0.5;        end
if ~isfield(opts, 'mg'),        opts.mg        = 5;          end
if ~isfield(opts, 'fOut'),      opts.fOut      = 0.3;        end
if ~isfield(opts, 'bandSwell'), opts.bandSwell = [0.04 0.25]; end
if ~isfield(opts, 'bandIG'),    opts.bandIG    = [0.004 0.04];end
if ~isfield(opts, 'bandSea'),   opts.bandSea   = [0.10 0.25]; end
if ~isfield(opts, 'saveAll'),   opts.saveAll   = false;      end
if ~isfield(opts, 'useParallel'), opts.useParallel = false;  end

fs     = L2.fs;
segLen = L2.params.segLen;
nSeg   = numel(L2.time);

step    = round(opts.nfft * (1 - opts.overlap));
subStarts = 1:step:(segLen - opts.nfft + 1);
K       = numel(subStarts);
if K < 1
    error('PUV_L4_bispectra:badSubseg', ...
        'No sub-segments fit in segLen=%d with nfft=%d and overlap=%.2f.', ...
        segLen, opts.nfft, opts.overlap);
end

% Probe one bispectrum call to learn the merged grid size
probe = bispectrum(zeros(opts.nfft, 1), fs, opts.mg, opts.fOut);
fGrid = probe.f;
nf    = numel(fGrid);
df    = probe.df;

% Allocate
L4bisp.time      = L2.time;
L4bisp.fs        = fs;
L4bisp.segLen    = segLen;
L4bisp.segValid  = false(nSeg, 1);
if isfield(L2, 'segValid'), L4bisp.segValid = L2.segValid; end
L4bisp.f         = fGrid;
L4bisp.df        = df;
L4bisp.bandSwell = opts.bandSwell;
L4bisp.bandIG    = opts.bandIG;
L4bisp.bandSea   = opts.bandSea;
L4bisp.K         = K;
L4bisp.nfftSub   = opts.nfft;

L4bisp.skewness          = NaN(nSeg, 1);
L4bisp.asymmetry         = NaN(nSeg, 1);
L4bisp.b95               = NaN(nSeg, 1);
L4bisp.edof              = NaN(nSeg, 1);
L4bisp.bic_max_overall   = NaN(nSeg, 1);
L4bisp.bic_swell_self    = NaN(nSeg, 1);
L4bisp.bic_swell_ig_diff = NaN(nSeg, 1);

if opts.saveAll
    L4bisp.B   = nan(nf, nf, nSeg) + 1i*nan(nf, nf, nSeg);
    L4bisp.Bic = nan(nf, nf, nSeg);
    L4bisp.Bip = nan(nf, nf, nSeg);
end

% --- Coupling-cell masks on the (f1, f2) one-sided merged grid ---
inSwell    = (fGrid >= opts.bandSwell(1)) & (fGrid <= opts.bandSwell(2));

[F1, F2]   = meshgrid(fGrid, fGrid);
F3         = F1 + F2;   % sum frequency for each cell

% Self-coupling mask (square diagonal in swell band)
maskSelf   = false(nf, nf);
swellIdx   = find(inSwell);
maskSelf(sub2ind([nf nf], swellIdx, swellIdx)) = true;

% Swell-IG difference coupling: f1 in swell, f2 in IG, f1+f2 in swell
% (and symmetrically f1 in IG, f2 in swell, f1+f2 in swell)
maskDiffA  = (F1 >= opts.bandSwell(1)) & (F1 <= opts.bandSwell(2)) & ...
             (F2 >= opts.bandIG(1))    & (F2 <= opts.bandIG(2))    & ...
             (F3 >= opts.bandSwell(1)) & (F3 <= opts.bandSwell(2));
maskDiffB  = (F2 >= opts.bandSwell(1)) & (F2 <= opts.bandSwell(2)) & ...
             (F1 >= opts.bandIG(1))    & (F1 <= opts.bandIG(2))    & ...
             (F3 >= opts.bandSwell(1)) & (F3 <= opts.bandSwell(2));
maskDiff   = maskDiffA | maskDiffB;

% --- Segments to process ---
% Same criterion as before: L2-valid and free of NaN.
useSeg = L4bisp.segValid(:) & ~any(isnan(eta), 1).';
segIdx = find(useSeg);
nUse   = numel(segIdx);

% --- Stage 1: the expensive part (K bispectrum calls per segment) ---
% Only the sub-segment loop is parallelised. Every derived quantity and the
% time-mean accumulation happen in stage 2, serially and in index order, so
% opts.useParallel does NOT change the numbers -- it is bit-identical to the
% serial path, not merely equivalent to rounding.
B_all  = complex(zeros(nf, nf, nUse));
P_all  = zeros(nf, nUse);
sk_all = NaN(nUse, 1);
as_all = NaN(nUse, 1);
ed_all = NaN(nUse, 1);

nfftSub = opts.nfft;
mg      = opts.mg;
fOutSub = opts.fOut;

% Pre-slice to the used columns. Indexing by the loop variable makes this a
% SLICED parfor variable, so each worker receives one 7200-sample column
% rather than a broadcast copy of the whole (segLen x nSeg) matrix -- which
% for the longest records would be ~200 MB per worker.
etaUse = eta(:, segIdx);

if opts.useParallel
    parfor q = 1:nUse
        etaSeg = etaUse(:, q);
        B_seg = zeros(nf, nf); P_seg = zeros(nf, 1);
        sk = 0; as_ = 0; ed = 0;
        for jSub = 1:K
            sub = etaSeg(subStarts(jSub) : subStarts(jSub) + nfftSub - 1);
            bs  = bispectrum(sub, fs, mg, fOutSub);
            B_seg = B_seg + bs.B;
            P_seg = P_seg + bs.P;
            sk = sk + bs.skewness; as_ = as_ + bs.asymmetry; ed = ed + bs.edof;
        end
        B_all(:,:,q) = B_seg / K;
        P_all(:,q)   = P_seg / K;
        sk_all(q) = sk / K; as_all(q) = as_ / K; ed_all(q) = ed;
    end
else
    for q = 1:nUse
        etaSeg = etaUse(:, q);
        B_seg = zeros(nf, nf); P_seg = zeros(nf, 1);
        sk = 0; as_ = 0; ed = 0;
        for jSub = 1:K
            sub = etaSeg(subStarts(jSub) : subStarts(jSub) + nfftSub - 1);
            bs  = bispectrum(sub, fs, mg, fOutSub);
            B_seg = B_seg + bs.B;
            P_seg = P_seg + bs.P;
            sk = sk + bs.skewness; as_ = as_ + bs.asymmetry; ed = ed + bs.edof;
        end
        B_all(:,:,q) = B_seg / K;
        P_all(:,q)   = P_seg / K;
        sk_all(q) = sk / K; as_all(q) = as_ / K; ed_all(q) = ed;
    end
end

% --- Stage 2: derived quantities + time mean, serial, in index order ---
[F1i, F2i]   = meshgrid(1:nf, 1:nf);
F3i          = round((F1 + F2) / df) + 1;   % index of f1+f2 on grid
inGrid       = F3i >= 1 & F3i <= nf;
F3i(~inGrid) = 1;

B_acc  = zeros(nf, nf);
P_acc  = zeros(nf, 1);
nValid = 0;

for q = 1:nUse
    i     = segIdx(q);
    B_seg = B_all(:,:,q);
    P_seg = P_all(:,q);

    Bic_seg = abs(B_seg) ./ sqrt(P_seg(F1i) .* P_seg(F2i) .* P_seg(F3i));
    Bic_seg(~inGrid) = 0;
    Bip_seg = atan2(imag(B_seg), real(B_seg));

    L4bisp.skewness(i)         = sk_all(q);
    L4bisp.asymmetry(i)        = as_all(q);
    L4bisp.edof(i)             = ed_all(q);   % sum, not mean (independent sub-segs)
    L4bisp.b95(i)              = sqrt(6 / L4bisp.edof(i));
    L4bisp.bic_max_overall(i)  = max(Bic_seg, [], 'all', 'omitnan');
    if any(maskSelf(:))
        L4bisp.bic_swell_self(i)   = max(Bic_seg(maskSelf), [], 'omitnan');
    end
    if any(maskDiff(:))
        L4bisp.bic_swell_ig_diff(i)= max(Bic_seg(maskDiff), [], 'omitnan');
    end

    if opts.saveAll
        L4bisp.B(:,:,i)   = B_seg;
        L4bisp.Bic(:,:,i) = Bic_seg;
        L4bisp.Bip(:,:,i) = Bip_seg;
    end

    B_acc  = B_acc + B_seg;
    P_acc  = P_acc + P_seg;
    nValid = nValid + 1;
end

% Time-mean grids
if nValid > 0
    L4bisp.B_mean = B_acc / nValid;
    P_mean        = P_acc / nValid;
    [F1i, F2i]    = meshgrid(1:nf, 1:nf);
    F3i           = round((F1 + F2) / df) + 1;
    inGrid        = F3i >= 1 & F3i <= nf;
    F3i(~inGrid)  = 1;
    L4bisp.Bic_mean = abs(L4bisp.B_mean) ./ ...
                      sqrt(P_mean(F1i) .* P_mean(F2i) .* P_mean(F3i));
    L4bisp.Bic_mean(~inGrid) = 0;
    L4bisp.Bip_mean = atan2(imag(L4bisp.B_mean), real(L4bisp.B_mean));
else
    L4bisp.B_mean   = nan(nf, nf);
    L4bisp.Bic_mean = nan(nf, nf);
    L4bisp.Bip_mean = nan(nf, nf);
end

L4bisp.nValid = nValid;
end
