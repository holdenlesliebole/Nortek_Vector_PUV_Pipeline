function diagnose_phaseA_deficit()
%DIAGNOSE_PHASEA_DEFICIT  Why does the recovered Hs read ~2.6% low against the 7 m frame?
%
% test_hs_ratio_confound REFUTED the wave-height-confound explanation: the healthy
% Hs10/Hs7 ratio is flat (0.960-0.976) and does not fall to the observed Phase-A 0.935.
% So the deficit is real. Three candidate causes, each with a distinct signature:
%
%   D1  the sound-speed rescale is UNDER-applied
%       => the deficit should grow with c_fac (1.023 on Dec 25 -> 1.055 on Dec 28)
%   D2  the transferred depth H is biased
%       => the deficit should be flat in c_fac, and should vanish on the 10 hours where
%          the pressure sensor still supplied a measured H
%   D3  the reconstruction's low-frequency (IG) band is contaminated
%       => the deficit should vanish when Hs is computed over the sea-swell band alone.
%          Spp_from_vel ~ Suu*(omega/gk)^2 blows up as f->0, so any turbulence or mean-flow
%          leakage at 0.008-0.04 Hz is amplified. The MEASURED control has real IG energy
%          there; the reconstruction has noise. This is a genuine wart in the method.
%
% D1/D2/D3 are not exclusive. Report all three signatures rather than pick one.
%
% 2026-07-09.

startup_puv;
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
SP = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/rec/';
RAW = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/raw/';

g=9.81; rho=1025; fs=2; segLen=7200; nfft=256; doffp10=1.00; doffp7=0.67; KpMin=0.1;
t0 = datetime(2023,11,14,12,0,2);
fIG=[0.004 0.04]; fSS=[0.04 0.25];

D = readmatrix([SP 'dat10_win.csv'],'NumHeaderLines',1);
t = t0 + seconds((D(:,1)-1)/2); u=D(:,2); v=D(:,3); cmin=D(:,5); pdb=D(:,7);
S10 = readtable([SP 'sen10_full.csv']); S7 = readtable([SP 'sen7_full.csv']);
s10t=S10.time; s7t=S7.time;
if ~isdatetime(s10t), s10t=datetime(s10t); end
if ~isdatetime(s7t), s7t=datetime(s7t); end
L7 = readtable([RAW 'L1_MOP586_7m.csv']); L7t=L7.time;
if ~isdatetime(L7t), L7t=datetime(L7t); end
h7 = L7.P*1e4/(rho*g)+doffp7;
Delta = 2.7436;

f = (0:nfft/2)'*fs/nfft;
iTot = f>=fIG(1) & f<=fSS(2);
iSS  = f>=fSS(1) & f<=fSS(2);

tSeg0 = dateshift(t(1),'start','hour'); if tSeg0<t(1), tSeg0=tSeg0+hours(1); end
nSeg = floor(seconds(t(end)-tSeg0)/3600);
Z = nan(nSeg,10);   % t, HsTot_rec, HsSS_rec, HsTot_meas, HsSS_meas, cfac, Hmeas, Htrans, fbad, pvalid
tt = NaT(nSeg,1);

for i=1:nSeg
    ta=tSeg0+hours(i-1); tb=ta+hours(1);
    m = t>=ta & t<tb; if sum(m)<segLen*0.99, continue; end
    idx = find(m,segLen,'first'); tt(i)=ta+minutes(30);
    fbad = mean(cmin(idx)<70); if fbad>0.10, continue; end
    crec = mean(S10.c(s10t>=ta & s10t<tb),'omitnan');
    ctru = mean(S7.c (s7t >=ta & s7t <tb),'omitnan');
    if ~isfinite(crec)||~isfinite(ctru), continue; end
    fac = ctru/crec;
    pm = mean(pdb(idx)); pv = pm>4.7 && pm<18.8 && std(pdb(idx))<2;
    Hm = pm*1e4/(rho*g)+doffp10;
    Ht = interp1(datenum(L7t),h7,datenum(tt(i)),'linear',NaN)+Delta;
    H  = Ht; if pv, H = Hm; end
    if ~isfinite(H), continue; end

    uu=detrend(u(idx))*fac; vv=detrend(v(idx))*fac;
    [Suu,~]=pwelch(uu,hann(nfft),nfft/2,nfft,fs);
    [Svv,~]=pwelch(vv,hann(nfft),nfft/2,nfft,fs);
    om=2*pi*f; k=zeros(size(f)); k(2:end)=get_wavenumber(om(2:end),H);
    u2p=zeros(size(f)); u2p(2:end)=om(2:end)./(g*k(2:end));
    Se = pressure_correction_linear((Suu+Svv).*u2p.^2, f, H, doffp10, KpMin);
    Z(i,2)=4*sqrt(max(trapz(f(iTot),Se(iTot)),0));
    Z(i,3)=4*sqrt(max(trapz(f(iSS ),Se(iSS )),0));
    if pv
        [Spp,~]=pwelch(detrend(pdb(idx)*1e4/(rho*g)),hann(nfft),nfft/2,nfft,fs);
        Sm = pressure_correction_linear(Spp,f,H,doffp10,KpMin);
        Z(i,4)=4*sqrt(max(trapz(f(iTot),Sm(iTot)),0));
        Z(i,5)=4*sqrt(max(trapz(f(iSS ),Sm(iSS )),0));
    end
    Z(i,6)=fac; Z(i,7)=Hm; Z(i,8)=Ht; Z(i,9)=fbad; Z(i,10)=pv;
