% Quick test: does flipping U_sn sign at MOP580_5m fix R²_swell?
% Re-run PUV_L4_reflection on this instrument with PUV.BuoyCoord.U/V negated
% (equivalent to rotating heading by 180 deg).

startup_puv;
l1p = 'outputs/L1/TOR24S/MOP586_7m_processed.mat';
l2p = 'outputs/L2/TOR24S/MOP586_7m_L2.mat';
l4p = 'outputs/L4/TOR24S/MOP586_7m_L4.mat';

l1 = load(l1p,'PUV');  PUV = l1.PUV;
l2 = load(l2p,'L2');   L2  = l2.L2;
l4 = load(l4p,'L4');   L4  = l4.L4;

fprintf('\n=== TEST: negate U/V at TBR23/MOP580_5m and re-decompose ===\n');

% Reference (original): print existing per-band R2
fprintf('\nBefore flip:\n');
for nm = {'IG','swell','sea'}
    R = L4.ref.byBand.(nm{1}).R2;
    fprintf('  %-5s median R2 = %.3f\n', nm{1}, median(R, 'omitnan'));
end

% Flip
PUV.BuoyCoord.U = -PUV.BuoyCoord.U;
PUV.BuoyCoord.V = -PUV.BuoyCoord.V;

ref2 = PUV_L4_reflection(PUV, L2, L4.eta);

fprintf('\nAfter flip (180 deg heading correction):\n');
for nm = {'IG','swell','sea'}
    R = ref2.byBand.(nm{1}).R2;
    fprintf('  %-5s median R2 = %.3f\n', nm{1}, median(R, 'omitnan'));
end

% Phase check
[U_sn, ~] = apply_shorenormal_rotation(PUV.BuoyCoord.U, PUV.BuoyCoord.V, L2.shorenormal);
segLen = 7200; startOffset = L2.params.startOffset_samples;
iTry = round(numel(L2.time)/2);
while iTry > 1
    idx = startOffset + ((iTry-1)*segLen+1 : iTry*segLen);
    if idx(end) <= numel(PUV.P) && all(~isnan(PUV.P(idx))) && all(~isnan(U_sn(idx))), break, end
    iTry = iTry - 50;
end
eta = L4.eta.eta_total(:, iTry);
u   = detrend(U_sn(idx));
eta = detrend(eta);
[Pxy,F] = cpsd(eta, u, hann(1024), 512, 2048, PUV.fs);
phi = angle(Pxy)*180/pi;
bands = struct('IG',[0.004 0.04],'swell',[0.04 0.12],'sea',[0.12 0.25]);
for nm = {'IG','swell','sea'}
    m = F >= bands.(nm{1})(1) & F <= bands.(nm{1})(2);
    wgt = abs(Pxy(m)).^2;
    mp = atan2(sum(wgt.*sin(phi(m)*pi/180)), sum(wgt.*cos(phi(m)*pi/180))) * 180/pi;
    fprintf('  phase %-5s = %6.1f deg\n', nm{1}, mp);
end
