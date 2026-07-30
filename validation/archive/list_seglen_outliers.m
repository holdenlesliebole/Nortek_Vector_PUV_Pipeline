function list_seglen_outliers()
% LIST_SEGLEN_OUTLIERS  Identify instruments with the largest seglen Δα.
% Diagnoses why the seglen comparison shows large RMS Δα despite 79% of
% instruments having |Δα|<0.005.
% Author: Holden Leslie-Bole, 2026

thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
S17 = load(fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate','phase2_summary.mat'));
S60 = load(fullfile(pipelineRoot,'outputs','validation','mean_flow_hourly','_aggregate','phase2_summary.mat'));
s17 = S17.summary; s60 = S60.summary;

nums = {'h_med','alpha','beta','R2_Hs2','N_segs'};
for k=1:numel(nums); s17.(nums{k})=s17.(nums{k})(:); s60.(nums{k})=s60.(nums{k})(:); end
s17.deployment=s17.deployment(:); s17.label=s17.label(:);
s60.deployment=s60.deployment(:); s60.label=s60.label(:);

key17 = strings(numel(s17.label),1);
for k=1:numel(s17.label), key17(k)=sprintf('%s/%s',s17.deployment{k},s17.label{k}); end
key60 = strings(numel(s60.label),1);
for k=1:numel(s60.label), key60(k)=sprintf('%s/%s',s60.deployment{k},s60.label{k}); end

[shared, i17, i60] = intersect(key17, key60, 'stable');
da = s60.alpha(i60) - s17.alpha(i17);
db = s60.beta(i60)  - s17.beta(i17);

% Sort by |Δα|
[~, ix] = sort(abs(da), 'descend');

fprintf('\nInstruments sorted by |Δα| (1-hr − 17-min):\n');
fprintf('%-22s  %6s  %10s  %10s  %10s  %10s  %10s  %10s  %8s  %8s  %8s\n', ...
    'instrument','h','alpha17','alpha60','Δα','beta17','beta60','Δβ','R2_17','R2_60','N17');
for k = 1:numel(ix)
    j = ix(k); j17 = i17(j); j60 = i60(j);
    fprintf('%-22s  %6.2f  %+10.4f  %+10.4f  %+10.4f  %+10.4f  %+10.4f  %+10.4f  %8.3f  %8.3f  %8d\n', ...
        shared(j), s17.h_med(j17), s17.alpha(j17), s60.alpha(j60), da(j), ...
        s17.beta(j17), s60.beta(j60), db(j), s17.R2_Hs2(j17), s60.R2_Hs2(j60), s17.N_segs(j17));
end
end
