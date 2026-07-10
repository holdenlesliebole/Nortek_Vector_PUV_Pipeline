load([ '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/e3b.mat'],'R');
he=[0 1 1.5 2 2.5 8]; hn={'<1','1-1.5','1.5-2','2-2.5','>2.5'};
fprintf('Median ztest_SS = Spp_measured / Spp_from_vel, by model Hs bin.\n');
fprintf('z==1 means velocity reconstructs the pressure spectrum exactly.\n\n');
fprintf('%-14s','frame'); fprintf('%14s',hn{:}); fprintf('\n');
labs={'MOP586_5m','MOP586_7m','MOP586_10m','MOP586_15m','MOP580_7m'};
for L=labs
  sel=find(strcmp({R.lab},L{1}));
  if isempty(sel), continue; end
  sv=vertcat(R(sel).sv); zt=vertcat(R(sel).zt); hm=vertcat(R(sel).hsm);
  fprintf('%-14s',L{1});
  for b=1:numel(hn)
    s=sv&isfinite(zt)&hm>=he(b)&hm<he(b+1);
    if sum(s)>=25
      q=prctile(zt(s),[25 50 75]);
      fprintf('%9.3f(%d)',q(2),sum(s));
    else, fprintf('%14s',sprintf('n=%d',sum(s))); end
  end
  fprintf('\n');
end
fprintf('\nIQR of z in the >2.5 m bin (7 m frame, the only one with real storm coverage):\n');
sel=find(strcmp({R.lab},'MOP586_7m')); sv=vertcat(R(sel).sv); zt=vertcat(R(sel).zt); hm=vertcat(R(sel).hsm);
s=sv&isfinite(zt)&hm>2.5;
q=prctile(zt(s),[5 25 50 75 95]);
fprintf('  n=%d  p05=%.3f p25=%.3f p50=%.3f p75=%.3f p95=%.3f\n', sum(s), q);
fprintf('  -> reconstructed Hs error at storm Hs: %+.1f%% (p50), [%+.1f%%, %+.1f%%] (p05-p95)\n', ...
   100*(1/sqrt(q(3))-1), 100*(1/sqrt(q(5))-1), 100*(1/sqrt(q(1))-1));
