% L4_L2_INDEX_MAP  Map L2 segment indices onto L4 segment indices by TIME.
%
% function [l4map, info] = l4_l2_index_map(L2, L4, opts)
%
% L4 per-segment arrays are NOT guaranteed to align with L2 by index. L4 is
% built against whatever L2 was canonical at the time, and an L1/L2 rerun can
% change the segment grid. Three catalog records (SIO25B/SIO_6m,
% TOR24S/MOP586_7m, TOR24W/MOP586_10m) have an L2 that gained one segment at
% the START, so L4 index i corresponds to L2 index i+1 for EVERY segment --
% not just the tail.
%
% Indexing an L4 array with an L2 index is therefore unsafe. Where the L4 array
% is shorter it raises an out-of-range error (loud, survivable); where it is
% the same length or longer, or where a shorter LOGICAL mask is used to index a
% longer L2 array, MATLAB silently returns the wrong hour. This helper removes
% the guesswork: match on time, always, even when the counts happen to agree.
%
% INPUTS
%   L2   - L2 struct (uses .time)
%   L4   - L4 struct. Any per-segment sub-product carrying .time works;
%          by default the first present of ref / eta / bispectra / boundwave /
%          moments / reflection_free is used. All of them share one grid within
%          a given L4 file.
%   opts - optional struct
%          .tol     max |t4 - t2| accepted as the same segment
%                   (duration; default minutes(1))
%          .source  name of the L4 sub-product to take .time from
%                   (default: first available, order as above)
%
% OUTPUT
%   l4map - (numel(L2.time) x 1) double. l4map(i) is the L4 index matching
%           L2 segment i, or NaN where L4 has no segment within .tol.
%           Use as:  j = l4map(i);  if isnan(j), skip;  x = L4.ref.R2_IG(j);
%   info  - struct with .nL2 .nL4 .nMatched .maxOffset .identity .source
%           .identity is true when l4map is exactly (1:nL2)', i.e. the naive
%           index assumption would have been correct for this record.
%
% Author: Holden Leslie-Bole, 2026

function [l4map, info] = l4_l2_index_map(L2, L4, opts)

if nargin < 3, opts = struct(); end
if ~isfield(opts, 'tol'), opts.tol = minutes(1); end

order = {'ref','eta','bispectra','boundwave','moments','reflection_free'};
if isfield(opts, 'source')
    order = {opts.source};
end
src = '';
for k = 1:numel(order)
    if isfield(L4, order{k}) && isfield(L4.(order{k}), 'time')
        src = order{k}; break
    end
end
if isempty(src)
    error('l4_l2_index_map:noTime', ...
        'No L4 sub-product with a .time field (looked for: %s).', strjoin(order, ', '));
end

t2 = L2.time(:);
t4 = L4.(src).time(:);

% datetime comparison requires a consistent time zone on both sides
if isempty(t2.TimeZone) && ~isempty(t4.TimeZone), t2.TimeZone = t4.TimeZone; end
if isempty(t4.TimeZone) && ~isempty(t2.TimeZone), t4.TimeZone = t2.TimeZone; end

nL2 = numel(t2);
nL4 = numel(t4);
l4map = NaN(nL2, 1);

% Both grids are sorted and regular, so the nearest match is found by
% interpolating index-vs-time and checking the residual.
if nL4 > 1
    cand = interp1(t4, (1:nL4)', t2, 'nearest', 'extrap');
else
    cand = ones(nL2, 1);
end
ok = abs(t4(cand) - t2) <= opts.tol;
l4map(ok) = cand(ok);

info = struct();
info.source    = src;
info.nL2       = nL2;
info.nL4       = nL4;
info.nMatched  = sum(~isnan(l4map));
info.maxOffset = max(abs(l4map - (1:nL2)'), [], 'omitnan');
if isempty(info.maxOffset), info.maxOffset = NaN; end
info.identity  = (nL4 == nL2) && all(l4map == (1:nL2)');
end
