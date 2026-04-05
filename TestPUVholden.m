load 5m_16739_MOP580_processed.mat

idx=find(PUV.time < datetime(2023,5,10));

fs=2;
fw=0:0.005:fs/2;
bcor=[];

Cg=[];
%% precalculate bottom correction term
%   using C.S. Wu dispersion approx method
h=5; % depth
z=-4; % puv distance from surface z=0; (1m above bottom)
for n=1:numel(fw)
 f1=fw(n); Lo=9.81/(f1.^2*2*pi);
 
    % bottom kh
    uo=2*pi*h./Lo;
    kh=uo.*(1+(uo.^1.09).*exp(-(1.55+1.3*uo+0.216*uo.^2)))./sqrt(tanh(uo));
    Cg(n)=pi*(f1.*h./kh).*(1+2*kh./sinh(2*kh));

    % height above bottom kh
    uo=2*pi*(h+z)./Lo;
    khz=uo.*(1+(uo.^1.09).*exp(-(1.55+1.3*uo+0.216*uo.^2)))./sqrt(tanh(uo));

    % puv to surface correction
    bcor(n)=(cosh(kh)/cosh(khz)).^2;% bottom correction
    
end

%% step through p data in 2048 sample (~17 min) sections
ns=0; % segment counter
HsBP=[];
HsBPwelch=[];
HsSS=[];

stime=datetime([],[],[]);
for n=1:2048:idx(end)-2047
    ts=PUV.P(n:n+2047); % 17 minute pressure segment
    ns=ns+1;
    stime(ns)=PUV.time(n+2047); % end time of segment
    % uncorrect "Hs" based on detrended pressure variance
    HsBP(ns)=4*sqrt(var(detrend(ts),'omitnan')); 
   
% Use matlab pwelch power spectral density function to get
%  autospectra of p time series. [] = default welch window and overlap
  if sum(isnan(ts)) == 0
    [C11,f] = pwelch(detrend(ts),[],[],fw,fs);C11=C11*2; % scale power by 2 to get m^2/hz;
    idx=find(f < 0.25);
    HsBPwelch(ns)=4*sqrt(sum(0.005*C11(idx))); 
    %% use pwelch to make surface corrected spectra Hs
    HsSS(ns)=4*sqrt(sum(0.005*C11(idx).*bcor(idx),'omitnan')); 
  else
    HsBPwelch(ns)=NaN;  
    HsSS(ns)=NaN;
  end

end

% assume puv times are utc
stime=datetime(stime,'TimeZone','utc');

figure('position',[150         249        1150         510]);
% plot with three 17min record smoothing to make something hourly-ish
plot(stime,movmean(HsBP,3,'omitnan'),'linewidth',2,...
    'DisplayName','Raw Bottom Pressure Time Series Hs')
hold on;
% plot(stime,movmean(HsBPwelch,3,'omitnan'),'linewidth',2,...
%     'DisplayName','Bottom Pressure Welch Spectra Hs (w/ 0.25hz cutoff')
plot(stime,movmean(HsBPwelch,3,'omitnan'),'linewidth',2,...
    'DisplayName','Bottom Pressure Welch Spectra Hs (w/ 0.25hz cutoff')
plot(stime,movmean(HsSS,3,'omitnan'),'linewidth',2,...
    'DisplayName','Surface Corrected Welch Spectra Hs (w/ 0.25hz cutoff')

title('PUV Pressure, detrended 2048 sample (~17 min) records')
ylabel('Hs(m)');


%% ----   Add MOP 586 Hindcast

% MOP 586 hindcast
stn='D0586'; % TP Mop number

% create url pathname to CDIP thredds netcdf nowcast file
urlbase=...
 'http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';
urlend='_hindcast.nc';% get the MOP nowcast file
dsurl = strcat(urlbase,stn,urlend) 
moptime=ncread(dsurl,'waveTime');% read in netcdf wave times 
% convert mop unix time to local time pst
moptime=datetime(moptime,'ConvertFrom','posixTime',...
    'TimeZone','UTC');
% get energy densities and f bands
a0=ncread(dsurl,'waveEnergyDensity');
f=double(ncread(dsurl,'waveFrequency'));
bw=ncread(dsurl,'waveBandwidth');

idx=find(f < 0.25);
HsMop=4*sqrt(sum(bw(idx).*a0(idx,:))); % del mar buoy Hs with f=0.25Hz cutoff

hold on;

idx=find(moptime > stime(1) & moptime < stime(end));
plot(moptime(idx),HsMop(idx),'linewidth',2,...
    'DisplayName','MOP 586 Hs (0.25Hz cutoff)')

set(gca,'fontsize',16)
grid on
legend('location','southwest')



% % ----  Option to  Add Del Mar Nearshore Buoy Hs for nearest reference
% 
% buoyid='153';
% [freq,bw,ptime,a0,a1,b1,a2,b2]=getcdipbuoyAllnetcdf(buoyid);
% buoytime=datetime(ptime,'ConvertFrom','datenum','TimeZone','UTC');
% 
% % del mar buoy Hs using f=0.25Hz cutoff
% idx=find(freq < 0.25);
% Hsby=4*sqrt(sum(bw(idx).*a0(idx,:))); 
% 
% hold on;
% 
% idx=find(buoytime > stime(1) & buoytime < stime(end));
% plot(buoytime(idx),movmean(Hsby(idx),3,'omitnan'),'linewidth',2,...
%     'DisplayName','Del Mar Buoy #153 Hs (0.25Hz cutoff)')


