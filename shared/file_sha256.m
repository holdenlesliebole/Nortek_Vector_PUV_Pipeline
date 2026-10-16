function h = file_sha256(path)
% FILE_SHA256  SHA-256 of a file's bytes, as 64 lowercase hex characters.
%
%   h = file_sha256(path)
%
% Uses the system `shasum -a 256` (macOS, Linux) when available, which reads at
% disk speed; falls back to Java's MessageDigest otherwise. Errors if the file
% does not exist, never returns an empty or partial hash.
%
% Author: Holden Leslie-Bole, 2026

    if ~isfile(path), error('file_sha256:noFile', 'No such file: %s', path); end
    [st, out] = system(sprintf('shasum -a 256 "%s" 2>/dev/null', strrep(path, '"', '\"')));
    tok = regexp(out, '^([0-9a-f]{64})\s', 'tokens', 'once');
    if st == 0 && ~isempty(tok)
        h = tok{1};
        return
    end
    md  = java.security.MessageDigest.getInstance('SHA-256');
    fid = fopen(path, 'r'); c = onCleanup(@() fclose(fid));
    while true
        b = fread(fid, 2^24, '*int8');
        if isempty(b), break, end
        md.update(b);
    end
    d = typecast(md.digest(), 'uint8');
    h = lower(reshape(dec2hex(d, 2).', 1, []));
end
