% Check cross-spectral coherence + phase between eta and shore-normal velocity
% at swell/sea frequencies for the 2 pathological instruments.
% For an incoming shore-normal wave, eta and u_sn should be IN PHASE (~0 deg).
% A persistent ~180 deg shift would explain the inverted decomposition.

startup_puv;
cases = { ...
    'TBR23/MOP580_5m',  'broken'; ...
    'TBR23/MOP580_7m',  'clean reference'; ...
    'TOR24S/MOP586_7m', 'broken'; ...
    'TOR24S/MOP586_5m', 'clean reference' ...
};
for c = 1:size(cases,1)
    tag  = cases{c,1};
    note = cases{c,2};
    parts = strsplit(tag, '/');
    dep = parts{1}; instr = parts{2};
    l1p = fullfile('outputs','L1',dep,[instr '_processed.mat']);
    l2p = fullfile('outputs','L2',dep,[instr '_L2.mat']);
    l4p = fullfile('outputs','L4',dep,[instr '_L4.mat']);
    fprintf('\n=== %s (%s) ===\n', tag, note);

    l1 = load(l1p,'PUV'); PUV = l1.PUV;
    l2 = load(l2p,'L2'); L2 = l2.L2;
    l4 = load(l4p,'L4'); L4 = l4.L4;

    [U_sn, ~] = apply_shorenormal_rotation(PUV.BuoyCoord.U, PUV.BuoyCoord.V, L2.shorenormal);
    fs = PUV.fs;
    segLen = 7200; % 1-hour @ 2 Hz
    startOffset = L2.params.startOffset_samples;

    % Pick a robustly mid-deployment segment with valid data
    nSeg = numel(L2.time);
    iTry = round(nSeg/2);
    while iTry > 1
        idx = startOffset + ((iTry-1)*segLen+1 : iTry*segLen);
        if idx(end) <= numel(PUV.P) && all(~isnan(PUV.P(idx))) && all(~isnan(U_sn(idx)))
            break
        end
        iTry = iTry - 50;
    end
    eta = L4.eta.eta_total(:, iTry);
    u   = U_sn(idx);
    u = detrend(u); eta = detrend(eta);

    % Welch cross-spectrum
    [Cxy, F] = mscohere(eta, u, hann(1024), 512, 2048, fs);
    [Pxy, ~] = cpsd(eta, u, hann(1024), 512, 2048, fs);
    phi = angle(Pxy) * 180/pi;

    bands = struct('IG',[0.004 0.04], 'swell',[0.04 0.12], 'sea',[0.12 0.25]);
    for nm = {'IG','swell','sea'}
        m = F >= bands.(nm{1})(1) & F <= bands.(nm{1})(2);
        % Energy-weighted mean phase
        wgt = (abs(Pxy(m))).^2;
        if sum(wgt) > 0
            mean_phi = atan2(sum(wgt.*sin(phi(m)*pi/180)), sum(wgt.*cos(phi(m)*pi/180))) * 180/pi;
        else
            mean_phi = NaN;
        end
        coh = mean(Cxy(m), 'omitnan');
        fprintf('  %-5s coh=%.2f  mean phase=%6.1f deg  (n=%d bins)\n', nm{1}, coh, mean_phi, sum(m));
    end
end
