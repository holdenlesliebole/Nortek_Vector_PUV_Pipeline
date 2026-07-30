% ANALYZE_COR16B_TIMERESOLVED  Is COR16B's beta = 0.63 an episode or a
% steady state?  (PUV_paper todo #61, part 2)
%
% Splits each record's valid segments into NCHUNK contiguous chunks, runs
% the ACTUAL PUV_L4_bispectra on each chunk (same defaults as production),
% recovers each chunk's P_mean via recover_P_from_bispectrum, and computes
% the chunk's sea-swell-restricted beta with bound_energy_from_bispectrum.
% COR17D is run identically as the co-sited control.
%
% Interpretation, pre-stated:
%   - beta ~ flat across chunks and high only for COR16B -> steady state;
%     points at real (or persistently artifactual) record-level coupling.
%   - beta dominated by one or two chunks -> an episode; check those
%     chunks' dates against deployment logs / storms / instrument events.
%   - per-chunk Hs medians are reported so a storm episode is
%     distinguishable from an instrument episode by covariance with forcing.
%
% Cost: one bispectrum pass per record (~2.3 s/segment; ~50 min for the
% two records). Chunks partition the valid segments, so total cost equals
% one full-record pass each.
%
% Output: outputs/validation/cor16b_timeresolved.mat
% Run from PUV_Pipeline/:  >> run validation/analyze_cor16b_timeresolved
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
t0 = tic;

BAND = [0.12 0.20]; F1MIN = 0.04;
NCHUNK = 8;
RECS = {'COR16B', 'MOP158_9m'; 'COR17D', 'MOP158_9m'};

OUT = struct('rec', {}, 'chunk', {}, 't0', {}, 't1', {}, 'nSeg', {}, ...
    'beta_ss', {}, 'beta_net', {}, 'noise_ss', {}, 'biphase_ss', {}, ...
    'Hs_med', {}, 'closure', {});

for r = 1:size(RECS,1)
    dep = RECS{r,1}; lab = RECS{r,2};
    S4 = load(fullfile(root, 'L4', dep, [lab '_L4.mat']), 'L4');
    S2 = load(fullfile(root, 'L2', dep, [lab '_L2.mat']), 'L2');
    L2 = S2.L2;
    eta = S4.L4.eta.eta_total;

    % Valid = the same criterion PUV_L4_bispectra applies internally
    useSeg = logical(L2.segValid(:)) & ~any(isnan(eta), 1).';
    idx    = find(useSeg);
    nUse   = numel(idx);
    edges  = round(linspace(0, nUse, NCHUNK + 1));

    fprintf('%s/%s: %d valid segments -> %d chunks\n', dep, lab, nUse, NCHUNK);

    for c = 1:NCHUNK
        pick = idx(edges(c)+1 : edges(c+1));
        if numel(pick) < 10, continue; end

        L2c = struct();
        L2c.time     = L2.time;
        L2c.segValid = false(numel(L2.time), 1);
        L2c.segValid(pick) = true;
        L2c.params.segLen  = L2.params.segLen;
        L2c.fs = L2.fs;

        L4c = PUV_L4_bispectra(eta, L2c, struct('useParallel', false));

        B   = L4c.B_mean;  Bic = L4c.Bic_mean;  fG = L4c.f(:);
        nf  = numel(fG);
        [P, ~] = recover_P_from_bispectrum(B, Bic, nf);

        % closure check on the chunk (can fail; report it)
        [I1, I2] = meshgrid(1:nf, 1:nf);
        K3 = I1 + I2 - 1;
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

        o = struct('rec', [dep '/' lab], 'chunk', c, ...
            't0', L2.time(pick(1)), 't1', L2.time(pick(end)), ...
            'nSeg', numel(pick), 'beta_ss', bSS, 'beta_net', bSS - bIm, ...
            'noise_ss', bIm, 'biphase_ss', angle(wsum), ...
            'Hs_med', median(L2.Hs(pick), 'omitnan'), 'closure', closure);
        OUT(end+1) = o; %#ok<SAGROW>

        fprintf('  chunk %d  %s - %s  n=%3d  beta_ss=%6.3f (net %6.3f, noise %6.3f)  biph=%+6.3f  Hs=%.2f  closure=%.1e\n', ...
            c, string(o.t0, 'yyyy-MM-dd'), string(o.t1, 'yyyy-MM-dd'), ...
            o.nSeg, bSS, o.beta_net, bIm, o.biphase_ss, o.Hs_med, closure);
    end
end

meta = struct('created', datetime('now'), 'band', BAND, 'nChunk', NCHUNK, ...
    'elapsed_min', toc(t0)/60, ...
    'note', 'Per-chunk SS-restricted bispectral beta for the two co-sited Coronado records (todo #61).');
save(fullfile(root, 'validation', 'cor16b_timeresolved.mat'), 'OUT', 'meta');
fprintf('\nsaved outputs/validation/cor16b_timeresolved.mat (%.1f min)\n', meta.elapsed_min);
