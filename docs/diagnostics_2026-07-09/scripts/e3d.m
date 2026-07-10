addpath('/Users/holden/Documents/Scripps/Research/toolbox');
load([ '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/e3b.mat'],'R');
get=@(l,d) R(strcmp({R.lab},l)&strcmp({R.dep},d));
for a=1:4, try, M80=read_MOPline2('D0580',datetime(2023,10,1),datetime(2025,7,1)); break; catch, pause(5); end, end
t80=M80.time; if ~isdatetime(t80), t80=datetime(t80,'ConvertFrom','datenum'); end

fprintf('=========== A(full). Retention vs model Hs WITHIN deployment ===========\n');
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

fprintf('\n=========== E. WHEN are the long outages, and what were the waves doing? ===========\n');
fprintf('%-8s %-12s %6s  %-19s %-19s %7s %7s\n','deploy','frame','len','start','end','maxHs','medHs');
for k=1:numel(R)
  bad=~R(k).sv; if ~any(bad), continue; end
  d=diff([false;bad(:);false]); st=find(d==1); en=find(d==-1)-1; L=en-st+1;
  [~,ord]=sort(L,'descend');
  for q=ord(1:min(2,numel(ord)))'
    if L(q)<40, continue; end
    t1=R(k).t(st(q)); t2=R(k).t(en(q)); hw=R(k).hsm(st(q):en(q));
    fprintf('%-8s %-12s %6d  %-19s %-19s %7.2f %7.2f\n',R(k).dep,R(k).lab,L(q), ...
      datestr(t1,'yyyy-mm-dd HH:MM'),datestr(t2,'yyyy-mm-dd HH:MM'),max(hw),median(hw,'omitnan'));
  end
end
fprintf('\nFor reference, the record-peak storm at D0586 was 2023-12-28..29 (Hs_586 peak 3.18 m).\n');

fprintf('\n=========== F. Was the 5m/7m loss wave-driven ONCE the long outages are excluded? ===========\n');
fprintf('Drop every contiguous invalid run of length >= 40 segments (>13 h) as an outage,\n');
fprintf('then recompute retention vs Hs on what remains.\n\n');
fprintf('%-8s %-12s','deploy','frame'); fprintf('%9s',hn{:}); fprintf('%12s\n','n kept');
for k=1:numel(R)
  bad=~R(k).sv; keepmask=true(size(bad));
  if any(bad)
    d=diff([false;bad(:);false]); st=find(d==1); en=find(d==-1)-1; L=en-st+1;
    for q=1:numel(L), if L(q)>=40, keepmask(st(q):en(q))=false; end, end
  end
  hm=R(k).hsm; sv=R(k).sv;
  fprintf('%-8s %-12s',R(k).dep,R(k).lab);
  for b=1:numel(hn)
    s=keepmask&hm>=he(b)&hm<he(b+1)&isfinite(hm);
    if sum(s)>=20, fprintf('%8.0f%%',100*mean(sv(s))); else, fprintf('%9s',sprintf('(%d)',sum(s))); end
  end
  fprintf('%12d\n',sum(keepmask));
end

fprintf('\n=========== G. Model 10-m Hs ratio D0586/D0580 over the SAME matched PUV times ===========\n');
pairs={'MOP580_5m','MOP586_5m','TOR23W';'MOP580_7m','MOP586_7m','TOR23W';'MOP580_7m','MOP586_7m','TOR24S'};
for p=1:size(pairs,1)
  A=get(pairs{p,1},pairs{p,3}); B=get(pairs{p,2},pairs{p,3});
  ja=find(A.sv&isfinite(A.hs)); jb=find(B.sv&isfinite(B.hs));
  [dd,ii]=min(abs(seconds(A.t(ja)-B.t(jb)')),[],2); keep=dd<600; ja=ja(keep); jb=jb(ii(keep));
  ha=A.hs(ja); hb=B.hs(jb);
  h80=interp1(t80,M80.Hs,A.t(ja),'linear',NaN); h86=A.hsm(ja);
  ok=isfinite(h80)&isfinite(h86);
  fprintf('%s %s/%s  n=%d\n',pairs{p,3},pairs{p,2},pairs{p,1},sum(ok));
  fprintf('   model 10-m Hs ratio 586/580 = %.3f   |   in-situ PUV Hs ratio = %.3f\n', ...
     median(h86(ok)./h80(ok)), median(hb(ok)./ha(ok)));
  fprintf('   -> model predicts a %.0f%% deficit at the 10-m contour; the beds at %s see %.0f%%\n', ...
     100*(1-median(h86(ok)./h80(ok))), pairs{p,2}(end-1:end), 100*(1-median(hb(ok)./ha(ok))));
end
fprintf('\nE3D_DONE\n');