end

% 7 m reference, sea-swell band
L=load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TOR23W/MOP586_7m_L2.mat','L2');
t7=L.L2.time(:); if ~isdatetime(t7), t7=datetime(t7,'ConvertFrom','datenum'); end
t7.TimeZone=''; ok=logical(L.L2.segValid(:));
hs7  = interp1(datenum(t7(ok)), L.L2.Hs(ok),    datenum(tt),'linear',NaN);
hs7ss= interp1(datenum(t7(ok)), L.L2.Hs_SS(ok), datenum(tt),'linear',NaN);

H0 = tt <  datetime(2023,12,25) & isfinite(Z(:,2)) & Z(:,10)==1;
PA = tt >= datetime(2023,12,25) & tt < datetime(2023,12,30) & isfinite(Z(:,2));

fprintf('\n============ WHY IS THE RECOVERED Hs LOW? ============\n');
fprintf('control n=%d, Phase A n=%d\n', sum(H0), sum(PA));

fprintf('\n--- D3: total band vs sea-swell band ---\n');
fprintf('  control  Hs_tot_rec/Hs_tot_meas = %.4f   Hs_SS_rec/Hs_SS_meas = %.4f\n', ...
    median(Z(H0,2)./Z(H0,4),'omitnan'), median(Z(H0,3)./Z(H0,5),'omitnan'));
fprintf('  control  Hs_tot_rec/Hs7_tot     = %.4f   Hs_SS_rec/Hs7_SS     = %.4f\n', ...
    median(Z(H0,2)./hs7(H0),'omitnan'), median(Z(H0,3)./hs7ss(H0),'omitnan'));
fprintf('  PhaseA   Hs_tot_rec/Hs7_tot     = %.4f   Hs_SS_rec/Hs7_SS     = %.4f\n', ...
    median(Z(PA,2)./hs7(PA),'omitnan'), median(Z(PA,3)./hs7ss(PA),'omitnan'));
fprintf('  If the SS-band ratios match between control and Phase A, D3 explains it.\n');

fprintf('\n--- D1: does the deficit track the sound-speed factor? ---\n');
fprintf('%-12s %5s %8s %12s %12s %12s\n','day','n','c_fac','Hs_tot/Hs7','Hs_SS/Hs7','fbad%');
dd = datetime(2023,12,22);
while dd < datetime(2023,12,30)
    s = tt>=dd & tt<dd+days(1) & isfinite(Z(:,2));
    if any(s)
        fprintf('%-12s %5d %8.4f %12.4f %12.4f %12.2f\n', datestr(dd,'yyyy-mm-dd'), sum(s), ...
            median(Z(s,6),'omitnan'), median(Z(s,2)./hs7(s),'omitnan'), ...
            median(Z(s,3)./hs7ss(s),'omitnan'), 100*mean(Z(s,9),'omitnan'));
    end
    dd = dd + days(1);
end
fprintf('  D1 signature: the ratio falls as c_fac rises (Dec 25 -> Dec 28).\n');
fprintf('  D2/D3 signature: the ratio is flat across those days.\n');

fprintf('\n--- D2: measured H vs transferred H on the SAME bursts ---\n');
B = tt>=datetime(2023,12,25) & Z(:,10)==1 & isfinite(Z(:,7)) & isfinite(Z(:,8));
if sum(B)>=3
    fprintf('  n=%d  H_meas - H_trans = %+.4f m (median), |max| %.4f m\n', sum(B), ...
        median(Z(B,7)-Z(B,8),'omitnan'), max(abs(Z(B,7)-Z(B,8))));
else
    fprintf('  too few pressure-valid Phase-A hours to compare\n');
end
Bh = H0 & isfinite(Z(:,7)) & isfinite(Z(:,8));
fprintf('  control: H_meas - H_trans = %+.4f m (median), sd %.4f m, n=%d\n', ...
    median(Z(Bh,7)-Z(Bh,8),'omitnan'), std(Z(Bh,7)-Z(Bh,8),'omitnan'), sum(Bh));

save([SP 'diagnose_phaseA.mat'],'Z','tt','hs7','hs7ss','-v7.3');
end
