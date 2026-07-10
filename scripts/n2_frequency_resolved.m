function n2_frequency_resolved()
%N2_FREQUENCY_RESOLVED  Where, in frequency, does the recovered energy go missing?
%
% Five explanations for the Phase-A scale inconsistency have been eliminated (depth transfer,
% IG contamination, wave-height confound, period-dependent operator bias, noise floor by sign).
% Rather than propose a sixth mechanism and test it, localise the defect: compare spectra
% band by band.
%
% Quantities, all as MEDIANS over the hours in each window:
%   Vr(f)  = [Suu+Svv](10m, raw)  /  [Suu+Svv](7m)      velocity, uncorrected
%   Er(f)  = S_eta_rec(10m)       /  S_eta(7m)          reconstructed elevation vs 7 m
%   Zr(f)  = S_eta_rec(10m)       /  S_eta_meas(10m)    the z-test, frequency-resolved (control only)
%   Nz(f)  = the raw velocity spectra themselves, to see the noise floor move
%
% The diagnostic is the RATIO OF RATIOS between windows, e.g. Vr_PA(f)/Vr_ctrl(f).
%   - A pure velocity SCALE error  => flat in f, equal to (c_rec/c_true)^2 in variance.
%   - A spectral SHAPE change      => varies with f, and tells us which band moved.
%
% Windows: control = 22-24 Dec (c_fac = 1.000). Phase A = 26-29 Dec (c_fac ~ 1.05, fully
% corrupt thermistor). 25 Dec is EXCLUDED: c_fac is transitional (1.023) and pressure is
% partly alive, so it belongs to neither window.
%
% 2026-07-09.

startup_puv;
SP = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/rec/';
RAW = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/raw/';
g=9.81; rho=1025; fs=2; segLen=7200; nfft=256; doffp10=1.00; doffp7=0.67; KpMin=0.1;
t0=datetime(2023,11,14,12,0,2); Delta=2.7436;

D=readmatrix([SP 'dat10_win.csv'],'NumHeaderLines',1);
t=t0+seconds((D(:,1)-1)/2); u10=D(:,2); v10=D(:,3); cmin=D(:,5); p10=D(:,7);
S10=readtable([SP 'sen10_full.csv']); S7=readtable([SP 'sen7_full.csv']);
s10t=S10.time; s7t=S7.time;
if ~isdatetime(s10t), s10t=datetime(s10t); end
if ~isdatetime(s7t), s7t=datetime(s7t); end
L7=readtable([RAW 'L1_MOP586_7m.csv']); L7t=L7.time;
if ~isdatetime(L7t), L7t=datetime(L7t); end
h7tab=L7.P*1e4/(rho*g)+doffp7;

fprintf('loading 7 m L1...\n');
Q=load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L1/TOR23W/MOP586_7m_processed.mat');
t7=Q.PUV.time(:); u7=Q.PUV.BuoyCoord.U(:); v7=Q.PUV.BuoyCoord.V(:); p7=Q.PUV.P(:); clear Q
kk=t7>=t(1)&t7<=t(end); t7=t7(kk); u7=u7(kk); v7=v7(kk); p7=p7(kk);

f=(0:nfft/2)'*fs/nfft; nf=numel(f);
tSeg0=dateshift(t(1),'start','hour'); if tSeg0<t(1), tSeg0=tSeg0+hours(1); end
nSeg=floor(seconds(t(end)-tSeg0)/3600);

V10=nan(nf,nSeg); V7=nan(nf,nSeg); E10=nan(nf,nSeg); E7=nan(nf,nSeg); EM=nan(nf,nSeg);
tt=NaT(nSeg,1); FAC=nan(nSeg,1);

for i=1:nSeg
    ta=tSeg0+hours(i-1); tb=ta+hours(1); tt(i)=ta+minutes(30);
    m=t>=ta&t<tb; if sum(m)<segLen*0.99, continue; end
    idx=find(m,segLen,'first');
    if mean(cmin(idx)<70)>0.10, continue; end
    crec=mean(S10.c(s10t>=ta&s10t<tb),'omitnan'); ctru=mean(S7.c(s7t>=ta&s7t<tb),'omitnan');
    if ~isfinite(crec)||~isfinite(ctru), continue; end
    FAC(i)=ctru/crec;

    m7=t7>=ta&t7<tb; if sum(m7)<segLen*0.95, continue; end
    j=find(m7,segLen,'first');
    if mean(isnan(u7(j)))>0.05, continue; end
    uu7=fillmissing(u7(j),'linear'); vv7=fillmissing(v7(j),'linear'); pp7=fillmissing(p7(j),'linear');

    pm=mean(p10(idx)); pv = pm>4.7 && pm<18.8 && std(p10(idx))<2;
    H10 = pv*(pm*1e4/(rho*g)+doffp10) + ~pv*(interp1(datenum(L7t),h7tab,datenum(tt(i)),'linear',NaN)+Delta);
    H7  = mean(pp7)*1e4/(rho*g)+doffp7;
    if ~isfinite(H10)||~isfinite(H7), continue; end

    % raw (uncorrected) velocity spectra, both frames
    [a1,~]=pwelch(detrend(u10(idx)),hann(nfft),nfft/2,nfft,fs);
    [a2,~]=pwelch(detrend(v10(idx)),hann(nfft),nfft/2,nfft,fs);
    [b1,~]=pwelch(detrend(uu7),hann(nfft),nfft/2,nfft,fs);
    [b2,~]=pwelch(detrend(vv7),hann(nfft),nfft/2,nfft,fs);
    V10(:,i)=a1+a2; V7(:,i)=b1+b2;

    % reconstructed S_eta at 10 m, from c-CORRECTED velocity
    E10(:,i)=seta_from_vel((a1+a2)*FAC(i)^2, f, H10, doffp10, KpMin, g);

    % 7 m S_eta from its own (healthy) pressure
    [Sp7,~]=pwelch(detrend(pp7*1e4/(rho*g)),hann(nfft),nfft/2,nfft,fs);
    E7(:,i)=pressure_correction_wu(Sp7,f,H7,doffp7,KpMin);

    % 10 m measured S_eta, where pressure lives
    if pv
        [Sp10,~]=pwelch(detrend(p10(idx)*1e4/(rho*g)),hann(nfft),nfft/2,nfft,fs);
        EM(:,i)=pressure_correction_wu(Sp10,f,H10,doffp10,KpMin);
    end
