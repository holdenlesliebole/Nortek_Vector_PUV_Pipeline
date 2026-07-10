addpath('/Users/holden/Documents/Scripps/Research/toolbox');
L2d='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';

% Model Hs at MOP586, independent of the PUV, so it exists for DROPPED segments too.
for a=1:4
  try, MP=read_MOPline2('D0586',datetime(2023,10,1),datetime(2025,7,1)); break
  catch ME, fprintf('mop try %d: %s\n',a,ME.message); pause(5); end
end
tM=MP.time; if ~isdatetime(tM), tM=datetime(tM,'ConvertFrom','datenum'); end
hsM=MP.Hs;

grab = @(dep,lab) fullfile(L2d,dep,[lab '_L2.mat']);
files = { 'TOR23W','MOP586_5m'; 'TOR24S','MOP586_5m';
          'TOR23W','MOP586_7m'; 'TOR24S','MOP586_7m'; 'TOR24W','MOP586_7m';
          'TOR23W','MOP586_10m';'TOR24S','MOP586_10m';'TOR24W','MOP586_10m';'TOR25S','MOP586_10m';
          'TOR23W','MOP586_15m';'TOR24W','MOP586_15m';'TOR25S','MOP586_15m';
          'TOR23W','MOP580_5m'; 'TOR23W','MOP580_7m'; 'TOR24S','MOP580_7m'};
R = struct('lab',{},'dep',{},'t',{},'sv',{},'hs',{},'hsm',{},'zt',{},'um',{},'sk',{},'uu2',{},'ub',{});
for k=1:size(files,1)
  f = grab(files{k,1},files{k,2});
  if ~isfile(f), fprintf('MISSING %s\n',f); continue; end
  S=load(f,'L2'); L2=S.L2; clear S
  t=L2.time(:); if ~isdatetime(t), t=datetime(t,'ConvertFrom','datenum'); end
  t.TimeZone=''; %#ok<*STRNU>
  zt = L2.ztest_SS(:); if numel(zt)~=numel(t), zt=nan(size(t)); end
  R(end+1)=struct('lab',files{k,2},'dep',files{k,1},'t',t,'sv',logical(L2.segValid(:)), ...
     'hs',L2.Hs(:),'hsm',interp1(tM,hsM,t,'linear',NaN),'zt',zt, ...
     'um',L2.uMean(:),'sk',L2.vmom.skewness(:),'uu2',L2.vmom.u_uabs2(:),'ub',L2.Ub(:)); %#ok<AGROW>
  fprintf('%-8s %-14s nSeg=%5d  valid=%5d (%.1f%%)\n',files{k,1},files{k,2},numel(t),sum(L2.segValid),100*mean(L2.segValid));
  clear L2
end
save([ '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/e3b.mat'],'R','-v7.3');

%% ---------- 1. RETENTION CURVE: P(segment survives) vs model Hs ----------
fprintf('\n================ E3.1  SEGMENT RETENTION vs FORCING ================\n');
fprintf('Model Hs (D0586) at every segment time, valid AND dropped.\n');
he=[0 1 1.5 2 2.5 3 8]; hn={'<1','1-1.5','1.5-2','2-2.5','2.5-3','>3'};
depths={'5m','7m','10m','15m'};
fprintf('\n%-6s %-8s','frame',''); fprintf('%9s',hn{:}); fprintf('\n');
for d=1:4
  sel = find(contains({R.lab},['MOP586_' depths{d}]));
  if isempty(sel), continue; end
  t=vertcat(R(sel).t); sv=vertcat(R(sel).sv); hm=vertcat(R(sel).hsm);
  fprintf('%-6s %-8s','586',depths{d});
  for b=1:numel(hn)
    s=hm>=he(b)&hm<he(b+1)&isfinite(hm);
    if sum(s)>=20, fprintf('%8.0f%%',100*mean(sv(s))); else, fprintf('%9s',sprintf('(%d)',sum(s))); end
  end
  fprintf('   n=%d\n',numel(t));
end
fprintf('\nSpearman(model Hs, segValid) per frame:\n');
for d=1:4
  sel=find(contains({R.lab},['MOP586_' depths{d}])); if isempty(sel),continue,end
  sv=vertcat(R(sel).sv); hm=vertcat(R(sel).hsm); ok=isfinite(hm);
  fprintf('  %-4s rho = %+.3f   (n=%d)\n',depths{d},corr(hm(ok),double(sv(ok)),'type','Spearman'),sum(ok));
end

