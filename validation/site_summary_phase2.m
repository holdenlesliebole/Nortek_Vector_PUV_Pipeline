function site_summary_phase2(opts)
% SITE_SUMMARY_PHASE2  Print per-site Phase 2 summary stats from a saved
% phase2_summary.mat. Default loads outputs/validation/mean_flow/_aggregate/
% phase2_summary.mat; pass opts.summaryFile to override.
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts,'summaryFile')
    opts.summaryFile = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate','phase2_summary.mat');
end

S = load(opts.summaryFile); s = S.summary;
nums = {'h_med','alpha','alpha_lo','alpha_hi','beta','beta_lo','beta_hi','R2_Hs2','alpha_th','modAmp_high','N_segs'};
for k = 1:numel(nums), s.(nums{k}) = s.(nums{k})(:); end
s.deployment = s.deployment(:); s.label = s.label(:);

isBad = strcmp(s.deployment,'TBR23') & strcmp(s.label,'MOP580_5m');
site = strings(numel(s.label),1);
for k = 1:numel(s.label)
    d = s.deployment{k};
    if startsWith(d,'TBR') || startsWith(d,'TOR') || startsWith(d,'RUBY'), site(k) = "Torrey";
    elseif startsWith(d,'SOL'),                    site(k) = "Solana";
    elseif startsWith(d,'SIO'),                    site(k) = "SIO Pier";
    elseif startsWith(d,'LPL'),                    site(k) = "LPL lagoon";
    elseif startsWith(d,'CAT'),                    site(k) = "Catalina";
    elseif startsWith(d,'IB'),                     site(k) = "Imperial Beach";
    end
end
sites = unique(site);

fprintf('\nSite-by-site Phase 2 summary (file: %s)\n', opts.summaryFile);
fprintf('%-12s  %3s  %12s  %10s  %8s  %12s  %11s  %12s\n', ...
    'site','N','median a','/a_th','a<0%','median |b|','|b|<2cm/s','median modHi');
for st = sites'
    p = (site == st) & ~isBad & ~isnan(s.alpha);
    a = s.alpha(p); ath = s.alpha_th(p); b = s.beta(p); m = s.modAmp_high(p);
    fprintf('%-12s  %3d  %+12.4f  %+10.2f  %7.0f%%  %+12.4f  %10.0f%%  %12.4f\n', ...
        st, sum(p), median(a), median(a./ath), 100*mean(a<0), ...
        median(b,'omitnan'), 100*mean(abs(b)<0.02,'omitnan'), median(m,'omitnan'));
end
% All combined
p = ~isBad & ~isnan(s.alpha);
a = s.alpha(p); ath = s.alpha_th(p); b = s.beta(p); m = s.modAmp_high(p);
fprintf('%-12s  %3d  %+12.4f  %+10.2f  %7.0f%%  %+12.4f  %10.0f%%  %12.4f\n', ...
    'ALL', sum(p), median(a), median(a./ath), 100*mean(a<0), ...
    median(b,'omitnan'), 100*mean(abs(b)<0.02,'omitnan'), median(m,'omitnan'));
end
