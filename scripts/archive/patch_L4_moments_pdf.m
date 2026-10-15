% Add L4.moments and L4.pdf to the 2 heading-fix reprocessed L4 files.
% (The reprocess script ran bispectra/boundwave/reflection but not the
% velocity-distribution-dependent moments + pdf modules.)

startup_puv;
projRoot = fileparts(fileparts(mfilename('fullpath')));

targets = { ...
    'TBR23',  'MOP580_5m'; ...
    'TOR24S', 'MOP586_7m' ...
};

for t = 1:size(targets,1)
    dep = targets{t,1}; instr = targets{t,2};
    fprintf('\n========== %s/%s ==========\n', dep, instr);

    l1p = fullfile(projRoot,'outputs','L1', dep, [instr '_processed.mat']);
    l2p = fullfile(projRoot,'outputs','L2', dep, [instr '_L2.mat']);
    l4p = fullfile(projRoot,'outputs','L4', dep, [instr '_L4.mat']);

    l1 = load(l1p,'PUV'); PUV = l1.PUV;
    l2 = load(l2p,'L2');  L2  = l2.L2;
    l4 = load(l4p,'L4');  L4  = l4.L4;

    tM = tic;
    L4.moments = PUV_L4_moments(L2);
    fprintf('  L4.moments: skewness_u med=%.3f, asymmetry_u med=%.3f  (%.1f s)\n', ...
        median(L4.moments.skewness_u,'omitnan'), ...
        median(L4.moments.asymmetry_u,'omitnan'), toc(tM));

    tP = tic;
    L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
    fprintf('  L4.pdf:     done (%.1f s)\n', toc(tP));

    save(l4p, 'L4', '-v7.3');
    info = dir(l4p);
    fprintf('  Saved %s (%.0f MB)\n', l4p, info.bytes/1e6);
end
fprintf('\nDone.\n');
