% CHECK_TOR18A_CLOCK  Measure the clock offset for TOR18A.
%
%   TOR18A was left out of TorreyOffshore_config's clockOffsetMap, so the config
%   threw and the record dropped silently out of every registry-driven loop
%   (they all use `catch, continue`). Its L1-L4 on disk therefore predate the
%   clock fix and carry NO offset.
%
%   Its neighbours disagree -- TOR17D (2017-18) is +8, TOR19A (2019-20) is 0 --
%   so the offset has to be measured, not interpolated. Same test as
%   audit_clock_lag: cross-correlate L2 depth against the NOAA-referenced
%   L3 tidal prediction.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';

for dep = {'TOR18A','TOR19A','TOR17D'}
    d0 = dep{1};
    f2 = fullfile(root,'L2',d0,'MOP591_9m_L2.mat');
    f3 = fullfile(root,'L3',d0,'MOP591_9m_L3.mat');
    if ~isfile(f2) || ~isfile(f3)
        fprintf('%-8s missing L2/L3\n', d0); continue
    end
    L2 = getfield(load(f2,'L2'),'L2'); %#ok<GFLD>
    L3 = getfield(load(f3,'L3'),'L3'); %#ok<GFLD>
    d = L2.depth(:); pr = L3.tidal.depth_pred(:); sv = logical(L2.segValid(:));
    m = sv & isfinite(d) & isfinite(pr);
    if sum(m) < 200, fprintf('%-8s only %d segments\n', d0, sum(m)); continue, end
    a = d; b = pr; a(~m)=NaN; b(~m)=NaN;
    a = a-mean(a,'omitnan'); b = b-mean(b,'omitnan');
    a(isnan(a))=0; b(isnan(b))=0;
    R = nan(1,29); L = -14:14;
    for i = 1:numel(L)
        x = circshift(b,L(i)); R(i) = dot(a,x)/(norm(a)*norm(x)+eps);
    end
    [bestR, bi] = max(R);
    fprintf('RES %-8s n=%-5d bestLag %+3d h  R=%.3f   R@0=%.3f   span %s to %s\n', ...
        d0, sum(m), L(bi), bestR, R(L==0), ...
        string(L2.time(find(m,1)),'dd-MMM-yyyy'), ...
        string(L2.time(find(m,1,'last')),'dd-MMM-yyyy'));
end

fprintf(['\nA lag of 0 means the record is already UTC (offset 0, like TOR19A).\n' ...
         'A lag of -8 means the labels are slow and +8 must be ADDED.\n']);