end

C = tt>=datetime(2023,12,22) & tt<datetime(2023,12,25) & isfinite(FAC);
P = tt>=datetime(2023,12,26) & tt<datetime(2023,12,30) & isfinite(FAC);
fprintf('\ncontrol n=%d (c_fac %.4f)   Phase A n=%d (c_fac %.4f)\n', ...
    sum(C), median(FAC(C),'omitnan'), sum(P), median(FAC(P),'omitnan'));

med=@(X,s) median(X(:,s),2,'omitnan');
bands=[0.040 0.055; 0.055 0.070; 0.070 0.090; 0.090 0.120; 0.120 0.160; 0.160 0.200; 0.200 0.250; 0.600 0.950];
bn={'0.040-0.055','0.055-0.070','0.070-0.090','0.090-0.120','0.120-0.160','0.160-0.200','0.200-0.250','0.60-0.95 (noise)'};

fprintf('\n========= VELOCITY (raw, uncorrected): [Suu+Svv] 10m / 7m =========\n');
fprintf('%-20s %10s %10s %12s %14s\n','band (Hz)','control','Phase A','PA/ctrl','implied c ratio');
for b=1:size(bands,1)
    s=f>=bands(b,1)&f<bands(b,2);
    rc=sum(med(V10,C).*s)/sum(med(V7,C).*s); rp=sum(med(V10,P).*s)/sum(med(V7,P).*s);
    fprintf('%-20s %10.4f %10.4f %12.4f %14.4f\n', bn{b}, rc, rp, rp/rc, sqrt(rp/rc));
end
fprintf('\nA pure velocity scale error => "implied c ratio" is FLAT across the wave bands\n');
fprintf('and equals c_rec/c_true = %.4f.  The noise band is not a wave band; it should NOT\n', 1/median(FAC(P),'omitnan'));
fprintf('follow the same law, and if it grew it tells us the Doppler noise changed.\n');

fprintf('\n========= RECONSTRUCTED ELEVATION: S_eta_rec(10m) / S_eta(7m) =========\n');
fprintf('(velocity already c-corrected; a flat ratio-of-ratios = 1.000 would mean the\n');
fprintf(' correction is exactly right in that band)\n');
fprintf('%-20s %10s %10s %12s\n','band (Hz)','control','Phase A','PA/ctrl');
for b=1:size(bands,1)-1
    s=f>=bands(b,1)&f<bands(b,2);
    rc=sum(med(E10,C).*s)/sum(med(E7,C).*s); rp=sum(med(E10,P).*s)/sum(med(E7,P).*s);
    fprintf('%-20s %10.4f %10.4f %12.4f\n', bn{b}, rc, rp, rp/rc);
end

fprintf('\n========= FREQUENCY-RESOLVED Z-TEST (control only): S_eta_rec / S_eta_meas, 10 m =========\n');
fprintf('%-20s %10s\n','band (Hz)','rec/meas');
for b=1:size(bands,1)-1
    s=f>=bands(b,1)&f<bands(b,2);
    fprintf('%-20s %10.4f\n', bn{b}, sum(med(E10,C).*s)/sum(med(EM,C).*s));
end

fprintf('\n========= NOISE FLOOR, raw velocity PSD at 0.60-0.95 Hz =========\n');
s=f>=0.60&f<=0.95;                                  % MATLAB has no chained indexing on a call
v10c=med(V10,C); v10p=med(V10,P); v7c=med(V7,C); v7p=med(V7,P);
fprintf('  10 m: control %.4e   Phase A %.4e   ratio %.2fx\n', mean(v10c(s)), mean(v10p(s)), mean(v10p(s))/mean(v10c(s)));
fprintf('   7 m: control %.4e   Phase A %.4e   ratio %.2fx\n', mean(v7c(s)),  mean(v7p(s)),  mean(v7p(s))/mean(v7c(s)));

save([SP 'n2_freq.mat'],'f','V10','V7','E10','E7','EM','tt','FAC','C','P','-v7.3');
fprintf('\nsaved n2_freq.mat\n');
end

function S_eta = seta_from_vel(Svel, f, H, doffp, KpMin, g)
om=2*pi*f; k=zeros(size(f)); k(2:end)=get_wavenumber(om(2:end),H);
u2p=zeros(size(f)); u2p(2:end)=om(2:end)./(g*k(2:end));
S_eta = pressure_correction_wu(Svel.*u2p.^2, f, H, doffp, KpMin);
end
