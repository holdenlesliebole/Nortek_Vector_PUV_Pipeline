% Can the matched-grid metric DETECT broadening if it is really there?
%
% A null result is worthless unless the test could have rejected. Two checks:
%   Rule 1  hand-derived Qp for an analytic spectrum, fine grid and coarse grid
%   Rule 8  inject known broadening, confirm the matched-grid metric recovers it
%
% For a Gaussian spectrum S(f) = A*exp(-(f-fp)^2/(2*sig^2)):
%     m0        = A*sig*sqrt(2*pi)
%     int f S^2 = fp * A^2 * sig * sqrt(pi)
%     Qp = (2/m0^2) * int f S^2 = fp / (sig*sqrt(pi))
% so broadening sig -> r*sig must scale Qp by exactly 1/r.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

fprintf('\n===== SENSITIVITY / DETECTION-FLOOR CHECK =====\n');

% Real MOP grid
MOP = read_MOPline2('D0586', datetime(2023,5,10,0,0,0,'TimeZone','UTC'), ...
                            datetime(2023,5,10,6,0,0,'TimeZone','UTC'));
fbounds = double(MOP.fbounds); fMid = double(MOP.frequency(:)); fbw = double(MOP.fbw(:));

df = 2.778e-4; f = (0:df:1.0)';
fp = 0.09; sig0 = 0.012;
fSS = [0.04 0.25];
iB  = fMid >= fSS(1) & fMid <= fSS(2);
iF  = f    >= fSS(1) & f    <= fSS(2);

%% ---- RULE 1: hand-derived Qp -----------------------------------------
Qp_analytic = fp / (sig0*sqrt(pi));
S0 = exp(-((f-fp).^2)/(2*sig0^2));

m0f = trapz(f(iF), S0(iF));
Qp_fine = (2/m0f^2) * trapz(f(iF), f(iF).*S0(iF).^2);

S0c = bin_spectrum_to_grid(f, S0, fbounds);
m0c = sum(S0c(iB).*fbw(iB));
Qp_coarse = (2/m0c^2) * sum(fMid(iB).*S0c(iB).^2.*fbw(iB));

fprintf('\nRULE 1  Gaussian spectrum, fp=%.3f Hz, sigma=%.4f Hz\n', fp, sig0);
fprintf('   Qp hand-derived  fp/(sigma*sqrt(pi)) = %.4f\n', Qp_analytic);
fprintf('   Qp on PUV fine grid                  = %.4f  (%.2f%% of analytic)\n', ...
    Qp_fine, 100*Qp_fine/Qp_analytic);
fprintf('   Qp on MOP coarse grid                = %.4f  (%.2f%% of analytic)\n', ...
    Qp_coarse, 100*Qp_coarse/Qp_analytic);
fprintf('   -> the coarse grid biases Qp LOW by %.1f%% in absolute terms,\n', ...
    100*(1-Qp_coarse/Qp_analytic));
fprintf('      but this bias is applied identically to BOTH sides of a\n');
fprintf('      matched comparison, so it cancels in the ratio. Verified next.\n');

%% ---- RULE 8: inject known broadening ---------------------------------
fprintf('\nRULE 8  inject broadening sigma -> r*sigma; can the ratio see it?\n');
fprintf('   %6s %12s %14s %14s %12s\n', 'r', 'Qp_true_ratio', 'matched_ratio', 'recovery', 'legacy_ratio');

rs = [1.00 1.02 1.05 1.10 1.20 1.50];
for r = rs
    Sb = exp(-((f-fp).^2)/(2*(r*sig0)^2));    % broadened

    % matched grid: bin BOTH
    Sac = bin_spectrum_to_grid(f, S0, fbounds);
    Sbc = bin_spectrum_to_grid(f, Sb, fbounds);
    qa = qp_coarse(Sac, fMid, fbw, iB);
    qb = qp_coarse(Sbc, fMid, fbw, iB);
    matched = qa/qb;

    % legacy path: narrow stays fine, broad gets binned+interp'd up
    Sb_up = interp1(fMid, Sbc, f, 'linear', 0);
    qaf = qp_fine(S0,    f, iF);
    qbf = qp_fine(Sb_up, f, iF);
    legacy = qaf/qbf;

    fprintf('   %6.2f %12.4f %14.4f %13.1f%% %12.4f\n', ...
        r, r, matched, 100*(matched-1)/(r-1+eps), legacy);
end

fprintf('\n   True Qp ratio must equal r exactly (analytic). "recovery" is the\n');
fprintf('   fraction of the injected effect the matched metric recovers.\n');

%% ---- Detection floor on real data -------------------------------------
fprintf('\nDETECTION FLOOR on a real PUV record (TBR23/MOP586_7m)\n');
S = load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TBR23/MOP586_7m_L2.mat');
L2 = S.L2; valid = find(L2.segValid);
sel = valid(round(linspace(1, numel(valid), 200)));

for r = [1.00 1.05 1.10 1.20]
    rat = NaN(numel(sel),1);
    for i = 1:numel(sel)
        s = double(L2.S_eta(:, sel(i)));
        if all(isnan(s)), continue; end
        % broaden by convolving in frequency with a Gaussian of width
        % sqrt(r^2-1)*sig0 -- exactly reproduces sigma -> r*sigma for a
        % Gaussian peak, and is a physically sensible smoothing otherwise
        if r > 1
            w = sqrt(r^2-1)*sig0;
            nk = ceil(4*w/df); kk = (-nk:nk)'*df;
            ker = exp(-kk.^2/(2*w^2)); ker = ker/sum(ker);
            sb = conv(s, ker, 'same');
        else
            sb = s;
        end
        ac = bin_spectrum_to_grid(L2.f(:), s,  fbounds);
        bc = bin_spectrum_to_grid(L2.f(:), sb, fbounds);
        rat(i) = qp_coarse(ac, fMid, fbw, iB) / qp_coarse(bc, fMid, fbw, iB);
    end
    fprintf('   injected r = %.2f  ->  matched Qp ratio = %.4f  (IQR %.4f-%.4f)\n', ...
        r, median(rat,'omitnan'), prctile(rat,25), prctile(rat,75));
end

fprintf('\n===== DONE =====\n\n');

function q = qp_coarse(s, fMid, fbw, iB)
    ss = s(iB); ss(~isfinite(ss)) = 0; fm = fMid(iB); w = fbw(iB);
    m0 = sum(ss.*w);
    if m0 <= 0, q = NaN; return; end
    q = (2/m0^2) * sum(fm .* ss.^2 .* w);
end

function q = qp_fine(s, f, iF)
    sp = s(iF); sp(~isfinite(sp)) = 0; ff = f(iF);
    m0 = trapz(ff, sp);
    if m0 <= 0, q = NaN; return; end
    q = (2/m0^2) * trapz(ff, ff .* sp.^2);
end
