L1='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L1/TOR23W/';
out='/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/raw/';
for f = {'MOP586_7m','MOP586_10m'}
  S=load([L1 f{1} '_processed.mat']); P=S.PUV; clear S
  t=P.time(:); u=P.BuoyCoord.U(:); v=P.BuoyCoord.V(:); T=P.T(:); pr=P.P(:);
  clear P
  keep = t>=datetime(2023,12,18) & t<datetime(2023,12,31);
  t=t(keep); u=u(keep); v=v(keep); T=T(keep); pr=pr(keep);
  % 20-min bins
  e = dateshift(t(1),'start','hour'):minutes(20):dateshift(t(end),'start','hour');
  g = discretize(t,e);
  ok = ~isnan(g);
  n = numel(e)-1;
  R = nan(n,6);
  for k=1:n
    s = ok & g==k;
    if sum(s)<600, continue; end
    uu=u(s); vv=v(s);
    R(k,1)=sqrt(var(uu,'omitnan')+var(vv,'omitnan'));   % rotation-invariant horizontal rms
    R(k,2)=mean(uu,'omitnan'); R(k,3)=mean(vv,'omitnan');
    R(k,4)=mean(T(s),'omitnan'); R(k,5)=mean(pr(s),'omitnan');
    R(k,6)=sum(~isnan(uu))/sum(s);
  end
  Tb = table(e(1:n)', R(:,1),R(:,2),R(:,3),R(:,4),R(:,5),R(:,6), ...
     'VariableNames',{'time','urms_h','umean','vmean','T','P','frac_ok'});
  writetable(Tb,[out 'L1_' f{1} '.csv']);
  fprintf('%s: %d bins, %d with data\n', f{1}, n, sum(isfinite(R(:,1))));
end
fprintf('REF7_DONE\n');
