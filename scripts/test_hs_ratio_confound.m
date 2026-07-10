function test_hs_ratio_confound()
%TEST_HS_RATIO_CONFOUND  Is the Phase-A "FAIL" a reconstruction error, or a confound?
%
% validate_recovery_MOP586_10m compares the recovered Hs against the 7 m frame, using
% 22-24 Dec as the control. The control median Hs10/Hs7 is 0.9616; Phase A gives 0.9354.
% The verdict flags that as a failure.
%
% But the control is CALM (Hs ~ 0.7-1.0 m) and Phase A contains the storm (Hs up to 3.4 m).
% The ratio Hs(9.4 m) / Hs(7 m) is NOT a constant: it depends on the spectrum, because
% shoaling between the two depths is frequency-dependent and storms are swell-dominated.
% Comparing a calm control to a stormy test period does not hold that constant.
%
% This is the same class of error the Chapter-2 audit keeps finding, so it gets the same
% treatment: estimate the confound from data where BOTH frames are healthy, and ask whether
% it quantitatively accounts for the shift.
%
%   H0 (confound):    Hs10/Hs7 declines with Hs for physical reasons. Evaluated at the
%                     Phase-A median Hs, the healthy relationship predicts ~0.935.
%   H1 (bad recovery): the reconstruction is biased ~2.6% low. Then the healthy
%                     relationship, extrapolated to Phase-A Hs, would predict ~0.962.
%
% These make DIFFERENT predictions and the data can choose. Pooling every deployment in
% which the 7 m and 10 m frames were simultaneously healthy gives storm coverage the
% 22-24 Dec control does not have.
%
% 2026-07-09.

startup_puv;
L2d = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/';
deps = {'TOR23W','TOR24S','TOR24W','TOR25S'};

T = []; H10 = []; H7 = [];
for d = 1:numel(deps)
    f10 = [L2d deps{d} '/MOP586_10m_L2.mat'];
    f7  = [L2d deps{d} '/MOP586_7m_L2.mat'];
    if ~isfile(f10) || ~isfile(f7), fprintf('skip %s\n', deps{d}); continue; end
    a = load(f10,'L2'); b = load(f7,'L2');
    ta = a.L2.time(:); tb = b.L2.time(:);
    if ~isdatetime(ta), ta = datetime(ta,'ConvertFrom','datenum'); end
    if ~isdatetime(tb), tb = datetime(tb,'ConvertFrom','datenum'); end
    ta.TimeZone=''; tb.TimeZone='';
    va = logical(a.L2.segValid(:)); vb = logical(b.L2.segValid(:));
    ha = a.L2.Hs(:); hb = b.L2.Hs(:);
    clear a b
    ja = find(va & isfinite(ha)); jb = find(vb & isfinite(hb));
    if isempty(ja) || isempty(jb), continue; end
    [dd,ii] = min(abs(seconds(ta(ja)-tb(jb)')),[],2);
    keep = dd < 600; ja = ja(keep); jb = jb(ii(keep));
    T = [T; ta(ja)]; H10 = [H10; ha(ja)]; H7 = [H7; hb(jb)]; %#ok<AGROW>
    fprintf('%-8s %5d co-located healthy bursts, Hs7 %.2f-%.2f m\n', deps{d}, numel(ja), min(hb(jb)), max(hb(jb)));
end

r = H10./H7;
fprintf('\nAll healthy co-located bursts: n=%d, Hs7 range %.2f-%.2f m\n', numel(r), min(H7), max(H7));

fprintf('\n=== Hs10 / Hs7 as a function of Hs7, on HEALTHY data from both frames ===\n');
e = [0 0.75 1.0 1.25 1.5 2.0 2.5 6];
fprintf('%-12s %7s %10s %18s\n','Hs7 bin','n','med ratio','IQR');
for b = 1:numel(e)-1
    s = H7>=e(b) & H7<e(b+1);
    if sum(s) >= 25
        fprintf('%4.2f-%-7.2f %7d %10.4f   [%.4f %.4f]\n', e(b), e(b+1), sum(s), ...
            median(r(s)), prctile(r(s),25), prctile(r(s),75));
    else
        fprintf('%4.2f-%-7.2f %7d %10s\n', e(b), e(b+1), sum(s), '(too few)');
    end
end

% control-equivalent and Phase-A-equivalent bands
cs = H7 >= 0.75 & H7 < 1.25;              % 22-24 Dec control sits here
ps = H7 >= 2.0;                            % the storm hours
fprintf('\nHealthy ratio in the CONTROL band (Hs7 0.75-1.25):  %.4f  (n=%d)\n', median(r(cs)), sum(cs));
if sum(ps) >= 20
    fprintf('Healthy ratio in the STORM   band (Hs7 > 2.0)   :  %.4f  (n=%d)\n', median(r(ps)), sum(ps));
    pred = median(r(ps));
else
    fprintf('Healthy ratio in the STORM band: only n=%d -- CANNOT TEST. Report as unresolved.\n', sum(ps));
    pred = NaN;
end

fprintf('\n=== What the two hypotheses predict for the Phase-A ratio ===\n');
fprintf('  observed Phase-A  Hs_rec / Hs_7m         = 0.9354\n');
fprintf('  observed control  Hs_meas / Hs_7m        = 0.9616\n');
if isfinite(pred)
    fprintf('  H0 (confound)  predicts the storm-band healthy ratio = %.4f\n', pred);
    fprintf('  H1 (2.6%% low)  predicts %.4f (control ratio, unchanged)\n', 0.9616);
    dH0 = abs(0.9354 - pred); dH1 = abs(0.9354 - 0.9616);
    fprintf('  |observed - H0| = %.4f    |observed - H1| = %.4f\n', dH0, dH1);
    if dH0 < dH1
        fprintf('  -> H0 favoured: the "FAIL" is a wave-height confound in the control, not a\n');
        fprintf('     reconstruction error. The verdict logic in validate_recovery must control for Hs.\n');
    else
        fprintf('  -> H1 favoured: the reconstruction really does read low. Quarantine Phase A.\n');
    end
end

fprintf('\n=== Independent, confound-free check (same bursts, inside the failed window) ===\n');
fprintf('  10 Phase-A hours where the pressure sensor still worked:\n');
fprintf('     Hs_rec / Hs_meas = 1.0085  [1.0018, 1.0200]\n');
fprintf('  This compares reconstruction against measurement at the SAME depth, SAME burst,\n');
fprintf('  so no shoaling ratio enters. It is the cleanest evidence available -- but those\n');
fprintf('  hours are calm, so it does NOT test the storm regime.\n');
end
