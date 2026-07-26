% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% Phase 1c pilot: the resolution-MATCHED spectral-shape comparison.
%
% Both PUV and MOP are reduced to MOP's native bin grid before any shape
% metric is computed. This is the measurement the previous code path could
% not make. Run on 4 deployments spanning exposures before committing to a
% 65-record sweep.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

L2root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';
cases = { 'TBR23',  'MOP586_7m'
          'CDF15A', 'MOP677_9m'
          'COR16B', 'MOP158_9m'
          'TOR17B', 'MOP591_9m' };

fprintf('\n===== PHASE 1c PILOT: resolution-matched shape comparison =====\n');

R = struct([]);

for c = 1:size(cases,1)
    dep = cases{c,1}; lab = cases{c,2};
    fn = fullfile(L2root, dep, [lab '_L2.mat']);
    if ~isfile(fn), fprintf('\n[skip] %s missing\n', fn); continue; end
    S = load(fn); L2 = S.L2;

    valid = find(L2.segValid);
    if numel(valid) < 20, fprintf('\n[skip] %s/%s: only %d valid\n', dep,lab,numel(valid)); continue; end

    tS = min(L2.time(valid)); tE = max(L2.time(valid));
    if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end

    station = L2.mopStation;
    fprintf('\n--- %s / %s  (%s, h=%.1f m, %d valid segs) ---\n', ...
        dep, lab, station, median(L2.depth(valid),'omitnan'), numel(valid));

    try
        MOP = read_MOPline2(station, tS, tE);
    catch ME
        fprintf('   [THREDDS failed: %s]\n', ME.message); continue;
    end
    if isempty(MOP.time), fprintf('   [no MOP data]\n'); continue; end

    % --- time match: MOP hour -> nearest valid PUV segment within 30 min
    tP = L2.time(valid); if isempty(tP.TimeZone), tP.TimeZone = MOP.time.TimeZone; end
    nM = numel(MOP.time);
    pick = NaN(nM,1);
    for t = 1:nM
        [dt, im] = min(abs(tP - MOP.time(t)));
        if dt < minutes(30), pick(t) = valid(im); end
    end
    keep = find(~isnan(pick));
    if numel(keep) < 20, fprintf('   [only %d matched hours]\n', numel(keep)); continue; end

    % --- shoal MOP, per-segment tidal depth at the matched hours
    h_seg = L2.depth(pick(keep));
    MOPk = MOP;
    MOPk.spec1D = MOP.spec1D(keep,:);
    MOPk.time   = MOP.time(keep);
    sh = shoal_mop_to_site(MOPk, h_seg);

    fMid = sh.frequency; fbw = sh.fbw; fbounds = sh.fbounds;
    f = L2.f(:); fSS = L2.params.fSS;

    % --- band mask on the MOP grid: SS band AND below the PUV cutoff
    fCut = median(L2.fCut(pick(keep)), 'omitnan');
    iB = fMid >= fSS(1) & fMid <= fSS(2) & fbounds(2,:)' <= min(fSS(2), fCut);
    if sum(iB) < 4, iB = fMid >= fSS(1) & fMid <= fSS(2); end

    nK = numel(keep);
    Qp_p = NaN(nK,1); Qp_m = NaN(nK,1);
    pk_p = NaN(nK,1); pk_m = NaN(nK,1);
    nu_p = NaN(nK,1); nu_m = NaN(nK,1);
    Hs_r = NaN(nK,1);
    % legacy fine-grid numbers, for side-by-side
    Qp_pf = NaN(nK,1); Qp_mf = NaN(nK,1); bwn = NaN(nK,1);

    for i = 1:nK
        s_fine = double(L2.S_eta(:, pick(keep(i))));
        if all(isnan(s_fine)), continue; end
        s_mopc = sh.spec(i,:)';                                  % already coarse

        % ---- MATCHED GRID: bin PUV down
        s_puvc = bin_spectrum_to_grid(f, s_fine, fbounds);

        [Qp_p(i), pk_p(i), nu_p(i), m0p] = shape_coarse(s_puvc, fMid, fbw, iB);
        [Qp_m(i), pk_m(i), nu_m(i), m0m] = shape_coarse(s_mopc, fMid, fbw, iB);
        Hs_r(i) = sqrt(m0p/m0m);

        % ---- LEGACY PATH: interp MOP up onto the fine grid
        s_up = interp1(fMid, s_mopc, f, 'linear', 0);
        iSS  = f >= fSS(1) & f <= fSS(2);
        df   = f(2)-f(1);
        [Qp_pf(i), bwp] = shape_fine(s_fine, f, iSS, df);
        [Qp_mf(i), bwm] = shape_fine(s_up,   f, iSS, df);
        bwn(i) = 100*(1 - bwp/bwm);
    end

    g = ~isnan(Qp_p) & ~isnan(Qp_m);
    fprintf('   matched hours: %d   MOP bins used: %d  (fCut = %.3f Hz)\n', sum(g), sum(iB), fCut);
    fprintf('   %-34s %8s %8s %8s\n','metric','PUV','MOP','ratio');
    fprintf('   %-34s %8.3f %8.3f %8.3f\n','MATCHED Goda Qp', ...
        median(Qp_p(g)), median(Qp_m(g)), median(Qp_p(g))/median(Qp_m(g)));
    fprintf('   %-34s %8.3f %8.3f %8.3f\n','MATCHED norm. peak density', ...
        median(pk_p(g)), median(pk_m(g)), median(pk_p(g))/median(pk_m(g)));
    fprintf('   %-34s %8.3f %8.3f %8.3f\n','MATCHED narrowness nu', ...
        median(nu_p(g)), median(nu_m(g)), median(nu_p(g))/median(nu_m(g)));
    fprintf('   %-34s %8.3f\n','Hs ratio (PUV/MOP)', median(Hs_r(g)));
    fprintf('   %-34s %8.3f %8.3f %8.3f\n','LEGACY (interp-up) Qp', ...
        median(Qp_pf(g)), median(Qp_mf(g)), median(Qp_pf(g))/median(Qp_mf(g)));
    fprintf('   %-34s %8.1f%%\n','LEGACY bandwidth narrowing', median(bwn(g)));

    k = numel(R)+1; if isempty(R), R = struct(); k = 1; end
    R(k).dep=dep; R(k).lab=lab; R(k).n=sum(g);
    R(k).Qp_ratio_matched = median(Qp_p(g))/median(Qp_m(g));
    R(k).pk_ratio_matched = median(pk_p(g))/median(pk_m(g));
    R(k).nu_ratio_matched = median(nu_p(g))/median(nu_m(g));
    R(k).Hs_ratio         = median(Hs_r(g));
    R(k).Qp_ratio_legacy  = median(Qp_pf(g))/median(Qp_mf(g));
    R(k).bw_narrow_legacy = median(bwn(g));
