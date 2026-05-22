% extract_legacy_bulk.m
% Author: Holden Leslie-Bole, 2026
% Walk the legacy per-segment struct array and build flat bulk-parameter
% arrays. Save to a small .mat file so the comparison script can load
% bulk values without paying the 2.4 GB file load again.
%
% Also captures one representative segment's spectrum (highest-Hs segment)
% so we can compare spectral shape directly.

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

l2file = 'raw_cache/Ruby2D/Torrey_Ruby2D_582_6m_PUV_process.mat';
fprintf('Loading legacy L2 (this is the 2.4 GB file, ~30s)...\n');
t0 = tic;
S = load(l2file, 'PUV_process');
fprintf('  loaded in %.1f s\n', toc(t0));

P = S.PUV_process;
N = numel(P);
fprintf('  %d segments\n', N);

% Allocate
seg_t   = NaT(N, 1);              % use first sample of segment
Hs      = nan(N, 1);
Hs_ss   = nan(N, 1);
Hs_ig   = nan(N, 1);
fpeak   = nan(N, 1);
Tm      = nan(N, 1);              % centroid period
dir1    = nan(N, 1);              % bulk direction (deg)
spread1 = nan(N, 1);              % bulk spread  (deg)
ztest_ss = nan(N, 1);
fcen     = nan(N, 1);
nSamp    = nan(N, 1);

for k = 1:N
    p = P(k);
    if ~isempty(p.time),     seg_t(k)   = p.time(1);                end
    if ~isempty(p.time),     nSamp(k)   = numel(p.time);            end
    if ~isempty(p.Hsig),     Hs(k)      = p.Hsig.Hs;                end
    if ~isempty(p.Hsig),     Hs_ss(k)   = p.Hsig.Hs_ss;             end
    if ~isempty(p.Hsig),     Hs_ig(k)   = p.Hsig.Hs_ig;             end
    if ~isempty(p.ids),      fpeak(k)   = p.ids.fpeak;              end
    if ~isempty(p.ids),      Tm(k)      = p.ids.Tm;                 end
    if ~isempty(p.ids),      fcen(k)    = p.ids.fcentroid_swell;    end
    if ~isempty(p.dir),      dir1(k)    = p.dir.dir1_ss_sum;        end
    if ~isempty(p.dir),      spread1(k) = p.dir.spread1_ss_sum;     end
    if ~isempty(p.ztest),    ztest_ss(k) = p.ztest.ztest_ss_sum;    end
end

Tp = 1 ./ fpeak;

legacy = struct();
legacy.time     = seg_t;
legacy.Hs       = Hs;
legacy.Hs_ss    = Hs_ss;
legacy.Hs_ig    = Hs_ig;
legacy.Tp       = Tp;
legacy.Tm       = Tm;          % centroid (energy-weighted)
legacy.fpeak    = fpeak;
legacy.fcen     = fcen;
legacy.dir1     = dir1;
legacy.spread1  = spread1;
legacy.ztest_ss = ztest_ss;
legacy.nSamp    = nSamp;

fprintf('\nSegment summary:\n');
fprintf('  N segments         : %d\n', N);
fprintf('  median samples/seg : %g  (=> %g min @ 2 Hz)\n', ...
    median(nSamp, 'omitnan'), median(nSamp, 'omitnan')/2/60);
fprintf('  time range         : %s  ->  %s\n', ...
    string(min(seg_t)), string(max(seg_t)));
fprintf('  Hs    median       : %.3f m  (range %.2f - %.2f)\n', ...
    median(Hs, 'omitnan'), min(Hs), max(Hs));
fprintf('  Tp    median       : %.2f s\n', median(Tp, 'omitnan'));
fprintf('  Tm    median       : %.2f s\n', median(Tm, 'omitnan'));
fprintf('  Dir   median       : %.1f deg\n', median(dir1, 'omitnan'));
fprintf('  Sprd  median       : %.1f deg\n', median(spread1, 'omitnan'));
fprintf('  zSS   median       : %.3f\n',   median(ztest_ss, 'omitnan'));

%% Pull a representative spectrum (segment near median Hs, in mid-record)
midHs = median(Hs, 'omitnan');
[~, kRep] = min(abs(Hs - midHs));
fprintf('\nRepresentative segment: idx %d, t = %s, Hs = %.2f m\n', ...
    kRep, string(seg_t(kRep)), Hs(kRep));

rep = struct();
rep.idx     = kRep;
rep.time    = seg_t(kRep);
rep.Hs      = Hs(kRep);
rep.Tp      = Tp(kRep);
rep.fm      = P(kRep).Spec.fm;        % low-res grid (post-correction)
rep.SSE     = P(kRep).Spec.SSE;       % sea surface elevation spectrum
rep.SppU    = P(kRep).Spec.SppU;      % uncorrected pressure spectrum (high-res)
rep.SSEU    = P(kRep).Spec.SSEU;      % uncorrected SSE? (high-res)

%% Also a high-Hs case so we can show what happens at the energetic tail
[~, kHi] = max(Hs);
high = struct();
high.idx  = kHi;
high.time = seg_t(kHi);
high.Hs   = Hs(kHi);
high.Tp   = Tp(kHi);
high.fm   = P(kHi).Spec.fm;
high.SSE  = P(kHi).Spec.SSE;
high.SppU = P(kHi).Spec.SppU;
high.SSEU = P(kHi).Spec.SSEU;

%% Save
outFile = 'raw_cache/Ruby2D/legacy_bulk_582_6m.mat';
save(outFile, 'legacy', 'rep', 'high');
fprintf('\nSaved bulk extract -> %s\n', outFile);
