% Compare velocity & pressure moments at MOP580_5m (just reprocessed)
% vs other TBR23 instruments. If the heading fix is the real explanation
% for the "biofouled" pattern, velocity skewness should now match the
% pattern of the other 3 sites, while eta skewness should not have
% changed (and any residual anomaly there would still indicate
% biofouling on the pressure sensor).

startup_puv;
fprintf('\n%-15s | n_seg | Hs med | <u^3> med (cm/s)^3 | <|u|^3> med (cm/s)^3 |  u_sk med  |  u_as med  | u mean cm/s\n', 'instr');
fprintf('%s\n', repmat('-', 1, 130));

cases = { ...
    'outputs/L4/TBR23/MOP580_5m_L4.mat', 'outputs/L2/TBR23/MOP580_5m_L2.mat', 'outputs/L1/TBR23/MOP580_5m_processed.mat'; ...
    'outputs/L4/TBR23/MOP580_7m_L4.mat', 'outputs/L2/TBR23/MOP580_7m_L2.mat', 'outputs/L1/TBR23/MOP580_7m_processed.mat'; ...
    'outputs/L4/TBR23/MOP586_5m_L4.mat', 'outputs/L2/TBR23/MOP586_5m_L2.mat', 'outputs/L1/TBR23/MOP586_5m_processed.mat'; ...
    'outputs/L4/TBR23/MOP586_7m_L4.mat', 'outputs/L2/TBR23/MOP586_7m_L2.mat', 'outputs/L1/TBR23/MOP586_7m_processed.mat'  ...
};

for c = 1:size(cases,1)
    l4p = cases{c,1}; l2p = cases{c,2}; l1p = cases{c,3};
    l4 = load(l4p,'L4'); L4 = l4.L4;
    l2 = load(l2p,'L2'); L2 = l2.L2;
    l1 = load(l1p,'PUV'); PUV = l1.PUV;

    [U_sn, ~] = apply_shorenormal_rotation(PUV.BuoyCoord.U, PUV.BuoyCoord.V, L2.shorenormal);
    u_cm = 100 * U_sn;
    u_clean = u_cm(~isnan(u_cm));
    u_mean = mean(u_clean);
    u_demean = u_clean - u_mean;
    u3_med = mean(u_demean.^3);          % third moment in cm^3/s^3 over full record
    abs_u3 = mean(abs(u_demean).^3);

    instr = regexprep(l4p, '.*[/\\]', '');
    instr = regexprep(instr, '_L4\.mat$', '');
    Hs = NaN;
    if isfield(L2, 'Hs'), Hs = median(L2.Hs, 'omitnan'); end
    eta_sk = NaN; eta_as = NaN;
    if isfield(L4,'moments')
        % L4.moments stores velocity skewness/asymmetry; pressure-based ones
        % live in L2 (Spp). Use L2.Hs for Hs.
        u_sk = median(L4.moments.skewness_u, 'omitnan');
        u_as = median(L4.moments.asymmetry_u, 'omitnan');
    else
        u_sk = NaN; u_as = NaN;
    end
    nSeg = numel(L2.time);

    fprintf('%-15s | %5d | %5.2f m | %18.0f | %19.0f | %10.3f | %10.3f | %10.3f\n', ...
        instr, nSeg, Hs, u3_med, abs_u3, u_sk, u_as, u_mean);
end

fprintf('\nInterpretation:\n');
fprintf('  - All 4 should have similar SIGN for <u^3> (positive onshore for shoaling waves).\n');
fprintf('  - eta_skewness and eta_asymmetry come from pressure only and depend only on shoaling state,\n');
fprintf('    not on the velocity sign.\n');
