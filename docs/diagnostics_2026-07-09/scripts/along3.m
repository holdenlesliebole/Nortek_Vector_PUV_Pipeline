addpath('/Users/holden/Documents/Scripps/Research/toolbox');
d1=datetime(2023,12,27); d2=datetime(2023,12,31);
fid=fopen('/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/along3.csv','w');
fprintf(fid,'mop,maxHs,medHs,m0_swell,m0_sea,depth,lat,lon,shorenormal\n');
for m = 576:590
  got=false;
  for attempt=1:4
    try
      M = read_MOPline2(sprintf('D%04d',m), d1, d2);
      f=M.frequency(:).'; fbw=M.fbw(:).';
      sw = f>=0.04 & f<=0.09; se = f>0.09;
      m0s = sum(M.spec1D(:,sw).*fbw(sw),2); m0e = sum(M.spec1D(:,se).*fbw(se),2);
      [~,i]=max(M.Hs);
      fprintf(fid,'%d,%.3f,%.3f,%.4f,%.4f,%.1f,%.5f,%.5f,%.1f\n', m, max(M.Hs), median(M.Hs,'omitnan'), ...
         m0s(i), m0e(i), M.depth, M.lat, M.lon, M.shorenormal);
      fprintf('MOP %d ok\n', m); got=true; break
    catch ME
      fprintf('MOP %d attempt %d failed: %s\n', m, attempt, ME.message); pause(3);
    end
  end
  if ~got, fprintf(fid,'%d,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', m); end
end
fclose(fid); fprintf('SCAN_DONE\n');
