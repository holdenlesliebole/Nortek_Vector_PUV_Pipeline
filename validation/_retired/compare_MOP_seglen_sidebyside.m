function compare_MOP_seglen_sidebyside(deployment, labels)
% COMPARE_MOP_SEGLEN_SIDEBYSIDE  Run compare_PUV_MOP_spectra on both
% 17-min and 1-hour L2 for the given instruments and capture reports.
%
%   compare_MOP_seglen_sidebyside('TBR23', {'MOP586_5m','MOP586_7m'})
%
% Side-effects: figures into outputs/validation/ tagged with _17min / _1hour
% suffixes via deploymentName monkey-patch. Reports written to
% outputs/validation/seglen_compare/<deployment>/MOP_compare_<label>.txt
% Author: Holden Leslie-Bole, 2026

if ischar(labels) || isstring(labels), labels = cellstr(labels); end

thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
L2dir       = fullfile(pipelineRoot,'outputs','L2_17min');
L2hourlyDir = fullfile(pipelineRoot,'outputs','L2');
reportDir   = fullfile(pipelineRoot,'outputs','validation','seglen_compare', deployment);
if ~exist(reportDir,'dir'), mkdir(reportDir); end

for iI = 1:numel(labels)
    label = labels{iI};

    % --- 17-min run ---
    diaryFile = fullfile(reportDir, sprintf('MOP_compare_%s.txt', label));
    if exist(diaryFile,'file'), delete(diaryFile); end
    diary(diaryFile);
    diary on;

    fprintf('\n##############################################################\n');
    fprintf('## %s / %s — 17-minute segment L2 vs MOP\n', deployment, label);
    fprintf('##############################################################\n');
    S17 = load(fullfile(L2dir, deployment, [label '_L2.mat']));
    L17 = S17.L2;
    L17.deploymentName = sprintf('%s_17min', deployment);   % tag figure names
    try
        compare_PUV_MOP_spectra(L17, 6);
    catch ME
        fprintf('  17-min run failed: %s\n', ME.message);
    end
    close all;

    % --- 1-hour run ---
    fprintf('\n##############################################################\n');
    fprintf('## %s / %s — 1-hour segment L2 vs MOP\n', deployment, label);
    fprintf('##############################################################\n');
    S60 = load(fullfile(L2hourlyDir, deployment, [label '_L2.mat']));
    L60 = S60.L2;
    L60.deploymentName = sprintf('%s_1hour', deployment);
    try
        compare_PUV_MOP_spectra(L60, 6);
    catch ME
        fprintf('  1-hour run failed: %s\n', ME.message);
    end
    close all;

    diary off;
    fprintf('\nReport: %s\n', diaryFile);
end
end