%% ---------- 2. Z-TEST retention among surviving segments ----------
fprintf('\n================ E3.4  STEVE''S Z-TEST (0.6<z<1.5) vs FORCING ================\n');
fprintf('%-6s %-8s','frame',''); fprintf('%9s',hn{:}); fprintf('\n');
for d=1:4
  sel=find(contains({R.lab},['MOP586_' depths{d}])); if isempty(sel),continue,end
  sv=vertcat(R(sel).sv); hm=vertcat(R(sel).hsm); zt=vertcat(R(sel).zt);
  pass = zt>0.6 & zt<1.5;
  fprintf('%-6s %-8s','586',depths{d});
  for b=1:numel(hn)
    s=sv&isfinite(zt)&hm>=he(b)&hm<he(b+1);
    if sum(s)>=20, fprintf('%8.0f%%',100*mean(pass(s))); else, fprintf('%9s',sprintf('(%d)',sum(s))); end
  end
  fprintf('\n');
end
fprintf('\nJOINT survival (nanFrac gate AND z-test), as a fraction of ALL segments:\n');
fprintf('%-6s %-8s','frame',''); fprintf('%9s',hn{:}); fprintf('\n');
for d=1:4
  sel=find(contains({R.lab},['MOP586_' depths{d}])); if isempty(sel),continue,end
  sv=vertcat(R(sel).sv); hm=vertcat(R(sel).hsm); zt=vertcat(R(sel).zt);
  keep = sv & zt>0.6 & zt<1.5;
  fprintf('%-6s %-8s','586',depths{d});
  for b=1:numel(hn)
    s=isfinite(hm)&hm>=he(b)&hm<he(b+1);
    if sum(s)>=20, fprintf('%8.0f%%',100*mean(keep(s))); else, fprintf('%9s',sprintf('(%d)',sum(s))); end
  end
  fprintf('\n');
end

%% ---------- 3. ALONGSHORE: is the 10-m swell contrast felt at 5 m and 7 m? ----------
fprintf('\n================ ALONGSHORE PUV: MOP580 vs MOP586 ================\n');
fprintf('Model 10-m Hs contrast over 2023-12-27..31 peak: 580=4.765 m, 586=3.183 m (ratio 0.67)\n');
fprintf('If the beach is alongshore uniform, the in-situ 5/7 m PUVs should NOT show 0.67.\n\n');
pairs = {'MOP580_5m','MOP586_5m','TOR23W'; 'MOP580_7m','MOP586_7m','TOR23W'; 'MOP580_7m','MOP586_7m','TOR24S'};
for p=1:size(pairs,1)
  ia=find(strcmp({R.lab},pairs{p,1}) & strcmp({R.dep},pairs{p,3}));
  ib=find(strcmp({R.lab},pairs{p,2}) & strcmp({R.dep},pairs{p,3}));
  if isempty(ia)||isempty(ib), fprintf('%s: pair unavailable\n',pairs{p,3}); continue; end
  A=R(ia); B=R(ib);
  [tc,ja,jb]=intersect(A.t,B.t);
  ok = A.sv(ja)&B.sv(jb)&isfinite(A.hs(ja))&isfinite(B.hs(jb));
  ha=A.hs(ja(ok)); hb=B.hs(jb(ok)); hm=A.hsm(ja(ok));
  fprintf('--- %s  %s vs %s : %d common valid bursts, Hs range %.2f-%.2f m\n', ...
     pairs{p,3},pairs{p,1},pairs{p,2},sum(ok),min(ha),max(ha));
  fprintf('    median Hs 580 = %.3f m, 586 = %.3f m, median ratio 586/580 = %.3f  corr=%.3f\n', ...
     median(ha),median(hb),median(hb./ha),corr(ha,hb));
  hh=[0 1 1.5 2 2.5 8];
  fprintf('    ratio by model Hs bin: ');
  for b=1:numel(hh)-1
    s=hm>=hh(b)&hm<hh(b+1);
    if sum(s)>=15, fprintf('[%.1f-%.1f]%.3f(n=%d) ',hh(b),hh(b+1),median(hb(s)./ha(s)),sum(s)); end
  end
  fprintf('\n');
  ua=A.um(ja(ok)); ub_=B.um(jb(ok));
  fprintf('    median uMean 580 = %+.4f m/s, 586 = %+.4f m/s\n', median(ua,'omitnan'), median(ub_,'omitnan'));
  sa=A.sk(ja(ok)); sb=B.sk(jb(ok));
  fprintf('    median skewness 580 = %+.3f, 586 = %+.3f\n', median(sa,'omitnan'), median(sb,'omitnan'));
end
fprintf('\nE3B_DONE\n');
