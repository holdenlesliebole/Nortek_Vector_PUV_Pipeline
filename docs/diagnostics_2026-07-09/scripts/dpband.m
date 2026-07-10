addpath('/Users/holden/Documents/Scripps/Research/toolbox');
% Use the DOCUMENTED Dp field (not a home-rolled datum) and hold the frequency
% band fixed, so the shadowed heading can be stated in real degrees.
d1=datetime(2023,11,1); d2=datetime(2025,6,30);
for m=[583 586], for a=1:4, try, S.(sprintf('m%d',m))=read_MOPline2(sprintf('D%04d',m),d1,d2); break; catch, pause(5); end, end, end
A=S.m583; B=S.m586; n=min(numel(A.Hs),numel(B.Hs));
f=A.frequency(:).'; fbw=A.fbw(:).'; Hs=A.Hs(1:n); Dp=A.Dp(1:n);
sel=f>=0.055&f<0.070;
a0=sum(A.spec1D(1:n,sel).*fbw(sel),2); b0=sum(B.spec1D(1:n,sel).*fbw(sel),2); r=b0./a0;
fprintf('shorenormal at 583 = %.1f deg, at 586 = %.1f deg\n', A.shorenormal, B.shorenormal);
de=[235 250 258 264 270 276 290];
he=[1 1.5 2 2.5 8]; hn={'1.0-1.5','1.5-2.0','2.0-2.5','>2.5'};
fprintf('\nBand 0.055-0.070 Hz.  Median m0_586/m0_583 in (Dp x Hs) cells.\n');
fprintf('%-12s','Dp (deg)'); fprintf('%11s',hn{:}); fprintf('%9s\n','all Hs>1');
for k=1:numel(de)-1
  fprintf('%-12s',sprintf('%d-%d',de(k),de(k+1)));
  for h=1:numel(hn)
    s=Dp>=de(k)&Dp<de(k+1)&Hs>=he(h)&Hs<he(h+1)&isfinite(r);
    if sum(s)>=25, fprintf('%11.3f',median(r(s))); else, fprintf('%11s',sprintf('n=%d',sum(s))); end
  end
  s=Dp>=de(k)&Dp<de(k+1)&Hs>1&isfinite(r);
  if sum(s)>=25, fprintf('%9.3f  (n=%d)\n',median(r(s)),sum(s)); else, fprintf('%9s\n','-'); end
end
fprintf('\nRows flat across Hs => amplitude-independent transfer (linear refraction).\n');
fprintf('DPBAND_DONE\n');
