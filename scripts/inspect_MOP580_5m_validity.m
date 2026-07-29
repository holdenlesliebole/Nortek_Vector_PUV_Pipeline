% Diagnose what's causing segment rejection at MOP580_5m post-heading-fix.
% Categorize each invalid segment by reason: NaN-frac, Hs/h, depth dev, or
% other. Compare to MOP580_7m, MOP586_5m, MOP586_7m. Also plot validity
% vs time to see if losses cluster (storm? burial?) or are spread out.

startup_puv;
projRoot = fileparts(fileparts(mfilename('fullpath')));

cases = { ...
    'TBR23', 'MOP580_5m', 'fixed';
    'TBR23', 'MOP580_7m', 'clean ref';
    'TBR23', 'MOP586_5m', 'clean ref';
    'TBR23', 'MOP586_7m', 'clean ref' ...
};

results = cell(size(cases,1), 1);

for c = 1:size(cases,1)
    dep = cases{c,1}; instr = cases{c,2}; note = cases{c,3};
    l1p = fullfile(projRoot, 'outputs','L1', dep, [instr '_processed.mat']);
    l2p = fullfile(projRoot, 'outputs','L2', dep, [instr '_L2.mat']);

    l1 = load(l1p,'PUV'); PUV = l1.PUV;
    l2 = load(l2p,'L2'); L2  = l2.L2;

    fs = PUV.fs;
    segLen = L2.params.segLen;
    startOffset = L2.params.startOffset_samples;
    nSeg = numel(L2.time);
    nMaxFrac = 0.1;   % default in PUV_L2_spectral

    % Rotate u,v to shore-normal frame (same as L2 does)
    [U_sn, V_sn] = apply_shorenormal_rotation(PUV.BuoyCoord.U, PUV.BuoyCoord.V, L2.shorenormal);

    reason_nan = false(nSeg,1);
    reason_Hsh = false(nSeg,1);
    reason_depth = false(nSeg,1);

    for i = 1:nSeg
        idx = startOffset + ((i-1)*segLen + 1 : i*segLen);
        if idx(end) > numel(PUV.P), reason_nan(i) = true; continue, end
        pSeg = PUV.P(idx);
        uSeg = U_sn(idx);
        vSeg = V_sn(idx);
        nf = sum(isnan(pSeg) | isnan(uSeg) | isnan(vSeg)) / segLen;
        if nf > nMaxFrac, reason_nan(i) = true; continue, end
    end

    % Hs/h and depth-deviation reasons from L2 outputs (only computed when not nan-rejected)
    HsToH = L2.Hs ./ L2.depth;
    reason_Hsh(~reason_nan & HsToH > 1.5) = true;

    depth_nom = NaN;
    cfgFn = str2func([dep '_config']); cfg = cfgFn();
    for k = 1:numel(cfg.instruments)
        if strcmp(cfg.instruments(k).label, instr)
            depth_nom = cfg.instruments(k).depth_nominal;
            break
        end
    end
    if ~isnan(depth_nom)
        reason_depth(~reason_nan & abs(L2.depth - depth_nom) > 0.5*depth_nom) = true;
    end

    nValid_actual = sum(L2.segValid);
    nNan = sum(reason_nan);
    nHsh = sum(reason_Hsh);
    nDepth = sum(reason_depth);
    nOther = nSeg - nValid_actual - nNan - nHsh - nDepth;

    fprintf('%-18s [%-10s] %d total: %d valid (%.0f%%) | nan=%d, Hs/h=%d, depth=%d, other=%d\n', ...
        [dep '/' instr], note, nSeg, nValid_actual, 100*nValid_actual/nSeg, nNan, nHsh, nDepth, max(0,nOther));

    results{c} = struct('dep',dep,'instr',instr,'time',L2.time, ...
                       'valid',L2.segValid,'nan',reason_nan, ...
                       'Hsh',reason_Hsh,'depth',reason_depth);
end

% Time-series view for MOP580_5m: when do invalidities cluster?
r = results{1};
fprintf('\n--- MOP580_5m validity time series ---\n');
% Bin by day
days = floor(datenum(r.time));
[uDay, ~, idx] = unique(days);
nValidPerDay = accumarray(idx, r.valid, [], @sum);
nTotalPerDay = accumarray(idx, ones(size(r.valid)), [], @sum);
ratePerDay = nValidPerDay ./ nTotalPerDay;
fprintf('Date         | valid / total | rate\n');
for k = 1:numel(uDay)
    fprintf('%s   | %3d / %3d     | %.0f%%\n', datestr(uDay(k),'yyyy-mm-dd'), ...
        nValidPerDay(k), nTotalPerDay(k), 100*ratePerDay(k));
end
