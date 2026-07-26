% Phase 1a verification: shoal_mop_to_site + bin_spectrum_to_grid
% Synthetic closure tests -- no THREDDS dependence.

startup_puv;

fprintf('\n========== PHASE 1a VERIFICATION ==========\n');

%% ---- Build a synthetic MOP struct -------------------------------------
% Non-uniform bins, like the real CDIP MOP grid (20 bins, 0.04-0.40 Hz)
nB   = 20;
edges = logspace(log10(0.04), log10(0.40), nB+1)';   % non-uniform on purpose
fLo  = edges(1:end-1);
fHi  = edges(2:end);
fMid = 0.5*(fLo+fHi);
fbw  = fHi - fLo;

nT = 5;
fp = 0.09;  sig = 0.012;
base = exp(-((fMid-fp).^2)/(2*sig^2));            % peaked shape
MOP = struct();
MOP.frequency = fMid;
MOP.fbw       = fbw;
MOP.fbounds   = [fLo'; fHi'];                      % [2 x nBins], CDIP layout
MOP.spec1D    = (base * (1:nT))';                  % [nT x nB], varying amplitude
MOP.depth     = 10.0;
MOP.time      = datetime(2024,1,1,0,0,0) + hours(0:nT-1)';

h_puv = 7.3;

%% ---- TEST A: behaviour preservation vs the inlined block --------------
% Reproduce compare_PUV_MOP.m:105-117 exactly
omega   = 2*pi*double(MOP.frequency(:));
k_mop_o = get_wavenumber(omega, double(MOP.depth));
k_puv_o = get_wavenumber(omega, h_puv);
cg_mop_o = get_cg(k_mop_o, double(MOP.depth));
cg_puv_o = get_cg(k_puv_o, h_puv);
shoal_o  = cg_mop_o(:) ./ cg_puv_o(:);
spec_old = MOP.spec1D .* shoal_o';

out = shoal_mop_to_site(MOP, h_puv);

relerr = max(abs(out.spec(:) - spec_old(:))) / max(abs(spec_old(:)));
fprintf('\nTEST A  behaviour preservation (scalar depth, no refraction)\n');
fprintf('   max relative difference vs inlined block : %.3e\n', relerr);
assert(relerr < 1e-12, 'TEST A FAILED: new function does not reproduce the inlined block');
fprintf('   PASS\n');

%% ---- TEST B: per-segment reduces to scalar when depths are equal ------
out_ps = shoal_mop_to_site(MOP, repmat(h_puv, nT, 1));
relerr_ps = max(abs(out_ps.spec(:) - spec_old(:))) / max(abs(spec_old(:)));
fprintf('\nTEST B  per-segment path with constant depth == scalar path\n');
fprintf('   max relative difference : %.3e\n', relerr_ps);
assert(relerr_ps < 1e-12, 'TEST B FAILED');
fprintf('   PASS\n');

% and that a real tidal swing actually changes the answer, in the right direction
h_tide = h_puv + 1.0*sin(2*pi*(0:nT-1)'/4);
out_td = shoal_mop_to_site(MOP, h_tide);
fprintf('   tidal swing %.1f-%.1f m changes Hs by %.1f%% (max)\n', ...
    min(h_tide), max(h_tide), ...
    100*max(abs(out_td.Hs - out.Hs)./out.Hs));
% Shallower water => more shoaling => larger Hs. Check the sign.
[~, iShallow] = min(h_tide);
[~, iDeep]    = max(h_tide);
ratio_shallow = out_td.Hs(iShallow)/out.Hs(iShallow);
ratio_deep    = out_td.Hs(iDeep)/out.Hs(iDeep);
fprintf('   Hs ratio at shallowest hour: %.4f (expect >1)\n', ratio_shallow);
fprintf('   Hs ratio at deepest    hour: %.4f (expect <1)\n', ratio_deep);
assert(ratio_shallow > 1 && ratio_deep < 1, 'TEST B FAILED: shoaling sign is wrong');
fprintf('   PASS (sign correct)\n');

%% ---- TEST C: refraction reduces energy, and Kr<=1 ---------------------
out_r = shoal_mop_to_site(MOP, h_puv, struct('theta_mop_deg', 30));
fprintf('\nTEST C  refraction (30 deg incidence at the model point)\n');
fprintf('   Kr range : %.4f - %.4f  (expect <= 1)\n', min(out_r.Kr), max(out_r.Kr));
fprintf('   Hs change vs no-refraction : %.2f%%\n', ...
    100*(mean(out_r.Hs)/mean(out.Hs) - 1));
assert(all(out_r.Kr <= 1+1e-12), 'TEST C FAILED: Kr > 1');
assert(mean(out_r.Hs) < mean(out.Hs), 'TEST C FAILED: refraction did not reduce energy');
fprintf('   PASS\n');

%% ---- TEST D: bin_spectrum_to_grid conserves variance ------------------
% Fine grid like a real PUV L2 spectrum (df = 2.78e-4 Hz)
df_fine = 2.78e-4;
f_fine  = (0:df_fine:1.0)';
S_fine  = exp(-((f_fine-fp).^2)/(2*sig^2)) + 0.02*exp(-((f_fine-0.22).^2)/(2*0.05^2));

[S_bin, fbw_out, cov] = bin_spectrum_to_grid(f_fine, S_fine, MOP.fbounds);

fprintf('\nTEST D  bin_spectrum_to_grid variance conservation\n');
% Per-bin: S_bin(j)*fbw(j) must equal the integral of S_fine over that bin
maxRel = 0;
for j = 1:nB
    inb = f_fine >= fLo(j) & f_fine <= fHi(j);
    % reference integral including exact edge handling
    fq  = [fLo(j); f_fine(f_fine > fLo(j) & f_fine < fHi(j)); fHi(j)];
    Sq  = interp1(f_fine, S_fine, fq, 'linear');
    ref = trapz(fq, Sq);
    got = S_bin(j) * fbw_out(j);
    maxRel = max(maxRel, abs(got-ref)/max(ref, eps));
end
fprintf('   max per-bin relative variance error : %.3e\n', maxRel);
fprintf('   coverage range : %.3f - %.3f\n', min(cov), max(cov));
assert(maxRel < 1e-9, 'TEST D FAILED: binning does not conserve variance');
fprintf('   PASS\n');

% Total variance over the binned band vs direct integration
m0_binned = sum(S_bin .* fbw_out);
inBand = f_fine >= fLo(1) & f_fine <= fHi(end);
m0_direct = trapz(f_fine(inBand), S_fine(inBand));
fprintf('   total m0 binned = %.6e, direct = %.6e, rel diff = %.3e\n', ...
    m0_binned, m0_direct, abs(m0_binned-m0_direct)/m0_direct);

%% ---- TEST E: multi-column input --------------------------------------
S_multi = [S_fine, 2*S_fine, 0.5*S_fine];
S_bin_m = bin_spectrum_to_grid(f_fine, S_multi, MOP.fbounds);
fprintf('\nTEST E  multi-column input\n');
fprintf('   size : [%d x %d] (expect [%d x 3])\n', size(S_bin_m,1), size(S_bin_m,2), nB);
err_m = max(max(abs(S_bin_m - [S_bin, 2*S_bin, 0.5*S_bin])));
fprintf('   max error vs scaled single-column : %.3e\n', err_m);
assert(size(S_bin_m,2)==3 && err_m < 1e-12, 'TEST E FAILED');
fprintf('   PASS\n');

fprintf('\n========== ALL PHASE 1a TESTS PASSED ==========\n\n');
