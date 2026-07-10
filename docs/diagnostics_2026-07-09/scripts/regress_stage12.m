% Real-data regression for the Stage-1/2 pipeline change.
% Re-runs L1 + L2 on TOR23W/MOP586_10m with the NEW per-channel code, writing to a
% scratch outputDir so the existing outputs/L1 and outputs/L2 are untouched, then:
%   R1  healthy segments must reproduce the EXISTING L2 (this change is a no-op on good data)
%   R2  the Phase-A segments the old gate destroyed must reappear as segValid_vel
%   R3  the sound-speed rescale must fire only where the thermistor failed
startup_puv;
SCRATCH='/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/regress';
if ~isfolder(SCRATCH), mkdir(SCRATCH); end
cfg = TOR23W_config();
cfg.outputDir = SCRATCH;
k = find(strcmp({cfg.instruments.label},'MOP586_10m'));
instr = cfg.instruments(k);
fprintf('L1 on %s ...\n', instr.label); tic
PUV = PUV_raw_process(instr, cfg);
fprintf('L1 done in %.1f min\n', toc/60);
save(fullfile(SCRATCH,'MOP586_10m_processed.mat'),'PUV','-v7.3');
fprintf('L2 ...\n'); tic
L2new = PUV_L2_spectral(PUV, instr, struct());
fprintf('L2 done in %.1f min\n', toc/60);
save(fullfile(SCRATCH,'MOP586_10m_L2_new.mat'),'L2new','-v7.3');
fprintf('REGRESS_L2_DONE\n');
