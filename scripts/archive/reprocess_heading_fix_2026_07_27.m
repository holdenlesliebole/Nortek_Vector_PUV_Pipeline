% REPROCESS_HEADING_FIX_2026_07_27  Rebuild L1->L2->L3->L4 for the three
% 2016-17 Torrey-offshore deployments whose heading was corrected on 2026-07-27.
%
%   TOR16B/MOP591_9m   auto 198.0 -> explicit  87.3  (-110.7, empirical)
%   TOR16C/MOP591_9m   auto 268.4 -> explicit  88.4  (-180.0, exact)
%   TOR16D/MOP591_9m   auto 265.2 -> explicit  85.2  (-180.0, exact)
%
% Heading enters at the L1 coordinate rotation, so the correction MUST propagate
% through the whole chain -- patching at L4 would leave L2 velocities, bed
% stress, radiation stress and every L4 directional product wrong.
%
% Backs up the existing outputs first. Follows the pattern established by
% scripts/reprocess_heading_fix.m (the May 2026 fix for TBR23/MOP580_5m and
% TOR24S/MOP586_7m).
%
% Detection + evidence: validation/sweep_heading_flips.m,
% validation/diagnose_sxy_heading.m.
%
% Author: Holden Leslie-Bole, 2026

startup_puv

targets = {'TOR16B','TOR16C','TOR16D'};
instr   = 'MOP591_9m';
root    = fileparts(fileparts(mfilename('fullpath')));
outputs = fullfile(root,'outputs');
stamp   = '2026-07-27';
backup  = fullfile(outputs, ['_pre_headingfix_backup_' stamp]);

if ~isfolder(backup), mkdir(backup); end
fprintf('\n=========== HEADING FIX REPROCESS (%s) ===========\n', stamp);
fprintf('Backup root: %s\n', backup);

% ---- 0. verify the mount before touching anything
[st,~] = system('mount | grep -c /Volumes/group');
if st ~= 0
    warning('Could not check the server mount. L1 reads raw data from /Volumes/group.');
end

% ---- 1. back up existing products
for t = 1:numel(targets)
    for L = {'L1','L2','L3','L4'}
        src = fullfile(outputs, L{1}, targets{t});
        if ~isfolder(src), continue; end
        dst = fullfile(backup, L{1}, targets{t});
        if ~isfolder(dst), mkdir(dst); end
        copyfile(fullfile(src,'*'), dst);
    end
    fprintf('  backed up %s\n', targets{t});
end

% ---- 2. rebuild
for t = 1:numel(targets)
    dep = targets{t};
    fprintf('\n========== %s/%s ==========\n', dep, instr);
    cfg = TorreyOffshore_config(dep);

    localCache = fullfile(root,'raw_cache',cfg.name);
    if isfolder(localCache)
        cfg.localDataRoot = localCache;
        fprintf('  using local raw cache\n');
    end

    ii = find(strcmp({cfg.instruments.label}, instr), 1);
    if isempty(ii), error('no %s in %s config', instr, dep); end
    fprintf('  config heading is now %.4f deg (was NaN/auto)\n', cfg.instruments(ii).heading);

    % --- L1
    tic; PUV = PUV_raw_process(cfg.instruments(ii), cfg);
    d1 = fullfile(cfg.outputDir,'L1',cfg.name); if ~isfolder(d1), mkdir(d1); end
    save(fullfile(d1,[instr '_processed.mat']),'PUV','-v7.3');
    fprintf('  L1 done (%.1f min), rotation.sensor = %.2f\n', toc/60, PUV.rotation.sensor);

    % --- L2
    tic; L2 = PUV_L2_spectral(PUV, cfg.instruments(ii));
    d2 = fullfile(cfg.outputDir,'L2',cfg.name); if ~isfolder(d2), mkdir(d2); end
    save(fullfile(d2,[instr '_L2.mat']),'L2','-v7.3');
    fprintf('  L2 done (%.1f min, %d segments)\n', toc/60, numel(L2.time));

    % --- L3 (module chain, as PUV_L3_driver does)
    tic;
    L3 = PUV_L3_bands(L2);
    L3 = PUV_L3_storms(L3, L2);
    L3 = PUV_L3_transport(L3, L2);
    L3 = PUV_L3_currents(L3, L2);
    d3 = fullfile(cfg.outputDir,'L3',cfg.name); if ~isfolder(d3), mkdir(d3); end
    save(fullfile(d3,[instr '_L3.mat']),'L3','-v7.3');
    fprintf('  L3 done (%.1f min)\n', toc/60);

    % --- L4 (module chain, matching scripts/reprocess_heading_fix.m)
    tic;
    L4 = struct();
    L4.eta             = PUV_L4_eta(PUV, L2);
    L4.bispectra       = PUV_L4_bispectra(L4.eta.eta_total, L2);
    L4.boundwave       = PUV_L4_boundwave(L4.eta, L2, PUV);
    L4.ref             = PUV_L4_reflection(PUV, L2, L4.eta);
    L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
    L4.moments         = PUV_L4_moments(L2);
    L4.label           = L2.label;
    L4.deploymentName  = L2.deploymentName;
    L4.mopStation      = L2.mopStation;
    L4.builtAt         = datetime('now');
    d4 = fullfile(cfg.outputDir,'L4',cfg.name); if ~isfolder(d4), mkdir(d4); end
    save(fullfile(d4,[instr '_L4.mat']),'L4','-v7.3');
    fprintf('  L4 done (%.1f min)\n', toc/60);

    % --- immediate check: per-band R2 should collapse to O(0.01) once fixed
    fprintf('  per-band median R2 (swell >> IG was the symptom):\n');
    for nm = {'IG','swell','sea'}
        if isfield(L4.ref,'byBand') && isfield(L4.ref.byBand, nm{1})
            fprintf('    %-5s = %.3f\n', nm{1}, median(L4.ref.byBand.(nm{1}).R2,'omitnan'));
        end
    end
end

fprintf('\n=========== VERIFY ===========\n');
fprintf('Run these and confirm the three records now read clean:\n');
fprintf('  validation/sweep_heading_flips.m    -> a1_swell should be ~ +0.95\n');
fprintf('  validation/audit_L4_coverage.m      -> still 65 records, 0 problems\n');
fprintf('Then re-run the sweeps that use directional data:\n');
fprintf('  validation/run_consequences_sweep.m  (Sxy)\n');
fprintf('  validation/run_nonlinearity_sweep.m  (bispectra are direction-independent,\n');
fprintf('                                        but rerun for a consistent snapshot)\n\n');
