S = load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/TBR23/MOP586_7m_L2.mat');
fprintf('L2 fields: %s\n', strjoin(fieldnames(S.L2), ', '));
if isfield(S.L2,'vmom')
    fprintf('vmom subfields: %s\n', strjoin(fieldnames(S.L2.vmom), ', '));
end
fprintf('L2 nSegs = %d, valid = %d\n', numel(S.L2.time), sum(S.L2.segValid));

S3 = load('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L3/TBR23/MOP586_7m_L3.mat');
fprintf('L3 fields: %s\n', strjoin(fieldnames(S3.L3), ', '));
