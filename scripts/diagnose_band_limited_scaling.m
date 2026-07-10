function diagnose_band_limited_scaling()
%DIAGNOSE_BAND_LIMITED_SCALING  Is "velocity ~ sound speed" being validated against a
% contaminated statistic?
%
% Two measurements of the same Phase-A deflation disagree:
%   broadband urms(10m)/urms(7m) : restored to within 0.6% by the c_true/c_rec rescale
%   band-limited Hs(10m)/Hs(7m)  : still 2.6% low after the same rescale
%
% Broadband urms integrates the Doppler NOISE FLOOR, which is white and independent of the
% wave field. Under the storm the 10 m frame's beam correlation fell 96 -> 93 and amplitude
% rose 100 -> 136 counts, both of which change the noise floor. So the broadband statistic
% is not a clean measure of wave-orbital velocity, and the 0.55% agreement I reported
% between the urms deflation and the sound-speed ratio may be partly coincidence.
%
% The band-limited orbital velocity variance in the sea-swell band (0.04-0.25 Hz) is the
% honest statistic: it excludes the noise floor and the mean flow.
%
%   Q1  What is the SS-band velocity-variance ratio 10m/7m, control vs Phase A?
%   Q2  Does the c_true/c_rec rescale restore THAT ratio to its healthy value?
%   Q3  Estimate the Doppler noise floor from the 0.6-1.0 Hz band (far above the waves)
%       and check whether it grew in Phase A by enough to explain the urms agreement.
%
% If Q2 says the rescale over- or under-corrects the in-band variance, then the recorded
% velocity is NOT simply proportional to the reported sound speed, and the recovery needs
% a different (or an additional) correction. That would be a real finding, not a nuisance.
%
% 2026-07-09.

startup_puv;
SP = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/rec/';
fs=2; nfft=256; segLen=7200; t0=datetime(2023,11,14,12,0,2);

D = readmatrix([SP 'dat10_win.csv'],'NumHeaderLines',1);
t = t0 + seconds((D(:,1)-1)/2); u10=D(:,2); v10=D(:,3); cmin=D(:,5);
S10 = readtable([SP 'sen10_full.csv']); S7 = readtable([SP 'sen7_full.csv']);
s10t=S10.time; s7t=S7.time;
if ~isdatetime(s10t), s10t=datetime(s10t); end
if ~isdatetime(s7t), s7t=datetime(s7t); end

fprintf('loading 7 m L1 (large)...\n');
Q = load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L1/TOR23W/MOP586_7m_processed.mat');
t7 = Q.PUV.time(:); u7=Q.PUV.BuoyCoord.U(:); v7=Q.PUV.BuoyCoord.V(:); clear Q
keep = t7>=t(1) & t7<=t(end); t7=t7(keep); u7=u7(keep); v7=v7(keep);

f=(0:nfft/2)'*fs/nfft;
iSS = f>=0.04 & f<=0.25;
iNZ = f>=0.60 & f<=0.95;          % well above the wave band: Doppler noise floor

tSeg0=dateshift(t(1),'start','hour'); if tSeg0<t(1), tSeg0=tSeg0+hours(1); end
nSeg=floor(seconds(t(end)-tSeg0)/3600);
tt=NaT(nSeg,1); V10=nan(nSeg,1); V7=nan(nSeg,1); N10=nan(nSeg,1); N7=nan(nSeg,1);
FAC=nan(nSeg,1); FB=nan(nSeg,1);

