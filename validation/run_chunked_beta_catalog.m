% RUN_CHUNKED_BETA_CATALOG  Catalog-wide per-chunk bispectral beta (todo #62).
%
% Removes the storm-weighting bias from the record-level beta
% (findings_cor16b_2026-07-30.md): B_mean weights hours as amplitude^3
% against P_mean's amplitude^2, so record-level beta is storm-tilted and can
% exceed every per-period value at extreme dynamic range. This driver chunks
% every record's valid segments into contiguous blocks of ~CHUNK segments,
% recomputes the bispectrum per chunk through the ACTUAL PUV_L4_bispectra
% (production defaults), and saves per-chunk sea-swell-restricted beta with
% per-chunk forcing (Hs, Hs/h) — yielding beta(Hs/h), the bound-fraction
% counterpart of the paper's threshold hierarchy, and a matched-weighting x
% for the beta-excess regression.
%
% SHARDING (no Parallel Computing Toolbox needed): set env BETA_SHARD="k/N"
% and launch N MATLAB processes; records are dealt round-robin. Each shard
% writes outputs/validation/chunked_beta_shard_<k>of<N>.mat, saving after
% every record (resumable: records already in the shard file are skipped).
% Merge afterwards with validation/assemble_chunked_beta.m.
%
% Cost: ~2.3 s/segment; the catalog is ~77k valid segments, so ~8 h wall on
% 6 shards.
%
% Chunk floor: 60 segments -> Im-measured noise floor ~1% of band power
% (measured on the COR16B/COR17D chunks), against chunk beta 0.02-0.4.
% Trailing chunks < 30 segments are merged into the previous chunk.
%
% Run:  BETA_SHARD="1/6" matlab -batch "run('validation/run_chunked_beta_catalog.m')"
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0all = tic;

BAND = [0.12 0.20]; F1MIN = 0.04; CHUNK = 60; MINCHUNK = 30;

shardStr = getenv('BETA_SHARD');
if isempty(shardStr), shardStr = '1/1'; end
tok = sscanf(shardStr, '%d/%d');
kSh = tok(1); nSh = tok(2);
outFile = fullfile(root, 'validation', sprintf('chunked_beta_shard_%dof%d.mat', kSh, nSh));

% resumable: load what this shard already has
OUT = struct('rec', {}, 'chunk', {}, 't0', {}, 't1', {}, 'nSeg', {}, ...
    'beta_ss', {}, 'beta_net', {}, 'noise_ss', {}, 'biphase_ss', {}, ...
    'Hs_med', {}, 'hsh_med', {}, 'closure', {});
doneRecs = {};
if isfile(outFile)
    prev = load(outFile);
    OUT = prev.OUT;
    doneRecs = unique({OUT.rec});
    fprintf('[shard %d/%d] resuming: %d records already done\n', kSh, nSh, numel(doneRecs));
end

reg   = deployment_registry();
names = sort(keys(reg));
seen  = containers.Map('KeyType','char','ValueType','logical');

% deterministic record list, then round-robin deal
recList = {};
for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;
    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        recList(end+1,:) = {cfg.name, erase(fl(k).name, '_L2.mat')}; %#ok<SAGROW>
    end
end

for iRec = 1:size(recList,1)
    if mod(iRec - 1, nSh) + 1 ~= kSh, continue; end
    dep = recList{iRec,1}; lab = recList{iRec,2};
    rec = [dep '/' lab];
    if any(strcmp(doneRecs, rec)), continue; end

    f4 = fullfile(root, 'L4', dep, [lab '_L4.mat']);
    if ~isfile(f4), fprintf('[skip] %s: no L4\n', rec); continue; end

    tRec = tic;
    try
        eta = h5read(f4, '/L4/eta/eta_total');
    catch
        S4 = load(f4, 'L4'); eta = S4.L4.eta.eta_total;
    end
    S2 = load(fullfile(root, 'L2', dep, [lab '_L2.mat']), 'L2');
    L2 = S2.L2;

    useSeg = logical(L2.segValid(:)) & ~any(isnan(eta), 1).';
    idx    = find(useSeg);
    nUse   = numel(idx);
    if nUse < MINCHUNK
        fprintf('[skip] %s: only %d valid segments\n', rec, nUse);
        continue
    end

    nCh    = max(1, floor(nUse / CHUNK));
    edges  = round(linspace(0, nUse, nCh + 1));

    for c = 1:nCh
        pick = idx(edges(c)+1 : edges(c+1));
        if numel(pick) < MINCHUNK, continue; end

        L2c = struct('time', L2.time, 'segValid', false(numel(L2.time),1), ...
            'params', struct('segLen', L2.params.segLen), 'fs', L2.fs);
        L2c.segValid(pick) = true;

        L4c = PUV_L4_bispectra(eta, L2c, struct());
        B   = L4c.B_mean;  Bic = L4c.Bic_mean;  fG = L4c.f(:);
        nf  = numel(fG);
        P   = recover_P_from_bispectrum(B, Bic, nf);

        [I1, I2] = meshgrid(1:nf, 1:nf);
        K3  = I1 + I2 - 1;
        chk = K3 <= nf & isfinite(Bic) & Bic > 0;
        BicR = abs(B(chk)) ./ sqrt(P(I1(chk)).*P(I2(chk)).*P(K3(chk)));
        closure = max(abs(BicR - Bic(chk)));

        oSS  = struct('minF1', F1MIN);
        Eb   = bound_energy_from_bispectrum(B, P, fG, oSS);
        EbIm = bound_energy_from_bispectrum(-1i*B, P, fG, oSS);
        inB  = fG >= BAND(1) & fG <= BAND(2);
        bSS  = sum(Eb(inB))   / sum(P(inB));
        bIm  = sum(EbIm(inB)) / sum(P(inB));

        wsum = 0;
        for i3 = find(inB(:))'
            for i1 = 2:floor((i3+1)/2)
                i2 = i3 + 1 - i1;
                if fG(i1) < F1MIN, continue; end
                ww = real(B(i1,i2))^2 / (P(i1)*P(i2));
                wsum = wsum + ww * B(i1,i2)/abs(B(i1,i2));
            end
        end

        OUT(end+1) = struct('rec', rec, 'chunk', c, ...
            't0', L2.time(pick(1)), 't1', L2.time(pick(end)), ...
            'nSeg', numel(pick), 'beta_ss', bSS, 'beta_net', bSS - bIm, ...
            'noise_ss', bIm, 'biphase_ss', angle(wsum), ...
            'Hs_med', median(L2.Hs(pick), 'omitnan'), ...
            'hsh_med', median(L2.Hs(pick) ./ L2.depth(pick), 'omitnan'), ...
            'closure', closure); %#ok<SAGROW>
    end

    meta = struct('created', datetime('now'), 'band', BAND, 'chunk', CHUNK, ...
        'shard', shardStr, 'note', 'Per-chunk SS-restricted bispectral beta (todo #62).');
    save(outFile, 'OUT', 'meta');
    fprintf('[shard %d/%d] %-22s %d chunks (%d segs) in %.1f min | total %.1f min\n', ...
        kSh, nSh, rec, nCh, nUse, toc(tRec)/60, toc(t0all)/60);
end

fprintf('[shard %d/%d] DONE: %d chunk rows, %.1f min\n', kSh, nSh, numel(OUT), toc(t0all)/60);
