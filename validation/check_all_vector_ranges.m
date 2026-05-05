function T = check_all_vector_ranges(opts)
% CHECK_ALL_VECTOR_RANGES  Tabulate Nominal velocity range setting for
% every Vector across all deployments by parsing the first .hdr file in
% each instrument's raw folder.
%
%   T = check_all_vector_ranges()
%
% Output: table with one row per instrument: deployment, label, range_mps,
% sampling_Hz, coord_system. Saved to outputs/validation/mean_flow/_aggregate/
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
aggDir = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate');
if ~exist(aggDir,'dir'), mkdir(aggDir); end

reg = deployment_registry();
deployments = keys(reg);

rows = struct('deployment',{},'label',{},'rawSubfolder',{},'range_mps',{}, ...
              'fs_Hz',{},'coord',{},'hdrFound',{});
nMissing = 0;

for iD = 1:numel(deployments)
    dep = deployments{iD};
    try
        configFn = reg(dep);
        cfg = configFn();
    catch
        continue
    end
    if ~isfield(cfg, 'rawDataRoot') || ~isfolder(cfg.rawDataRoot)
        % Note: server may be unmounted; record but mark missing
        rawRoot = '';
    else
        rawRoot = cfg.rawDataRoot;
    end
    for iI = 1:numel(cfg.instruments)
        instr = cfg.instruments(iI);
        row = struct('deployment',dep,'label',instr.label, ...
                     'rawSubfolder', getf(instr,'rawSubfolder',''), ...
                     'range_mps',NaN,'fs_Hz',NaN,'coord','', 'hdrFound', false);
        if ~isempty(rawRoot)
            % Use rawSubfolder if specified; otherwise scan rawDataRoot itself
            if ~isempty(row.rawSubfolder)
                instrDir = fullfile(rawRoot, row.rawSubfolder);
            else
                instrDir = rawRoot;
            end
            if isfolder(instrDir)
                % Prefer .hdr that matches filePrefix when available
                if isfield(instr,'filePrefix') && ~isempty(instr.filePrefix)
                    hdrs = dir(fullfile(instrDir, [instr.filePrefix '*.hdr']));
                else
                    hdrs = [];
                end
                if isempty(hdrs)
                    hdrs = dir(fullfile(instrDir, '*.hdr'));
                end
                if ~isempty(hdrs)
                    [~, ord] = sort({hdrs.name});
                    hdr = fullfile(instrDir, hdrs(ord(1)).name);
                    [row.range_mps, row.fs_Hz, row.coord] = parse_hdr(hdr);
                    row.hdrFound = true;
                end
            end
        end
        if ~row.hdrFound, nMissing = nMissing + 1; end
        rows(end+1) = row; %#ok<AGROW>
    end
end

T = struct2table(rows);

% Print summary
fprintf('\n=== Nominal Velocity Range tabulation ===\n');
fprintf('Total instruments: %d   |   .hdr parsed: %d   |   missing: %d\n', ...
    height(T), sum([rows.hdrFound]), nMissing);

if any([rows.hdrFound])
    parsed = T(T.hdrFound, :);
    [u, ~, ix] = unique(parsed.range_mps);
    fprintf('\nRange settings observed:\n');
    for k = 1:numel(u)
        fprintf('   %.2f m/s : %d instruments\n', u(k), sum(ix == k));
    end
    if numel(u) == 1
        fprintf('\n  → All parsed instruments use the same range setting.\n');
    end
    % List any non-4 m/s instruments
    nonStd = parsed(parsed.range_mps ~= 4.0, :);
    if ~isempty(nonStd)
        fprintf('\n  Non-4 m/s instruments:\n');
        disp(nonStd);
    end
end

% List any missing
miss = T(~T.hdrFound, :);
if ~isempty(miss)
    fprintf('\nUnparsed (server unmounted or .hdr missing):\n');
    for k = 1:height(miss)
        fprintf('   %s / %s\n', miss.deployment{k}, miss.label{k});
    end
end

writetable(T, fullfile(aggDir, 'vector_range_settings.csv'));
save(fullfile(aggDir, 'vector_range_settings.mat'), 'T');
fprintf('\nSaved: %s\n', fullfile(aggDir, 'vector_range_settings.csv'));
end


function v = getf(s, fname, default)
if isfield(s, fname) && ~isempty(s.(fname)), v = s.(fname); else, v = default; end
end


function [range_mps, fs_Hz, coord] = parse_hdr(hdrFile)
range_mps = NaN; fs_Hz = NaN; coord = '';
fid = fopen(hdrFile, 'r');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid));
while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line), break; end
    tok = regexp(line, 'Nominal velocity range\s+([\d.]+)\s*m/s', 'tokens', 'once');
    if ~isempty(tok), range_mps = str2double(tok{1}); end
    tok = regexp(line, 'Sampling rate\s+([\d.]+)\s*Hz', 'tokens', 'once');
    if ~isempty(tok), fs_Hz = str2double(tok{1}); end
    tok = regexp(line, 'Coordinate system\s+(\S+)', 'tokens', 'once');
    if ~isempty(tok), coord = tok{1}; end
end
end
