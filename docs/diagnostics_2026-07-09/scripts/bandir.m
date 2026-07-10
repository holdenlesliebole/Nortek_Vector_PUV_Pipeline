addpath('/Users/holden/Documents/Scripps/Research/toolbox');
% Condition on BOTH frequency band and band-mean direction. If the 586/583 ratio
% is still Hs-dependent inside a fixed (f, theta) cell, no linear direction-and-
% frequency-resolved transfer function can explain it.
% Also print band energies so an additive noise floor (which would drag the ratio
% toward 1 at low energy and manufacture a spurious Hs trend) is visible.
d1=datetime(2023,11,1); d2=datetime(2025,6,30);
for m=[583 586]
  for a=1:4
    try, S.(sprintf('m%d',m))=read_MOPline2(sprintf('D%04d',m),d1,d2); break
    catch ME, pause(5); end
  end
end
A=S.m583; B=S.m586; n=min(numel(A.Hs),numel(B.Hs));
f=A.frequency(:).'; fbw=A.fbw(:).'; Hs=A.Hs(1:n);
band=[0.055 0.070];  sel=f>=band(1)&f<band(2);
a0=sum(A.spec1D(1:n,sel).*fbw(sel),2); b0=sum(B.spec1D(1:n,sel).*fbw(sel),2);
% band-mean direction at 583 from energy-weighted a1,b1
wa = A.spec1D(1:n,sel).*fbw(sel);
a1b= sum(A.a1(1:n,sel).*wa,2)./sum(wa,2);  b1b= sum(A.b1(1:n,sel).*wa,2)./sum(wa,2);
thb= mod(270 - atan2d(b1b,a1b),360);   % nautical-ish; only bin edges matter, not the datum
r=b0./a0;

fprintf('\nBand 0.055-0.070 Hz.  Band m0 at 583: median %.4f, p05 %.4f, p95 %.4f m^2\n', ...
   median(a0,'omitnan'), prctile(a0,5), prctile(a0,95));
fprintf('  (an additive floor >~ p05 would bias low-energy ratios toward 1)\n');

de = prctile(thb(isfinite(thb)&Hs>1),[10 30 50 70 90]);
fprintf('\nband-mean direction deciles (deg): %s\n', num2str(de,'%.1f '));
edges=[-inf de inf];
he=[1 1.5 2 2.5 3 8]; hn={'1.0-1.5','1.5-2.0','2.0-2.5','2.5-3.0','>3.0'};
fprintf('\nMedian ratio r=m0_586/m0_583 in (direction x Hs) cells:\n');
fprintf('%-16s','dir bin (deg)'); fprintf('%12s',hn{:}); fprintf('\n');
for k=1:numel(edges)-1
  fprintf('%-16s', sprintf('%.0f-%.0f',max(edges(k),0),min(edges(k+1),360)));
  for h=1:numel(hn)
    s = thb>=edges(k)&thb<edges(k+1)&Hs>=he(h)&Hs<he(h+1)&isfinite(r)&a0>0;
    if sum(s)>=20, fprintf('%9.3f(%s)',median(r(s)),'*'); else, fprintf('%12s',sprintf('n=%d',sum(s))); end
  end
  fprintf('\n');
end
fprintf('\nSame cells, median band m0 at 583 (m^2) -- to judge a noise floor:\n');
fprintf('%-16s','dir bin (deg)'); fprintf('%12s',hn{:}); fprintf('\n');
for k=1:numel(edges)-1
  fprintf('%-16s', sprintf('%.0f-%.0f',max(edges(k),0),min(edges(k+1),360)));
  for h=1:numel(hn)
    s = thb>=edges(k)&thb<edges(k+1)&Hs>=he(h)&Hs<he(h+1)&isfinite(r)&a0>0;
    if sum(s)>=20, fprintf('%12.4f',median(a0(s))); else, fprintf('%12s','-'); end
  end
  fprintf('\n');
end
fprintf('\nDirect check: Spearman(r, a0) within the modal direction bin, holding direction fixed:\n');
mid = thb>=de(2)&thb<de(4)&isfinite(r)&Hs>1;
fprintf('  n=%d  rho(r, band m0)=%+.3f   rho(r, Hs)=%+.3f\n', sum(mid), ...
   corr(r(mid),a0(mid),'type','Spearman'), corr(r(mid),Hs(mid),'type','Spearman'));
fprintf('\nBANDIR_DONE\n');
