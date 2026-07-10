function firstGood = puv_trim_anchor(DAT)
%PUV_TRIM_ANCHOR  First in-water sample to start the L1 timeseries at (channel-aware).
%
%   firstGood = puv_trim_anchor(DAT)
%
% Returns the index of the first sample to keep, so the leading block of NaN from before
% submersion is dropped. Pressure marks submersion cleanly, so it is preferred; but a
% whole-deployment pressure failure with a healthy Doppler head used to make DAT(:,15)
% all-NaN and throw, discarding exactly the velocity Stage 1 exists to rescue (F5). This
% falls back to the velocity channel in that case, and errors only if BOTH are dead.
%
% DAT columns: 3,4 = U,V velocity; 15 = pressure (dBar).
%
% 2026-07-10.

idx = find(~isnan(DAT(:,15)), 1, 'first');           % prefer pressure
if isempty(idx)
    idx = find(~isnan(DAT(:,3)) & ~isnan(DAT(:,4)), 1, 'first');   % fall back to velocity
end
if isempty(idx)
    error('puv_trim_anchor:noValidData', ...
        'No valid pressure OR velocity remains after QC -- nothing to keep.');
end
firstGood = idx;
end
