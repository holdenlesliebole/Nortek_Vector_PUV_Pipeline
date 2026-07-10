function validate_recovery_MOP586_10m()
%VALIDATE_RECOVERY_MOP586_10M  External validation of the Phase-A recovery.
%
% recover_MOP586_10m_phaseA proved the recovery INTERNALLY (the reconstruction reproduces
% the frame's own measured Hs on healthy hours, and the sound-speed factor is recovered
% two independent ways). That is necessary but not sufficient: both checks live inside the
% same instrument. This script checks the recovered bursts against two EXTERNAL references
% that know nothing about the 10 m frame:
%
%   (1) the CDIP MOP D0586 hindcast at the 10-m contour
%   (2) the co-located, fully healthy MOP586_7m PUV
%
% CONTROL. Both comparisons are first run on the HEALTHY hours (22-24 Dec), where the 10 m
% frame's own pressure sensor works. That fixes the expected offset between the frame and
% each reference. The Phase-A hours must then reproduce the SAME offset. A recovery that
% merely produced plausible numbers would not.
%
% FALSIFIER. If Phase-A Hs_rec / D0586 departs from the healthy Hs_meas / D0586 ratio by
% more than the healthy scatter, the recovery is wrong and Phase A stays quarantined.
%
% 2026-07-09.

startup_puv;
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
SP = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/rec/';
S = load([SP 'recover_10m_phaseA.mat']); R = S.R;

cal = 0.9747;                          % from the healthy-hour z-test; see recover_..._phaseA
Hs_rec = cal * R.Hs_rec;

% ---- reference 1: CDIP MOP D0586 ----
for a = 1:5
    try, M = read_MOPline2('D0586', datetime(2023,12,21), datetime(2023,12,31)); break
    catch, pause(5); end
end
tM = M.time; if ~isdatetime(tM), tM = datetime(tM,'ConvertFrom','datenum'); end
hsMOP = interp1(datenum(tM), M.Hs, datenum(R.t), 'linear', NaN);

% ---- reference 2: the healthy 7 m PUV ----
L = load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TOR23W/MOP586_7m_L2.mat','L2');
t7 = L.L2.time(:); if ~isdatetime(t7), t7 = datetime(t7,'ConvertFrom','datenum'); end
t7.TimeZone = '';
hs7 = L.L2.Hs(:); ok7 = L.L2.segValid(:);
hs7i = interp1(datenum(t7(ok7)), hs7(ok7), datenum(R.t), 'linear', NaN);

H  = R.t <  datetime(2023,12,25) & R.segValid_vel & R.segValid_p;   % control
P  = R.t >= datetime(2023,12,25) & R.t < datetime(2023,12,30) & R.segValid_vel;
PA = P & ~R.segValid_p;                                             % purely reconstructed

fprintf('\n============ EXTERNAL VALIDATION OF THE PHASE-A RECOVERY ============\n');
fprintf('control (Dec 22-24, pressure alive): n=%d\n', sum(H));
fprintf('Phase A (Dec 25-29, velocity only) : n=%d\n', sum(PA));

fprintf('\n-- vs CDIP MOP D0586 (10-m contour) --\n');
rH = R.Hs_meas(H)./hsMOP(H);      % what the frame reads when it is healthy
rP = Hs_rec(PA)./hsMOP(PA);       % what the recovery reads
show('control  Hs_meas / D0586', rH);
show('Phase A  Hs_rec  / D0586', rP);
uncal = R.Hs_rec(PA)./hsMOP(PA);
show('  (uncalibrated Hs_rec)  ', uncal);

fprintf('\n-- vs MOP586_7m PUV (healthy throughout) --\n');
qH = R.Hs_meas(H)./hs7i(H);
qP = Hs_rec(PA)./hs7i(PA);
show('control  Hs_meas / Hs_7m', qH);
show('Phase A  Hs_rec  / Hs_7m', qP);

fprintf('\n-- the 10 hours inside Phase A where pressure survived: direct check --\n');
B = P & R.segValid_p;
if sum(B) >= 3
    fprintf('  n=%d   Hs_rec/Hs_meas = %.4f  [%.4f %.4f]\n', sum(B), ...
        median(Hs_rec(B)./R.Hs_meas(B),'omitnan'), min(Hs_rec(B)./R.Hs_meas(B)), max(Hs_rec(B)./R.Hs_meas(B)));
    fprintf('  (reconstructed vs measured, on the SAME bursts, inside the failed window)\n');
else
    fprintf('  too few\n');
end

fprintf('\n-- verdict --\n');
dMOP = abs(median(rP,'omitnan') - median(rH,'omitnan'));
d7   = abs(median(qP,'omitnan') - median(qH,'omitnan'));
sMOP = iqr(rH(isfinite(rH))); s7 = iqr(qH(isfinite(qH)));
fprintf('  shift in the D0586 ratio, control -> Phase A : %+.4f   (control IQR %.4f)\n', ...
    median(rP,'omitnan')-median(rH,'omitnan'), sMOP);
fprintf('  shift in the 7 m   ratio, control -> Phase A : %+.4f   (control IQR %.4f)\n', ...
    median(qP,'omitnan')-median(qH,'omitnan'), s7);
if dMOP < sMOP && d7 < s7
    fprintf('  PASS: the recovered bursts sit at the same offset from both external\n');
    fprintf('        references as the frame does when it is healthy.\n');
else
    fprintf('  FAIL: recovery shifts the offset beyond the healthy scatter. Quarantine.\n');
end

fprintf('\n-- the storm peak, hour by hour (28-29 Dec) --\n');
fprintf('%-18s %9s %9s %9s %8s %7s %6s\n','hour','Hs_rec','D0586','Hs_7m','c_fac','fbad%','flag');
sel = find(R.t >= datetime(2023,12,28,12,0,0) & R.t < datetime(2023,12,29,18,0,0) & R.segValid_vel);
for i = sel(:)'
    fprintf('%-18s %9.2f %9.2f %9.2f %8.4f %7.2f %6d\n', datestr(R.t(i),'mm-dd HH:MM'), ...
        Hs_rec(i), hsMOP(i), hs7i(i), R.c_factor(i), 100*R.fbad(i), R.qc_flag(i));
end
end

function show(name, r)
r = r(isfinite(r));
if numel(r) < 3, fprintf('  %-26s (too few)\n', name); return; end
fprintf('  %-26s median %.4f   IQR [%.4f %.4f]   n=%d\n', name, median(r), prctile(r,25), prctile(r,75), numel(r));
end
