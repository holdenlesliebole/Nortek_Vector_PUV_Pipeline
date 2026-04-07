function L3 = PUV_L3_bands(L2)
% PUV_L3_BANDS  Level 3a: frequency-band energy decomposition.
%
%   L3 = PUV_L3_bands(L2)
%
%   Decomposes L2 spectral products into frequency bands and computes
%   band-specific energy flux, wave height, and mean period.
%
%   INPUTS
%     L2 - L2 struct from PUV_L2_spectral
%
%   OUTPUT
%     L3 - struct with band-decomposed products (same time axis as L2)
%
%   BAND DEFINITIONS
%     IG:    0.004 – 0.04  Hz  (infragravity)
%     Swell: 0.04  – 0.10  Hz  (swell)
%     Sea:   0.10  – 0.25  Hz  (local wind seas)
%     Total: 0.004 – 0.25  Hz  (full sea-swell + IG)

g   = 9.81;
rho = 1025;

f  = L2.f;
df = f(2) - f(1);
nSeg = length(L2.time);
validIdx = L2.segValid;

%% Band definitions
bands = struct();
bands.ig    = [0.004, 0.04];
bands.swell = [0.04,  0.10];
bands.sea   = [0.10,  0.25];
bands.total = [0.004, 0.25];

bandNames = fieldnames(bands);
nBands = length(bandNames);

% Frequency masks
for b = 1:nBands
    bname = bandNames{b};
    brange = bands.(bname);
    masks.(bname) = f >= brange(1) & f <= brange(2);
end

%% Pre-allocate outputs
nanVec = NaN(nSeg, 1);

% Band energy flux (W/m)
L3.Ef_ig    = nanVec;
L3.Ef_swell = nanVec;
L3.Ef_sea   = nanVec;
L3.Ef_total = nanVec;

% Band wave height (m)
L3.Hs_ig    = nanVec;
L3.Hs_swell = nanVec;
L3.Hs_sea   = nanVec;
L3.Hs_total = nanVec;

% Band mean period (s)
L3.Tm_ig    = nanVec;
L3.Tm_swell = nanVec;
L3.Tm_sea   = nanVec;
L3.Tm_total = nanVec;

% Dominant band flag (1=IG, 2=swell, 3=sea)
L3.dominant_band = nanVec;

% Energy flux partitioning (fraction of total)
L3.frac_ig    = nanVec;
L3.frac_swell = nanVec;
L3.frac_sea   = nanVec;

%% Compute per segment
for i = 1:nSeg
    if ~validIdx(i), continue; end

    S = L2.S_eta(:, i);
    h = L2.depth(i);

    if isnan(h) || h <= 0, continue; end

    % Wavenumber and group velocity for all frequencies
    omega = 2 * pi * f(2:end);
    k = get_wavenumber(omega, h);
    cg = get_cg(k, h);
    cg_full = [0; cg(:)];  % DC bin has no group velocity

    for b = 1:nBands
        bname = bandNames{b};
        mask = masks.(bname);

        % Wave height: Hs = 4*sqrt(m0)
        m0 = trapz(f(mask), S(mask));
        Hs = 4 * sqrt(max(m0, 0));

        % Energy flux: Ef = rho*g * integral(cg * S * df)
        Ef = rho * g * trapz(f(mask), cg_full(mask) .* S(mask));

        % Mean period: Tm = m0/m1 where m1 = integral(f*S*df)
        m1 = trapz(f(mask), f(mask) .* S(mask));
        if m1 > 0
            Tm = m0 / m1;
        else
            Tm = NaN;
        end

        L3.(['Hs_' bname])(i) = Hs;
        L3.(['Ef_' bname])(i) = Ef;
        L3.(['Tm_' bname])(i) = Tm;
    end

    % Dominant band (by energy flux)
    Ef_bands = [L3.Ef_ig(i), L3.Ef_swell(i), L3.Ef_sea(i)];
    [~, iMax] = max(Ef_bands);
    L3.dominant_band(i) = iMax;

    % Partitioning fractions
    Ef_tot = L3.Ef_total(i);
    if Ef_tot > 0
        L3.frac_ig(i)    = L3.Ef_ig(i)    / Ef_tot;
        L3.frac_swell(i) = L3.Ef_swell(i) / Ef_tot;
        L3.frac_sea(i)   = L3.Ef_sea(i)   / Ef_tot;
    end
end

%% Metadata
L3.time           = L2.time;
L3.segValid       = L2.segValid;
L3.label          = L2.label;
L3.deploymentName = L2.deploymentName;
L3.depth          = L2.depth;
L3.bands          = bands;

%% Summary stats
nValid = sum(validIdx);
fprintf('  L3a bands: %d valid segments\n', nValid);
fprintf('    Median Hs — swell: %.3f m, sea: %.3f m, IG: %.3f m\n', ...
    median(L3.Hs_swell(validIdx), 'omitnan'), ...
    median(L3.Hs_sea(validIdx), 'omitnan'), ...
    median(L3.Hs_ig(validIdx), 'omitnan'));
fprintf('    Median Ef — swell: %.0f W/m, sea: %.0f W/m, IG: %.0f W/m\n', ...
    median(L3.Ef_swell(validIdx), 'omitnan'), ...
    median(L3.Ef_sea(validIdx), 'omitnan'), ...
    median(L3.Ef_ig(validIdx), 'omitnan'));

% Dominant band statistics
domValid = L3.dominant_band(validIdx);
fprintf('    Dominant band: swell %.0f%%, sea %.0f%%, IG %.0f%%\n', ...
    100*sum(domValid==2)/nValid, 100*sum(domValid==3)/nValid, 100*sum(domValid==1)/nValid);

%% Consistency check: total should match L2.Ef
Ef_check = L3.Ef_total(validIdx);
Ef_L2 = L2.Ef(validIdx);
good = ~isnan(Ef_check) & ~isnan(Ef_L2) & Ef_L2 > 0;
if sum(good) > 10
    ratio = median(Ef_check(good) ./ Ef_L2(good));
    fprintf('    Ef_total vs L2.Ef: ratio = %.4f (expect ~1.0)\n', ratio);
end

end
