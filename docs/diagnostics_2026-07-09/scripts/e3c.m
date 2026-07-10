load([ '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/e3b.mat'],'R');
get=@(l,d) R(strcmp({R.lab},l)&strcmp({R.dep},d));

fprintf('=========== A. Is the segment loss WAVE-driven or INSTRUMENT-driven? ===========\n');
fprintf('Retention vs model Hs, computed WITHIN each deployment (removes the\n');
fprintf('deployment x winter confound). TOR23W is the big-wave winter.\n\n');
he=[0 1 1.5 2 2.5 8]; hn={'<1','1-1.5','1.5-2','2-2.5','>2.5'};
fprintf('%-8s %-12s','deploy','frame'); fprintf('%9s',hn{:}); fprintf('%10s\n','overall');
for k=1:numel(R)
  hm=R(k).hsm; sv=R(k).sv;
  fprintf('%-8s %-12s',R(k).dep,R(k).lab);
  for b=1:numel(hn)
    s=hm>=he(b)&hm<he(b+1)&isfinite(hm);
    if sum(s)>=20, fprintf('%8.0f%%',100*mean(sv(s))); else, fprintf('%9s',sprintf('(%d)',sum(s))); end
  end
  fprintf('%9.0f%%\n',100*mean(sv));
end

fprintf('\n=========== B. Are the dropped segments CLUSTERED IN TIME? ===========\n');
fprintf('An instrument failure gives few long runs; wave-driven loss gives many short ones.\n');
fprintf('%-8s %-12s %8s %8s %8s %10s\n','deploy','frame','nInval','nRuns','maxRun','medRun');
for k=1:numel(R)
  bad=~R(k).sv; if ~any(bad), fprintf('%-8s %-12s %8d %8s\n',R(k).dep,R(k).lab,0,'-'); continue; end
  d=diff([false;bad(:);false]); st=find(d==1); en=find(d==-1)-1; L=en-st+1;
  fprintf('%-8s %-12s %8d %8d %8d %10.1f\n',R(k).dep,R(k).lab,sum(bad),numel(L),max(L),median(L));
end

fprintf('\n=========== C. Distribution of the corrected z-test (is it informative?) ===========\n');
fprintf('%-8s %-12s %8s %8s %8s %8s %8s %10s\n','deploy','frame','p01','p05','p50','p95','p99','%%in[.6,1.5]');
for k=1:numel(R)
  z=R(k).zt(R(k).sv); z=z(isfinite(z)); if numel(z)<50, continue; end
  fprintf('%-8s %-12s %8.3f %8.3f %8.3f %8.3f %8.3f %10.1f\n',R(k).dep,R(k).lab, ...
    prctile(z,1),prctile(z,5),median(z),prctile(z,95),prctile(z,99),100*mean(z>0.6&z<1.5));
end

fprintf('\n=========== D. ALONGSHORE: does the 10-m swell contrast reach 5 m and 7 m? ===========\n');
fprintf('Model 10-m Hs, 2023-12-27..31 peak: D0580=4.765 m, D0586=3.183 m -> ratio 0.67\n');
fprintf('Matching PUV bursts within 10 min (segment midpoints do not align exactly).\n\n');
pairs={'MOP580_5m','MOP586_5m','TOR23W';'MOP580_7m','MOP586_7m','TOR23W';'MOP580_7m','MOP586_7m','TOR24S'};
for p=1:size(pairs,1)
  A=get(pairs{p,1},pairs{p,3}); B=get(pairs{p,2},pairs{p,3});
  if isempty(A)||isempty(B), fprintf('%s pair unavailable\n',pairs{p,3}); continue; end
  ja=find(A.sv&isfinite(A.hs)); jb=find(B.sv&isfinite(B.hs));
  if isempty(ja)||isempty(jb), fprintf('no valid\n'); continue; end
  [d,ii]=min(abs(seconds(A.t(ja)-B.t(jb)')),[],2);   % nearest B for each A
  keep=d<600; ja=ja(keep); jb=jb(ii(keep));
  ha=A.hs(ja); hb=B.hs(jb); hm=A.hsm(ja);
  fprintf('--- %s : %s vs %s | %d matched valid bursts\n',pairs{p,3},pairs{p,1},pairs{p,2},numel(ja));
  if numel(ja)<30, fprintf('    too few\n'); continue; end
  fprintf('    PUV Hs  median 580=%.3f  586=%.3f   median ratio 586/580 = %.3f   corr=%.4f\n', ...
     median(ha),median(hb),median(hb./ha),corr(ha,hb));
  hh=[0 1 1.5 2 2.5 8];
  fprintf('    ratio by model-Hs(D0586) bin:');
  for b=1:numel(hh)-1
    s=hm>=hh(b)&hm<hh(b+1);
    if sum(s)>=15, fprintf('  [%.1f-%.1f] %.3f (n=%d)',hh(b),hh(b+1),median(hb(s)./ha(s)),sum(s)); end
  end
  fprintf('\n');
  fprintf('    model 10-m Hs ratio D0586/D0580 over the SAME matched times: (computed below)\n');
  ua=A.um(ja); ub=B.um(jb); sa=A.sk(ja); sb=B.sk(jb);
  fprintf('    uMean   580=%+.4f  586=%+.4f m/s   |  skewness 580=%+.3f  586=%+.3f\n', ...
     median(ua,'omitnan'),median(ub,'omitnan'),median(sa,'omitnan'),median(sb,'omitnan'));
end
fprintf('\nE3C_DONE\n');