end

fprintf('\n===== SUMMARY =====\n');
fprintf('%-9s %-11s %5s %10s %10s %10s %10s %10s\n', ...
    'dep','label','n','Qp(match)','pk(match)','nu(match)','Qp(legacy)','bw%(leg)');
for k = 1:numel(R)
    fprintf('%-9s %-11s %5d %10.3f %10.3f %10.3f %10.3f %10.1f\n', ...
        R(k).dep, R(k).lab, R(k).n, R(k).Qp_ratio_matched, R(k).pk_ratio_matched, ...
        R(k).nu_ratio_matched, R(k).Qp_ratio_legacy, R(k).bw_narrow_legacy);
end
fprintf('\nReminder: the self-comparison artifact on the legacy path was\n');
fprintf('  Qp ratio 1.225, bandwidth narrowing 68.3%%, peak density 1.81.\n');
fprintf('A matched-grid ratio near 1.00 means no physical shape bias.\n\n');

save(fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation','phase1c_pilot.mat'),'R');

%% ---- local functions --------------------------------------------------
function [Qp, pkNorm, nu, m0] = shape_coarse(s, fMid, fbw, iB)
    ss = s(iB); fm = fMid(iB); w = fbw(iB);
    ss(~isfinite(ss)) = 0;
    m0 = sum(ss .* w);
    if m0 <= 0, Qp=NaN; pkNorm=NaN; nu=NaN; return; end
    m1 = sum(fm .* ss .* w);
    m2 = sum(fm.^2 .* ss .* w);
    Qp = (2/m0^2) * sum(fm .* ss.^2 .* w);
    [pk, ipk] = max(ss);
    pkNorm = pk / (m0 / fm(ipk));          % dimensionless
    nu = sqrt(max(m0*m2/m1^2 - 1, 0));
end

function [Qp, bw] = shape_fine(s, f, iSS, df)
    sp = s(iSS); fp_ = f(iSS);
    sp(~isfinite(sp)) = 0;
    m0 = trapz(fp_, sp);
    if m0 <= 0, Qp=NaN; bw=NaN; return; end
    Qp = (2/m0^2) * trapz(fp_, fp_ .* sp.^2);
    pk = max(sp);
    bw = sum(sp >= pk/2) * df;
end
