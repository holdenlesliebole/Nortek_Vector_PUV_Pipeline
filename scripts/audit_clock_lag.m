% AUDIT_CLOCK_LAG  Independent check that every clock-recovered record now sits
% at zero lag against the NOAA tidal reference.
%
%   This is the check `vec_clock_from_filenames.m` asks for in its own header
%   and never got: the filename clock tells you what the recorder was SET to,
%   not whether that setting was UTC or local. Cross-correlating L2 depth
%   against the L3 tidal prediction resolves it.
%
%   Run AFTER the clock fix. Every clockSource='filename' record must report
%   lag 0. A nonzero lag means the offset is still wrong.
%
%   Author: Holden Leslie-Bole, 2026

startup_puv
root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';
reg  = deployment_registry();

% Enumerate from the registry rather than hardcoding: a hardcoded list is how
% TOR18A went unchecked. Every record whose clock was reconstructed from
% filenames belongs in this audit, whatever its offset.
REC = {};
allNames = sort(keys(reg));
seenDep  = containers.Map('KeyType','char','ValueType','logical');
for i = 1:numel(allNames)
    try, fn = reg(allNames{i}); cfg = fn(); catch, continue, end
    if isKey(seenDep, cfg.name), continue, end
    seenDep(cfg.name) = true;
    in = cfg.instruments(1);
    if isfield(in,'clockSource') && strcmpi(in.clockSource,'filename')
        REC{end+1} = cfg.name; %#ok<SAGROW>
    end
end
REC = sort(REC);

fprintf('\n%-8s %-8s %-7s %-6s %-7s  %s\n','deploy','offset','bestLag','R@lag','R@0','verdict');
fprintf('%s\n', repmat('-',1,62));
nPass = 0; nFail = 0;
for i = 1:numel(REC)
    dep = REC{i};
    try, fn = reg(dep); cfg = fn(); catch, fprintf('%-8s  (not registered)\n',dep); continue, end
    lab = cfg.instruments(1).label;
    off = 0;
    if isfield(cfg.instruments(1),'clockOffsetHours') && ~isempty(cfg.instruments(1).clockOffsetHours)
        off = cfg.instruments(1).clockOffsetHours;
    end
    f2 = fullfile(root,'L2',dep,[lab '_L2.mat']);
    f3 = fullfile(root,'L3',dep,[lab '_L3.mat']);
    if ~isfile(f2) || ~isfile(f3), fprintf('%-8s  (missing L2/L3)\n',dep); continue, end
    L2 = getfield(load(f2,'L2'),'L2'); %#ok<GFLD>
    L3 = getfield(load(f3,'L3'),'L3'); %#ok<GFLD>
    if ~isfield(L3,'tidal') || ~isfield(L3.tidal,'depth_pred')
        fprintf('%-8s  (no tidal)\n',dep); continue
    end
    d = L2.depth(:); pr = L3.tidal.depth_pred(:); sv = logical(L2.segValid(:));
    m = sv & isfinite(d) & isfinite(pr);
    if sum(m) < 200, fprintf('%-8s  (only %d segments)\n',dep,sum(m)); continue, end
    a = d; b = pr; a(~m) = NaN; b(~m) = NaN;
    a = a - mean(a,'omitnan'); b = b - mean(b,'omitnan');
    a(isnan(a)) = 0; b(isnan(b)) = 0;
    bl = 0; br = -2; r0 = NaN;
    for L = -14:14
        x = circshift(b,L); s = dot(a,x)/(norm(a)*norm(x)+eps);
        if L == 0, r0 = s; end
        if s > br, br = s; bl = L; end
    end
    pass = (bl == 0) && (br > 0.7);
    if pass, nPass = nPass + 1; v = 'PASS'; else, nFail = nFail + 1; v = '*** FAIL ***'; end
    fprintf('%-8s %+-8g %+-7d %-6.3f %-7.3f  %s\n', dep, off, bl, br, r0, v);
end
fprintf('\n%d pass, %d fail\n', nPass, nFail);
