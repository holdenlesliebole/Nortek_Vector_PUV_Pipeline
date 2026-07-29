startup_puv;
paths = { ...
    'outputs/L2/TBR23/MOP580_5m_L2.mat',  'outputs/L1/TBR23/MOP580_5m_processed.mat'; ...
    'outputs/L2/TOR24S/MOP586_7m_L2.mat', 'outputs/L1/TOR24S/MOP586_7m_processed.mat'; ...
    'outputs/L2/TBR23/MOP580_7m_L2.mat',  'outputs/L1/TBR23/MOP580_7m_processed.mat'; ...
    'outputs/L2/TOR24S/MOP586_5m_L2.mat', 'outputs/L1/TOR24S/MOP586_5m_processed.mat' ...
};
for ii = 1:size(paths,1)
    l2p = paths{ii,1}; l1p = paths{ii,2};
    l2 = load(l2p, 'L2'); L2 = l2.L2;
    l1 = load(l1p, 'PUV'); PUV = l1.PUV;
    fprintf('\n=== %s ===\n', l2p);
    fprintf('  L2.doffp = %.4f m  (distance from bed to pressure sensor)\n', L2.doffp);
    if isfield(L2, 'doffv'), fprintf('  L2.doffv = %.4f m\n', L2.doffv); end
    if isfield(L2, 'doff'),  fprintf('  L2.doff  = %.4f m\n', L2.doff); end
    fprintf('  L2.shorenormal = %.2f deg\n', L2.shorenormal);
    fprintf('  L2.depth   range [%.2f, %.2f] m, median %.2f m\n', ...
        min(L2.depth), max(L2.depth), median(L2.depth));
    fprintf('  PUV.BuoyCoord.U std = %.4f m/s, mean=%.4f m/s\n', std(PUV.BuoyCoord.U, 'omitnan'), mean(PUV.BuoyCoord.U, 'omitnan'));
    fprintf('  PUV.BuoyCoord.V std = %.4f m/s, mean=%.4f m/s\n', std(PUV.BuoyCoord.V, 'omitnan'), mean(PUV.BuoyCoord.V, 'omitnan'));
    if isfield(PUV, 'doffp'),  fprintf('  PUV.doffp  = %.4f m\n', PUV.doffp); end
    if isfield(PUV, 'doffv'),  fprintf('  PUV.doffv  = %.4f m\n', PUV.doffv); end
    if isfield(PUV, 'doff'),   fprintf('  PUV.doff   = %.4f m\n', PUV.doff); end
    if isfield(PUV, 'params')
        fns = fieldnames(PUV.params);
        for f = fns(:)', fprintf('  PUV.params.%s = %s\n', f{1}, mat2str(PUV.params.(f{1})(1:min(end,3)))); end
    end
end
