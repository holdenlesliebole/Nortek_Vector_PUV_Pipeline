% R1/R2/R3 for the Stage-1/2 real-data regression at TOR23W/MOP586_10m.
startup_puv;
SCRATCH='/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/regress';
N=load(fullfile(SCRATCH,'MOP586_10m_L2_new.mat')); Lnew=N.L2new;
O=load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TOR23W/MOP586_10m_L2.mat','L2'); Lold=O.L2;
tn=Lnew.time(:); to=Lold.time(:);
fprintf('\n================ STAGE 1/2 REAL-DATA REGRESSION ================\n');
fprintf('old L2: %d segments, %d valid\n', numel(to), sum(Lold.segValid));
fprintf('new L2: %d segments, %d valid (segValid, old semantics)\n', numel(tn), sum(Lnew.segValid));
fprintf('new L2: %d segValid_vel, %d segValid_p\n', sum(Lnew.segValid_vel), sum(Lnew.segValid_p));

% align on time
[tc,ia,ib] = intersect(tn,to);
fprintf('\n%d segments align by timestamp\n', numel(tc));

%% R1: on segments valid under BOTH, the change must be a no-op
both = Lnew.segValid(ia) & Lold.segValid(ib);
fn = {'Hs','Hs_SS','Tp','Ub','depth','uMean','ztest_SS'};
fprintf('\nR1  no-op on healthy data (segments valid in both, n=%d)\n', sum(both));
worst = 0;
for k=1:numel(fn)
    a=Lnew.(fn{k})(ia); b=Lold.(fn{k})(ib);
    d=max(abs(a(both)-b(both)),[],'omitnan'); worst=max(worst,d);
    fprintf('    max |Delta %-9s| = %.3e\n', fn{k}, d);
end
a=Lnew.vmom.skewness(ia); b=Lold.vmom.skewness(ib);
d=max(abs(a(both)-b(both)),[],'omitnan'); worst=max(worst,d);
fprintf('    max |Delta %-9s| = %.3e\n','skewness', d);
a=Lnew.vmom.u_uabs2(ia); b=Lold.vmom.u_uabs2(ib);
d=max(abs(a(both)-b(both)),[],'omitnan'); worst=max(worst,d);
fprintf('    max |Delta %-9s| = %.3e\n','u_uabs2', d);
if worst < 1e-9, fprintf('  -> PASS: healthy segments unchanged (worst %.2e)\n', worst);
else, fprintf('  -> INSPECT: worst difference %.3e\n', worst); end

%% R2: recovered segments
rec = Lnew.segValid_vel(ia) & ~Lold.segValid(ib);
fprintf('\nR2  segments the OLD pipeline discarded that now carry velocity moments: %d\n', sum(rec));
if any(rec)
    tr = tn(ia(rec));
    fprintf('    span %s -> %s\n', datestr(min(tr)), datestr(max(tr)));
    fprintf('    of which in 25-29 Dec 2023: %d\n', sum(tr>=datetime(2023,12,25,'TimeZone','UTC') & tr<datetime(2023,12,30,'TimeZone','UTC')));
    fprintf('    all have qc_flag = 3? %s\n', string(all(Lnew.qc_flag(ia(rec))==3)));
    fprintf('    all have segValid = false? %s  (old consumers cannot see them)\n', string(~any(Lnew.segValid(ia(rec)))));
    fprintf('    Hs is NaN for all of them? %s\n', string(all(isnan(Lnew.Hs(ia(rec))))));
    sk = Lnew.vmom.skewness(ia(rec));
    fprintf('    velocity skewness on recovered segments: median %.4f, %d finite\n', median(sk,'omitnan'), sum(isfinite(sk)));
end

%% R3: sound-speed rescale fired only where the thermistor failed
fprintf('\nR3  sound-speed rescale\n');
nC = sum(Lnew.vel_c_corrected);
fprintf('    segments rescaled: %d\n', nC);
if nC>0
    tcz = tn(Lnew.vel_c_corrected);
    fprintf('    span %s -> %s\n', datestr(min(tcz)), datestr(max(tcz)));
    fprintf('    median factor %.4f (range %.4f - %.4f)\n', ...
        median(Lnew.vel_c_factor(Lnew.vel_c_corrected)), min(Lnew.vel_c_factor(Lnew.vel_c_corrected)), max(Lnew.vel_c_factor(Lnew.vel_c_corrected)));
    % A rescaled segment whose velocity is ALSO unusable is a failure, not a suspect result.
    % Assert on the usable ones only; assert the unusable ones are qc_flag = 4.
    usable = Lnew.vel_c_corrected & (Lnew.segValid_vel | Lnew.segValid_p);
    fprintf('    usable rescaled segments: %d, all qc_flag=3? %s\n', sum(usable), string(all(Lnew.qc_flag(usable)==3)));
    fprintf('    unusable rescaled segments: %d, all qc_flag=4? %s\n', sum(Lnew.vel_c_corrected & ~usable), ...
        string(all(Lnew.qc_flag(Lnew.vel_c_corrected & ~usable)==4)));
    fprintf('    any qc_flag=1 segment rescaled? %d (must be 0)\n', sum(Lnew.qc_flag==1 & Lnew.vel_c_corrected));
end
pre = tn < datetime(2023,12,25,'TimeZone','UTC');
fprintf('    rescale applied before 25 Dec (must be ZERO): %d\n', sum(Lnew.vel_c_corrected & pre));
fprintf('    vel_c_factor on pre-25-Dec segments: max |f-1| = %.3e (must be 0)\n', max(abs(Lnew.vel_c_factor(pre)-1)));
fprintf('\nREGRESS_COMPARE_DONE\n');
