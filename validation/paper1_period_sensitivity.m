% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% Paper 1 period sensitivity, computed through PAPER 1'S OWN MACHINERY.
%
% Paper 1 uses a hybrid: Ub is broadband (bed_velocity_ifft, 2-component,
% measured velocity) but Aw = Ub*Tp/(2*pi) collapses onto the peak period.
% The full-spectrum alternative must be built from the SAME measured velocity,
% not from the elevation spectrum, or the comparison mixes two definitions of
% Ub and the sensitivity is contaminated by that instead of by the period.
%
% Consistent construction from stored L2 fields:
%   S_ubed(f) = [Suu(f) + Svv(f)] / cosh(k*z_s)^2      z_s = doffp
%   u_b = sqrt(int S_ubed df)        <-- must reproduce L2.Ub  (closure check)
%   A_b = sqrt(int S_ubed/omega^2 df)
%   T_b = 2*pi*A_b/u_b
%
% Then tau under Paper 1's Tp vs tau under the spectral T_b, same Ub, same ks.

startup_puv;

dep = 'TBR23';
labs = {'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'};
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';
rho = 1025; g = 9.81; rho_s = 2650; nu = 1e-6;

fprintf('\n========= PAPER 1 PERIOD SENSITIVITY (TBR23, per PUV) =========\n');
fprintf('Ub held fixed at Paper 1''s value; only the period entering Aw changes.\n\n');

fprintf('%-12s %5s %6s %7s %7s %7s %8s %9s %9s %9s\n', ...
    'PUV','h','clos','Tp','T_b','Tb/Tp','Aw ratio','tau ratio','mob(Tp)','mob(Tb)');

OUT = struct([]);
for c = 1:numel(labs)
    S = load(fullfile(root, dep, [labs{c} '_L2.mat'])); L2 = S.L2;
    v = find(L2.segValid);
    f = L2.f(:); df = f(2)-f(1);
    fSS = L2.params.fSS;
    zs = L2.doffp;

    % roughness + sediment exactly as the pipeline would
    ks = 10*L2.params.D50; D50 = L2.params.D50; ksSrc = 'legacy 10*D50';
    try
        gs = site_grain_size(char(L2.label));
        if isfinite(gs.D84) && gs.D84>0
            ks = 2.5*gs.D84; ksSrc = sprintf('2.5*D84 (%s)', char(gs.status));
            if isfinite(gs.D50)&&gs.D50>0, D50 = gs.D50; end
        end
    catch
    end
    % Soulsby & Whitehouse (1997) critical Shields
    Dstar = D50 * (g*(rho_s/rho - 1)/nu^2)^(1/3);
    th_cr = 0.30/(1 + 1.2*Dstar) + 0.055*(1 - exp(-0.020*Dstar));

    n = numel(v);
    ub_s = NaN(n,1); Ab = NaN(n,1); Tb = NaN(n,1); Tp = NaN(n,1); UbP = NaN(n,1);
    for i = 1:n
        ii = v(i); h = L2.depth(ii);
        if ~isfinite(h) || h<=0, continue; end
        fc = L2.fCut(ii); if ~isfinite(fc), fc = fSS(2); end
        iF = f>=fSS(1) & f<=min(fSS(2),fc);
        ff = f(iF); om = 2*pi*ff;
        k = get_wavenumber(om, h);

        Su = double(L2.Suu(iF,ii)) + double(L2.Svv(iF,ii));
        Su(~isfinite(Su)) = 0;
        Su_bed = Su ./ (cosh(k(:)*zs).^2);        % sensor -> bed, per bin

        ub_s(i) = sqrt(sum(Su_bed)*df);
        Ab(i)   = sqrt(sum(Su_bed./(om.^2))*df);
        Tb(i)   = 2*pi*Ab(i)/max(ub_s(i),eps);
        Tp(i)   = L2.Tp(ii);
        UbP(i)  = L2.Ub(ii);
    end
    gd = isfinite(Tb)&isfinite(Tp)&isfinite(UbP)&UbP>0&Tp>0;

    % closure: does the spectral reconstruction reproduce Paper 1's Ub?
    clos = median(ub_s(gd)./UbP(gd));

    % tau both ways, Paper 1's Ub in both
    [tau_Tp,  ~, Aw_Tp] = bed_stress_ks(UbP(gd), Tp(gd), ks, rho);
    [tau_Tb,  ~, Aw_Tb] = bed_stress_ks(UbP(gd), Tb(gd), ks, rho);
    sh_Tp = tau_Tp/((rho_s-rho)*g*D50);
    sh_Tb = tau_Tb/((rho_s-rho)*g*D50);

    fprintf('%-12s %5.1f %6.3f %7.2f %7.2f %7.3f %8.3f %9.3f %9.1f%% %8.1f%%\n', ...
        labs{c}, median(L2.depth(v),'omitnan'), clos, median(Tp(gd)), median(Tb(gd)), ...
        median(Tb(gd))/median(Tp(gd)), median(Aw_Tb./Aw_Tp), median(tau_Tb./tau_Tp), ...
        100*mean(sh_Tp>th_cr), 100*mean(sh_Tb>th_cr));

    k2 = numel(OUT)+1; if isempty(OUT), OUT=struct(); k2=1; end
    OUT(k2).lab=labs{c}; OUT(k2).clos=clos; OUT(k2).Tp=median(Tp(gd)); OUT(k2).Tb=median(Tb(gd));
    OUT(k2).tau_ratio=median(tau_Tb./tau_Tp); OUT(k2).mob_Tp=mean(sh_Tp>th_cr);
    OUT(k2).mob_Tb=mean(sh_Tb>th_cr); OUT(k2).ks=ks; OUT(k2).ksSrc=ksSrc;
    OUT(k2).th_cr=th_cr; OUT(k2).D50=D50; OUT(k2).n=sum(gd);
end

fprintf('\nclos = spectral u_b / Paper 1 L2.Ub. Should be ~1 (Parseval); it is the\n');
fprintf('       check that the reconstruction is consistent with Paper 1''s Ub.\n');
fprintf('tau ratio = tau(full-spectrum T_b) / tau(Paper 1 T_p). >1 means Paper 1\n');
fprintf('       UNDERestimates bed stress (conservative for mobilization claims).\n');
fprintf('mob = %% of valid hours above the Soulsby-Whitehouse critical Shields.\n\n');
for i=1:numel(OUT)
    fprintf('  %-12s ks = %.4g m (%s), D50 = %.4g m, theta_cr = %.4f, n = %d\n', ...
        OUT(i).lab, OUT(i).ks, OUT(i).ksSrc, OUT(i).D50, OUT(i).th_cr, OUT(i).n);
end

tr = [OUT.tau_ratio];
fprintf('\nSUMMARY across the four TBR23 PUVs:\n');
fprintf('  tau(T_b)/tau(T_p) = %.4f - %.4f  (median %.4f)\n', min(tr), max(tr), median(tr));
fprintf('  i.e. Paper 1 underestimates bed stress by %.1f - %.1f%%\n', ...
    100*(min(tr)-1), 100*(max(tr)-1));
dmob = 100*([OUT.mob_Tb]-[OUT.mob_Tp]);
fprintf('  mobilized-hours change: %+.2f to %+.2f percentage points\n', min(dmob), max(dmob));

save(fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','validation','paper1_period.mat'),'OUT');