for i=1:nSeg
    ta=tSeg0+hours(i-1); tb=ta+hours(1); tt(i)=ta+minutes(30);
    m=t>=ta & t<tb; if sum(m)<segLen*0.99, continue; end
    idx=find(m,segLen,'first');
    FB(i)=mean(cmin(idx)<70); if FB(i)>0.10, continue; end
    crec=mean(S10.c(s10t>=ta & s10t<tb),'omitnan');
    ctru=mean(S7.c (s7t >=ta & s7t <tb),'omitnan');
    if ~isfinite(crec)||~isfinite(ctru), continue; end
    FAC(i)=ctru/crec;

    [a,~]=pwelch(detrend(u10(idx)),hann(nfft),nfft/2,nfft,fs);
    [b,~]=pwelch(detrend(v10(idx)),hann(nfft),nfft/2,nfft,fs);
    V10(i)=trapz(f(iSS),a(iSS)+b(iSS));           % raw, uncorrected
    N10(i)=mean(a(iNZ)+b(iNZ));

    m7=t7>=ta & t7<tb;
    if sum(m7)>=segLen*0.95
        j=find(m7,segLen,'first');
        uu=u7(j); vv=v7(j);
        if mean(isnan(uu))>0.05, continue; end
        uu=fillmissing(uu,'linear'); vv=fillmissing(vv,'linear');
        [c1,~]=pwelch(detrend(uu),hann(nfft),nfft/2,nfft,fs);
        [c2,~]=pwelch(detrend(vv),hann(nfft),nfft/2,nfft,fs);
        V7(i)=trapz(f(iSS),c1(iSS)+c2(iSS));
        N7(i)=mean(c1(iNZ)+c2(iNZ));
    end
end

H0 = tt<datetime(2023,12,25) & isfinite(V10) & isfinite(V7);
PA = tt>=datetime(2023,12,25) & tt<datetime(2023,12,30) & isfinite(V10) & isfinite(V7);

fprintf('\n============ BAND-LIMITED ORBITAL VELOCITY SCALING ============\n');
fprintf('control n=%d, Phase A n=%d\n\n', sum(H0), sum(PA));

% amplitude ratio = sqrt(variance ratio)
rH = sqrt(V10(H0)./V7(H0));
rP = sqrt(V10(PA)./V7(PA));
fprintf('Q1  SS-band orbital amplitude ratio 10m/7m, RAW (no c correction)\n');
fprintf('    control : %.4f   [%.4f %.4f]\n', median(rH), prctile(rH,25), prctile(rH,75));
fprintf('    Phase A : %.4f   [%.4f %.4f]\n', median(rP), prctile(rP,25), prctile(rP,75));
defl = median(rP)/median(rH);
fprintf('    in-band deflation = %.4f\n', defl);

fprintf('\nQ2  Does the sound-speed rescale explain that deflation?\n');
cf = median(FAC(PA),'omitnan');
fprintf('    applied rescale c_true/c_rec = %.4f  => corrects deflation %.4f -> %.4f\n', ...
    cf, defl, defl*cf);
fprintf('    required rescale to close it = %.4f  (i.e. c_rec/c_true would have to be %.4f)\n', ...
    1/defl, defl);
fprintf('    shortfall = %.2f%%\n', 100*(defl*cf - 1));

fprintf('\n    For comparison, the BROADBAND urms deflation reported earlier was 0.9457,\n');
fprintf('    and c_true/c_rec = %.4f would correct it to %.4f.\n', cf, 0.9457*cf);

fprintf('\nQ3  Doppler noise floor (0.60-0.95 Hz), which contaminates broadband urms\n');
fprintf('    10 m: control %.3e   Phase A %.3e   ratio %.2fx\n', ...
    median(N10(H0),'omitnan'), median(N10(PA),'omitnan'), median(N10(PA),'omitnan')/median(N10(H0),'omitnan'));
fprintf('     7 m: control %.3e   Phase A %.3e   ratio %.2fx\n', ...
    median(N7(H0),'omitnan'), median(N7(PA),'omitnan'), median(N7(PA),'omitnan')/median(N7(H0),'omitnan'));
fprintf('    A noise floor that GREW at 10 m inflates broadband urms and would make the\n');
fprintf('    earlier 0.55%% agreement optimistic. A floor that did not grow leaves the\n');
fprintf('    urms-vs-Hs discrepancy unexplained -- say so rather than pick a story.\n');

save([SP 'band_limited.mat'],'tt','V10','V7','N10','N7','FAC','-v7.3');
end
