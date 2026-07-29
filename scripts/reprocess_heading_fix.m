% REPROCESS_HEADING_FIX  Reprocess L1->L2->L4 for the 2 instruments whose
% heading config was corrected on 2026-05-14:
%   TBR23/MOP580_5m: 270.7361 -> 90.7361
%   TOR24S/MOP586_7m: NaN(auto=258.7) -> explicit 78.7
%
% Each instrument: L1 + L2 + L4 (eta, bispectra, boundwave, ref, ref_free)
% plus the band-aware reflection from PUV_L4_reflection.m.

startup_puv;

targets = { ...
    'TBR23',  'MOP580_5m'; ...
    'TOR24S', 'MOP586_7m' ...
};

for t = 1:size(targets,1)
    dep   = targets{t,1};
    instr = targets{t,2};
    fprintf('\n========== %s/%s ==========\n', dep, instr);

    cfgFn = str2func([dep '_config']);
    cfg = cfgFn();
    localCache = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'raw_cache', cfg.name);
    if isfolder(localCache)
        cfg.localDataRoot = localCache;
        fprintf('  Using local cache: %s\n', localCache);
    end
    iInstr = -1;
    for k = 1:numel(cfg.instruments)
        if strcmp(cfg.instruments(k).label, instr), iInstr = k; break; end
    end
    if iInstr < 0, error('Could not find %s in %s config', instr, dep); end
    fprintf('  Config heading is now %.4f deg\n', cfg.instruments(iInstr).heading);

    % --- L1 ---
    tL1 = tic;
    PUV = PUV_raw_process(cfg.instruments(iInstr), cfg);
    l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
    if ~isfolder(l1Dir), mkdir(l1Dir); end
    l1Path = fullfile(l1Dir, [instr '_processed.mat']);
    save(l1Path, 'PUV', '-v7.3');
    fprintf('  L1 saved (%.1f s)\n', toc(tL1));

    % --- L2 ---
    tL2 = tic;
    L2 = PUV_L2_spectral(PUV, cfg.instruments(iInstr));
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l2Dir), mkdir(l2Dir); end
    l2Path = fullfile(l2Dir, [instr '_L2.mat']);
    save(l2Path, 'L2', '-v7.3');
    fprintf('  L2 saved (%.1f s, %d segments)\n', toc(tL2), numel(L2.time));

    % --- L4 ---
    % Build the COMPLETE struct. An earlier version of this script wrote only
    % eta/bispectra/boundwave/ref/reflection_free and re-saved over the
    % existing file, which silently stripped `moments`, `pdf` and the whole
    % metadata block. That damaged TBR23/MOP580_5m (May 2026) and TOR16B/C/D
    % (2026-07-27) -- both times unnoticed, because audit_L4_coverage checks
    % sub-products but not metadata, and the loss only surfaces when
    % PUV_L4_xspec asks for L4.LATLON / L4.shorenormal.
    %
    % `clear L4` matters too: without it the struct leaks across loop
    % iterations and one instrument can inherit another's fields.
    tL4 = tic;
    clear L4
    L4.eta = PUV_L4_eta(PUV, L2);
    L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
    L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, struct('useParallel', true));
    L4.moments = PUV_L4_moments(L2);
    L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
    L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);
    L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
    L4.label          = PUV.label;
    L4.deploymentName = PUV.deploymentName;
    L4.LATLON         = PUV.LATLON;
    L4.doffp          = PUV.doffp;
    L4.shorenormal    = L2.shorenormal;
    if isfield(L2, 'mopStation'), L4.mopStation = L2.mopStation; end
    L4.builtAt        = datetime('now');
    l4Dir = fullfile(cfg.outputDir, 'L4', cfg.name);
    if ~isfolder(l4Dir), mkdir(l4Dir); end
    l4Path = fullfile(l4Dir, [instr '_L4.mat']);
    save(l4Path, 'L4', '-v7.3');
    fprintf('  L4 saved (%.1f min)\n', toc(tL4)/60);

    % --- Verify R2_band ---
    fprintf('  Verification — per-band median R2:\n');
    for nm = {'IG','swell','sea'}
        R = L4.ref.byBand.(nm{1}).R2;
        fprintf('    %-5s = %.3f\n', nm{1}, median(R, 'omitnan'));
    end
end
fprintf('\nAll done.\n');
