function [T, info] = vector_head_matrix(hdrFiles, vecFiles)
% VECTOR_HEAD_MATRIX  Head transformation matrix of a Nortek Vector, from the raw files.
%
%   [T, info] = vector_head_matrix(hdrFiles, vecFiles)
%
%   T maps beam velocities to the instrument XYZ frame, x = T*b (Nortek
%   convention; dimensionless). It is a property of the probe head, so every
%   file of one record must carry the same matrix. This reads it from two
%   independent places and refuses if they disagree:
%     - each ExploreV .hdr text file ("Transformation matrix", Head
%       configuration block, three rows of 4 decimals);
%     - the Head Configuration record (0xA5 0x04, 224 bytes) at the start of
%       the first raw binary (.VEC/.vec/.049): nine int16 at bytes 8..25 of the
%       176-byte System field, row-major, divided by 4096. The record is
%       accepted only if its Nortek checksum verifies.
%   0-byte .hdr files are skipped (some pre-2019 deployments ship them), and so
%   are placeholder heads (identity matrix, serial "VEC 0000"), counted in
%   info.nPlaceholder.
%
%   INPUTS  cellstr of paths (either may be empty, not both)
%   OUTPUT  T     3x3 double
%           info  struct: source ('hdr+vec'|'hdr'|'vec'), headSerial,
%                 nHdrRead, maxDiffHdr (max |T_i - T| over .hdr files),
%                 diffHdrVec (max |T_hdr - T_vec|), files used.
%
%   Agreement tolerance is 1e-4: the .hdr prints 4 decimals of k/4096, so
%   honest copies differ by at most 5e-5.
%
%   Added 2026-11-13 for the L1 beam-step correction
%   (docs/SPEC_L1_beam_step_correction_2026-11-13.md).

    if nargin < 2, vecFiles = {}; end
    if ischar(hdrFiles), hdrFiles = {hdrFiles}; end
    if ischar(vecFiles), vecFiles = {vecFiles}; end
    tol = 1e-4;

    info = struct('source', '', 'headSerial', '', 'nHdrRead', 0, 'nPlaceholder', 0, ...
        'maxDiffHdr', NaN, 'diffHdrVec', NaN, 'hdrFile', '', 'vecFile', '');
    % A PLACEHOLDER head (identity matrix and serial "VEC 0000") is written by
    % repair exports (TOR18A's *_rep files, 2026-11-13); it is not a head and
    % is skipped and counted, never used.
    isPlaceholder = @(T, ser) ~isempty(T) && max(abs(T(:) - reshape(eye(3), [], 1))) < 1e-4 && ...
        contains(strrep(ser, ' ', ''), 'VEC0000');

    % --- every .hdr
    Th = [];  serH = '';
    for i = 1:numel(hdrFiles)
        d = dir(hdrFiles{i});
        if isempty(d) || d.bytes == 0, continue; end
        [Ti, si] = parse_hdr(hdrFiles{i});
        if isempty(Ti), continue; end
        if isPlaceholder(Ti, si), info.nPlaceholder = info.nPlaceholder + 1; continue; end
        info.nHdrRead = info.nHdrRead + 1;
        if isempty(Th)
            Th = Ti;  serH = si;  info.hdrFile = hdrFiles{i};
            info.maxDiffHdr = 0;
        else
            dd = max(abs(Ti(:) - Th(:)));
            info.maxDiffHdr = max(info.maxDiffHdr, dd);
            if dd > tol
                error('vector_head_matrix:hdrDisagree', ...
                    'Head matrix differs by %.2e between %s and %s.', ...
                    dd, info.hdrFile, hdrFiles{i});
            end
        end
    end

    % --- first binary
    Tv = [];  serV = '';
    for i = 1:numel(vecFiles)                 % first binary with a real head
        [Tv, serV] = parse_vec(vecFiles{i});
        if isPlaceholder(Tv, serV), info.nPlaceholder = info.nPlaceholder + 1; Tv = []; continue; end
        if ~isempty(Tv), info.vecFile = vecFiles{i}; break; end
    end

    if isempty(Th) && isempty(Tv)
        error('vector_head_matrix:notFound', ...
            'No head transformation matrix in %d .hdr and %d binary file(s).', ...
            numel(hdrFiles), numel(vecFiles));
    elseif ~isempty(Th) && ~isempty(Tv)
        info.diffHdrVec = max(abs(Th(:) - Tv(:)));
        if info.diffHdrVec > tol
            error('vector_head_matrix:hdrVecDisagree', ...
                'Head matrix in %s and %s differ by %.2e.', ...
                info.hdrFile, info.vecFile, info.diffHdrVec);
        end
        T = Tv;  info.source = 'hdr+vec';  info.headSerial = serV;
    elseif ~isempty(Tv)
        T = Tv;  info.source = 'vec';  info.headSerial = serV;
    else
        T = Th;  info.source = 'hdr';  info.headSerial = serH;
    end

    if abs(det(T)) < 1e-3
        error('vector_head_matrix:singular', 'Head matrix is singular (det %.2e).', det(T));
    end
end

% ======================================================================
function [T, ser] = parse_hdr(f)
    T = [];  ser = '';
    txt = fileread(f);
    L = regexp(txt, '\r?\n', 'split');
    inHead = false;
    for i = 1:numel(L)
        if startsWith(strtrim(L{i}), 'Head configuration'), inHead = true; end
        if inHead && startsWith(L{i}, 'Serial number') && isempty(ser)
            ser = strtrim(extractAfter(L{i}, 'Serial number'));
        end
        if startsWith(L{i}, 'Transformation matrix')
            r1 = sscanf(extractAfter(L{i}, 'Transformation matrix'), '%f')';
            r2 = sscanf(L{i+1}, '%f')';
            r3 = sscanf(L{i+2}, '%f')';
            if numel(r1) == 3 && numel(r2) == 3 && numel(r3) == 3
                T = [r1; r2; r3];
            end
            return
        end
    end
end

% ======================================================================
function [T, ser] = parse_vec(f)
    T = [];  ser = '';
    fid = fopen(f, 'r');
    if fid < 0, return; end
    b = fread(fid, 8192, 'uint8=>uint8');
    fclose(fid);
    b = double(b(:));
    cand = find(b(1:end-1) == 165 & b(2:end) == 4);
    for q = cand'
        if q + 223 > numel(b), break; end
        if b(q+2) + 256*b(q+3) ~= 112, continue; end      % size in words
        w = b(q:2:q+221) + 256*b(q+1:2:q+222);
        cs = mod(hex2dec('B58C') + sum(w), 65536);
        if cs ~= b(q+222) + 256*b(q+223), continue; end
        v = zeros(1, 9);
        for k = 1:9
            p = q + 22 + 8 + 2*(k-1);
            v(k) = b(p) + 256*b(p+1);
            if v(k) > 32767, v(k) = v(k) - 65536; end
        end
        T = reshape(v, 3, 3).' / 4096;
        s = b(q+10:q+21)';
        s = s(1:find([s < 32 | s > 126, true], 1) - 1);
        ser = strtrim(char(s));
        return
    end
end
