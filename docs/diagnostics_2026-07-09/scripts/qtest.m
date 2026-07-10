addpath('/Users/holden/Documents/Scripps/Research/toolbox');
d='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TBR23/';
m=matfile([d 'MOP586_5m_L2.mat']); L2=m.L2;
fprintf('qtest_PU size: %s   phase_PU size: %s\n', mat2str(size(L2.qtest_PU)), mat2str(size(L2.phase_PU)));
fprintf('nSeg=%d\n', numel(L2.time));
q=L2.qtest_PU; fprintf('qtest_PU: p01=%.3f p05=%.3f p50=%.3f p95=%.3f  frac>0.75 = %.1f%%\n', ...
  prctile(q(:),1),prctile(q(:),5),median(q(:),'omitnan'),prctile(q(:),95),100*mean(q(:)>0.75,'omitnan'));
clear L2 m

for a=1:4, try, MP=read_MOPline2('D0586',datetime(2022,10,1),datetime(2023,10,1)); break; catch, pause(5); end, end
tM=MP.time; if ~isdatetime(tM), tM=datetime(tM,'ConvertFrom','datenum'); end
he=[0 0.5 0.75 1 1.25 8]; hn={'<0.5','0.5-.75','.75-1','1-1.25','>1.25'};
labs={'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'};
fprintf('\n=== STEVE''S FULL QC ON CHAPTER 1 (TBR23): what does it actually remove? ===\n');
fprintf('%-12s %10s %10s %10s %12s\n','frame','nSeg','nanFrac ok','+z-test','+Q-test(>.75)');
for k=1:4
  S=load([d labs{k} '_L2.mat'],'L2'); L2=S.L2; clear S
  sv=logical(L2.segValid(:)); zt=L2.ztest_SS(:); q=L2.qtest_PU(:);
  if numel(q)~=numel(sv), q=nan(size(sv)); end
  k1=sv; k2=k1 & zt>0.6 & zt<1.5; k3=k2 & q>0.75;
  fprintf('%-12s %10d %9.1f%% %9.1f%% %11.1f%%\n',labs{k},numel(sv),100*mean(k1),100*mean(k2),100*mean(k3));
  L2q.(labs{k})=struct('sv',sv,'zt',zt,'q',q,'t',L2.time(:)); clear L2
end
fprintf('\nRetention of the FULL QC chain (nanFrac & z-test & Q-test) vs model Hs:\n');
fprintf('%-12s','frame'); fprintf('%10s',hn{:}); fprintf('%14s\n','rho(Hs,keep)');
for k=1:4
  A=L2q.(labs{k}); t=A.t; if ~isdatetime(t), t=datetime(t,'ConvertFrom','datenum'); end
  t.TimeZone=''; hm=interp1(tM,MP.Hs,t,'linear',NaN);
  keep=A.sv & A.zt>0.6 & A.zt<1.5 & A.q>0.75;
  fprintf('%-12s',labs{k});
  for b=1:numel(hn)
    s=hm>=he(b)&hm<he(b+1)&isfinite(hm);
    if sum(s)>=20, fprintf('%9.0f%%',100*mean(keep(s))); else, fprintf('%10s',sprintf('(%d)',sum(s))); end
  end
  ok=isfinite(hm);
  fprintf('%14.3f\n', corr(hm(ok),double(keep(ok)),'type','Spearman'));
end
fprintf('\nQTEST_DONE\n');
