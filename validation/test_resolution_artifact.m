% Phase 1b: bound the frequency-resolution artifact.
%
% Compare a real PUV spectrum against ITSELF, degraded through the exact
% pipeline that analyze_spectral_shape.m:110 applies to MOP:
%     bin to the MOP grid  ->  interp1 back up onto the PUV fine grid
% Any apparent "peak broadening" is then pure artifact, because both sides
% carry identical physics. That number is the yardstick.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

fprintf('\n========== PHASE 1b: RESOLUTION ARTIFACT ==========\n');

%% ---- Load a real L2 ---------------------------------------------------
L2f = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TBR23/MOP586_7m_L2.mat';
S = load(L2f); L2 = S.L2;
fprintf('\nL2: %s / %s\n', L2.deploymentName, L2.label);
fprintf('   f grid: %d bins, df = %.3e Hz, band [%.3f %.3f] Hz\n', ...
    numel(L2.f), L2.f(2)-L2.f(1), min(L2.f), max(L2.f));

valid = find(L2.segValid);
fprintf('   %d valid segments of %d\n', numel(valid), numel(L2.segValid));

%% ---- Get the real MOP frequency grid ---------------------------------
tS = min(L2.time(valid)); tE = tS + hours(6);
if isempty(tS.TimeZone), tS.TimeZone='UTC'; tE.TimeZone='UTC'; end
fprintf('\nFetching MOP grid for %s ...\n', L2.mopStation);
MOP = read_MOPline2(L2.mopStation, tS, tE);
fbounds = double(MOP.fbounds);
fMid    = double(MOP.frequency(:));
fbw     = double(MOP.fbw(:));
fprintf('   MOP: %d bins, %.3f-%.3f Hz, bandwidth %.4f-%.4f Hz\n', ...
    numel(fMid), min(fbounds(:)), max(fbounds(:)), min(fbw), max(fbw));
fprintf('   PUV/MOP frequency resolution ratio: %.0fx\n', mean(fbw)/(L2.f(2)-L2.f(1)));

%% ---- Metric helpers ---------------------------------------------------
fSS = L2.params.fSS;
f   = L2.f(:);
iSS = f >= fSS(1) & f <= fSS(2);
df  = f(2)-f(1);

    function [Qp, bw, peakS, m0] = shape_metrics_fine(s, f, iSS, df)
        sp = s(iSS); fp_ = f(iSS);
        m0 = trapz(fp_, sp);
        Qp = (2/m0^2) * trapz(fp_, fp_ .* sp.^2);
        [peakS, ~] = max(sp);
        bw = sum(sp >= peakS/2) * df;      % half-power bandwidth, as in the original
    end

    function [Qp, m0, peakNorm] = shape_metrics_binned(sb, fMid, fbw, iB)
        s = sb(iB); fm = fMid(iB); w = fbw(iB);
        m0 = sum(s .* w);
        Qp = (2/m0^2) * sum(fm .* s.^2 .* w);
        [pk, ipk] = max(s);
        peakNorm = pk / (m0 * fm(ipk));    % dimensionless peak density
    end

iB = fMid >= fSS(1) & fMid <= fSS(2);

%% ---- Run the self-comparison over every valid segment ----------------
n = numel(valid);
Qp_true = NaN(n,1); Qp_art = NaN(n,1);
bw_true = NaN(n,1); bw_art = NaN(n,1);
pk_true = NaN(n,1); pk_art = NaN(n,1);
m0_true = NaN(n,1); m0_art = NaN(n,1);
Qp_matched_true = NaN(n,1); Qp_matched_art = NaN(n,1);

for i = 1:n
    s_fine = double(L2.S_eta(:, valid(i)));
    if all(isnan(s_fine)) || all(s_fine==0), continue; end

    % Degrade exactly the way MOP is currently handled:
    s_binned   = bin_spectrum_to_grid(f, s_fine, fbounds);          % coarse
    s_reinterp = interp1(fMid, s_binned, f, 'linear', 0);           % back up (the flaw)

    [Qp_true(i), bw_true(i), pk_true(i), m0_true(i)] = shape_metrics_fine(s_fine,   f, iSS, df);
    [Qp_art(i),  bw_art(i),  pk_art(i),  m0_art(i) ] = shape_metrics_fine(s_reinterp, f, iSS, df);

    % Resolution-MATCHED comparison: both sides on the MOP grid.
    % Self-comparison here is the identity, which is the point.
    [Qp_matched_true(i), ~, ~] = shape_metrics_binned(s_binned, fMid, fbw, iB);
    Qp_matched_art(i) = Qp_matched_true(i);
end

ok = ~isnan(Qp_true) & ~isnan(Qp_art);
fprintf('\n%d segments evaluated\n', sum(ok));

%% ---- Report -----------------------------------------------------------
fprintf('\n--- ARTIFACT, measured on the CURRENT (interp-up) code path ---\n');
fprintf('  These compare a PUV spectrum to a degraded copy of ITSELF,\n');
fprintf('  so the true answer for every row is "no difference".\n\n');

bw_narrow = 100*(1 - bw_true./bw_art);
Qp_ratio  = Qp_true ./ Qp_art;
pk_ratio  = pk_true ./ pk_art;
m0_ratio  = m0_true ./ m0_art;

fprintf('  half-power bandwidth "narrowing"  : median %6.1f%%  [IQR %5.1f - %5.1f]\n', ...
    median(bw_narrow(ok)), prctile(bw_narrow(ok),25), prctile(bw_narrow(ok),75));
fprintf('  Goda Qp ratio (true/degraded)     : median %6.3f  [IQR %5.3f - %5.3f]\n', ...
    median(Qp_ratio(ok)), prctile(Qp_ratio(ok),25), prctile(Qp_ratio(ok),75));
fprintf('  peak density ratio                : median %6.3f  [IQR %5.3f - %5.3f]\n', ...
    median(pk_ratio(ok)), prctile(pk_ratio(ok),25), prctile(pk_ratio(ok),75));
fprintf('  m0 ratio (variance, should be ~1) : median %6.4f\n', median(m0_ratio(ok)));

fprintf('\n--- Reference: the numbers this artifact is being compared against ---\n');
fprintf('  results_validation.tex  : bandwidth 16.7%% narrower, Qp ratio 1.07, peak density +14.4%%\n');
fprintf('  cross_deployment_*.mat  : bandwidth narrowing 36-78%%,  Qp ratio 0.98-1.31\n');

save(fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation','resolution_artifact_bound.mat'), ...
     'bw_narrow','Qp_ratio','pk_ratio','m0_ratio','ok','fbw','fMid','fbounds');

fprintf('\n========== DONE ==========\n\n');
