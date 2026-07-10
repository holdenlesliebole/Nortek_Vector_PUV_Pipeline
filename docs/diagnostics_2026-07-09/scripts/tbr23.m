addpath('/Users/holden/Documents/Scripps/Research/toolbox');
d='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TBR23/';
m=matfile([d 'MOP586_5m_L2.mat']); fn=fieldnames(m.L2);
fprintf('TBR23 L2 has %d fields.\n', numel(fn));
extra = setdiff(fn, {'S_eta','Spp','Suu','Svv','Kp','a1','b1','a2','b2','time','segValid','Hs','Hs_SS','Hs_IG','Tp','Tm02','meanDir','Ef','depth','fCut','uBed_rms','vBed_rms','Ub','tau_b','fric_w','Aw','uMean','vMean','wMean','Tmean','reynolds','vmom','ztest_SS','ztest_IG','Sxx','Syy','Sxy','label','deploymentName','LATLON','doffp','shorenormal','fs','f','params','mopStation'});
fprintf('fields present in TBR23 but NOT in the Jun-5 TOR files: %s\n', strjoin(extra,', '));

for a=1:4, try, MP=read_MOPline2('D0586',datetime(2022,10,1),datetime(2023,10,1)); break; catch, pause(5); end, end
tM=MP.time; if ~isdatetime(tM), tM=datetime(tM,'ConvertFrom','datenum'); end
he=[0 0.5 0.75 1 1.25 8]; hn={'<0.5','0.5-.75','.75-1','1-1.25','>1.25'};
fprintf('\n=== Chapter 1 (TBR23) retention + z-test, by model Hs at D0586 ===\n');
fprintf('%-14s %6s %7s','frame','nSeg','valid'); fprintf('%10s',hn{:}); fprintf('\n');
labs={'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'};
for k=1:4
  S=load([d labs{k} '_L2.mat'],'L2'); L2=S.L2; clear S
  t=L2.time(:); if ~isdatetime(t), t=datetime(t,'ConvertFrom','datenum'); end
  t.TimeZone='';
  sv=logical(L2.segValid(:)); hm=interp1(tM,MP.Hs,t,'linear',NaN); zt=L2.ztest_SS(:);
  fprintf('%-14s %6d %6.1f%%',labs{k},numel(t),100*mean(sv));
  for b=1:numel(hn)
    s=hm>=he(b)&hm<he(b+1)&isfinite(hm);
    if sum(s)>=20, fprintf('%9.0f%%',100*mean(sv(s))); else, fprintf('%10s',sprintf('(%d)',sum(s))); end
  end
  ok=isfinite(hm);
  fprintf('  rho(Hs,valid)=%+.3f\n', corr(hm(ok),double(sv(ok)),'type','Spearman'));
  z=zt(sv); z=z(isfinite(z));
  % contiguity of loss
  bad=~sv; nR=0; mx=0;
  if any(bad), dd=diff([false;bad;false]); st=find(dd==1); en=find(dd==-1)-1; nR=numel(st); mx=max(en-st+1); end
  fprintf('   z-test: %.1f%% of valid segs in [0.6,1.5]  (p01=%.3f p50=%.3f p99=%.3f) | invalid runs: %d, longest %d\n', ...
     100*mean(z>0.6&z<1.5), prctile(z,1), median(z), prctile(z,99), nR, mx);
  clear L2
end
fprintf('\nTBR23_DONE\n');
