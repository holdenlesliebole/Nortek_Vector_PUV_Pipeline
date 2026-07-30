% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% How much does the representative-period choice matter for bed stress?
%
% bed_stress computes Aw = Ub*T/(2*pi) internally from ONE period. But the bed
% transfer T(f) = omega/sinh(kh) is a strong low-pass, so the frequency content
% of the NEAR-BED orbital motion is not that of the surface elevation. The
% spectrally consistent quantities are
%
%   S_u(f) = S_eta(f) * (omega/sinh(kh))^2      near-bed velocity
%   S_a(f) = S_u(f)/omega^2 = S_eta/sinh^2(kh)  near-bed displacement
%   u_b = sqrt(int S_u df),  A_b = sqrt(int S_a df),  T_b = 2*pi*A_b/u_b
%
% Passing T_b to bed_stress makes its internal Aw exactly equal to the spectral
% A_b, so the single-period interface can carry the full-spectrum answer.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

cases = { 'TOR24S','MOP586_5m'; 'TBR23','MOP586_7m'; 'TOR23W','MOP586_10m'; 'TOR24W','MOP586_15m' };
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';

fprintf('\n===== PERIOD DEFINITION AND BED STRESS =====\n');
fprintf('%-9s %-12s %5s %7s %7s %7s %8s %8s %9s %9s\n', ...
    'deploy','label','h','Tp','Tm01','T_b','Tb/Tm01','r(Tm01)','tau ratio','fw ratio');

for c = 1:size(cases,1)
    S = load(fullfile(root, cases{c,1}, [cases{c,2} '_L2.mat'])); L2 = S.L2;
    v = find(L2.segValid); v = v(round(linspace(1,numel(v),min(400,numel(v)))));
    f = L2.f(:); df = f(2)-f(1);
    fSS = L2.params.fSS;
    D50 = L2.params.D50; rho = 1025;

    Tp_ = NaN(numel(v),1); Tm01 = Tp_; Tb = Tp_; ub = Tp_; Ab = Tp_;
    for i = 1:numel(v)
        h = L2.depth(v(i)); if ~isfinite(h)||h<=0, continue; end
        s = double(L2.S_eta(:,v(i)));
        fc = L2.fCut(v(i)); if ~isfinite(fc), fc = fSS(2); end
        iF = f>=fSS(1) & f<=min(fSS(2),fc);
        sF = s(iF); sF(~isfinite(sF))=0; ff = f(iF);
        om = 2*pi*ff; k = get_wavenumber(om,h); sh = sinh(k(:)*h);

        m0 = sum(sF)*df; m1 = sum(ff.*sF)*df;
        if m0<=0, continue; end
        Tm01(i) = m0/m1;
        [~,ip] = max(sF); Tp_(i) = 1/ff(ip);

        Su = sF .* (om./sh).^2;          % near-bed velocity spectrum
        Sa = sF ./ (sh.^2);              % near-bed displacement spectrum
        ub(i) = sqrt(sum(Su)*df);
        Ab(i) = sqrt(sum(Sa)*df);
        Tb(i) = 2*pi*Ab(i)/max(ub(i),eps);
    end
    g = isfinite(Tb) & isfinite(Tm01) & ub>0;

    ks = 10*D50;
    % single-period (as currently coded) vs full-spectrum
    Aw_m01 = ub(g).*Tm01(g)/(2*pi);
    Aw_spec = Ab(g);
    [tau_m01,fw_m01] = local_swart(ub(g), Aw_m01, ks, rho);
    [tau_spc,fw_spc] = local_swart(ub(g), Aw_spec, ks, rho);

    fprintf('%-9s %-12s %5.1f %7.2f %7.2f %7.2f %8.3f %8.0f %9.3f %9.3f\n', ...
        cases{c,1}, cases{c,2}, median(L2.depth(v),'omitnan'), ...
        median(Tp_(g)), median(Tm01(g)), median(Tb(g)), ...
        median(Tb(g))/median(Tm01(g)), median(Aw_m01/ks), ...
        median(tau_spc./tau_m01), median(fw_spc./fw_m01));
end

fprintf('\nTb/Tm01 > 1 means the near-bed motion is longer-period than the surface\n');
fprintf('elevation, because the bed filters out high frequencies. tau ratio is\n');
fprintf('full-spectrum / single-period: how much the current code is off.\n');
fprintf('\nSwart rough-flow branch used here is fw = 0.0521*r^-0.187, so at fixed Ub\n');
fprintf('a factor X error in Aw gives X^-0.187 in fw and hence in tau.\n\n');

function [tau, fw] = local_swart(Ub, Aw, ks, rho)
    r = Aw./ks; fw = nan(size(r));
    i1 = r<5;              fw(i1) = 0.3*r(i1).^(-0.5);
    i2 = r>=5 & r<=70;     fw(i2) = exp(-6.0 + 5.2*r(i2).^(-0.19));
    i3 = r>70;             fw(i3) = 0.0521*r(i3).^(-0.187);
    tau = 0.5*rho.*fw.*Ub.^2;
end
