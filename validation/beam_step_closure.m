function R = beam_step_closure(Xbase, validBase, fs, Ttrue, inj, corrOpts, Tcorr, label)
% BEAM_STEP_CLOSURE  Inject known beam steps into a clean series, correct, score.
%
%   R = beam_step_closure(Xbase, validBase, fs, Ttrue, inj, corrOpts, Tcorr, label)
%
%   Synthetic closure test for vector_beam_step_correct (spec
%   docs/SPEC_L1_beam_step_correction_2026-11-13.md, test T2). Steps are
%   injected in beam space with the TRUE head matrix Ttrue (x += Ttrue*k*Dinj);
%   the corrector is given Tcorr (= Ttrue unless a break test swaps it).
%
%   Xbase     N x 3 recorded-frame velocity (m/s), clean (no steps)
%   validBase N x 1 logical
%   inj       struct of counts and settings (defaults = spec T2):
%             .nS1 200 single |k|=1     .nS2 50 double |k|=2
%             .nS3 30 two-beam (+1,-1)  .nS4 40 runs 2-11 samples
%             .nS5 10 runs 12-30        .nS6 60 single, gap 1-4 one/both sides
%             .nS7 30 single, gap 5-20 one side
%             .Dinj 1.508 m/s  .spacing 200 samples  .seed 20261113
%             .Xscale 1 (multiplies Xbase before injecting; T3 stress test)
%   corrOpts  options for vector_beam_step_correct (e.g. .Delta)
%
%   R: per-category n/n exact, false flags, wrong corrections, bitwise check of
%   untouched samples, max |x' - x_clean| over injected samples, Delta used,
%   status, per-injection outcome for S7, and pass flags for criteria T2a.
%
%   Added 2026-11-13.

    if nargin < 8, label = ''; end
    d = struct('nS1',200,'nS2',50,'nS3',30,'nS4',40,'nS5',10,'nS6',60,'nS7',30, ...
        'Dinj',1.508,'spacing',200,'seed',20261113,'Xscale',1);
    f = fieldnames(d);
    for i = 1:numel(f), if ~isfield(inj,f{i}), inj.(f{i}) = d.(f{i}); end, end
    rng(inj.seed);

    N = size(Xbase, 1);
    X0 = Xbase * inj.Xscale;
    valid = logical(validBase(:)) & all(isfinite(X0), 2);

    % ---- sites: neighborhood [p-25, p+60] fully valid, sites >= spacing apart
    ok = movmin(double(valid), [25 60]) == 1;
    ok([1:30, N-65:N]) = false;
    cand = find(ok);
    cand = cand(randperm(numel(cand)));
    sites = zeros(0,1);
    taken = false(N,1);
    nTot = inj.nS1+inj.nS2+inj.nS3+inj.nS4+inj.nS5+inj.nS6+inj.nS7;
    for c = cand.'
        if numel(sites) == nTot, break; end
        if ~taken(c)
            sites(end+1,1) = c; %#ok<AGROW>
            taken(max(1,c-inj.spacing):min(N,c+inj.spacing)) = true;
        end
    end
    if numel(sites) < nTot
        error('beam_step_closure:noRoom', '%s: room for %d of %d sites.', label, numel(sites), nTot);
    end

    cats = [repmat(1,inj.nS1,1); repmat(2,inj.nS2,1); repmat(3,inj.nS3,1); repmat(4,inj.nS4,1); ...
            repmat(5,inj.nS5,1); repmat(6,inj.nS6,1); repmat(7,inj.nS7,1)];
    Kexp = zeros(N, 3);
    rowsOf = cell(nTot, 1);
    for q = 1:nTot
        p = sites(q);
        kv = zeros(1,3);
        switch cats(q)
            case {1,4,5,6,7}, kv(randi(3)) = 2*randi(2)-3;
            case 2,           kv(randi(3)) = 2*(2*randi(2)-3);
            case 3,           bb = randperm(3, 2); kv(bb) = [1 -1];
        end
        switch cats(q)
            case 4, L = randi([2 11]);
            case 5, L = randi([12 30]);
            otherwise, L = 1;
        end
        rows = (p:p+L-1).';
        Kexp(rows, :) = repmat(kv, L, 1);
        rowsOf{q} = rows;
        if cats(q) == 6
            mode = randi(3);   % 1 before, 2 after, 3 both
            if mode ~= 2, valid(p-randi(4):p-1) = false; end
            if mode ~= 1, valid(p+L:p+L-1+randi(4)) = false; end
        elseif cats(q) == 7
            g = randi([5 20]);
            if randi(2) == 1, valid(p-g:p-1) = false; else, valid(p+L:p+L-1+g) = false; end
        end
    end
    inject = any(Kexp ~= 0, 2);
    Xinj = X0;
    Xinj(inject, :) = X0(inject, :) + (Ttrue * (Kexp(inject, :).' * inj.Dinj)).';

    [Xc, bs] = vector_beam_step_correct(Xinj, valid, fs, Tcorr, corrOpts);

    % ---- score
    K = double(bs.k);
    R = struct('label', label, 'status', bs.status, 'Delta', bs.Delta, ...
        'nDeltaEdges', bs.nDeltaEdges, 'counts', bs.counts);
    names = {'S1 single','S2 double','S3 two-beam','S4 run 2-11','S5 run 12-30', ...
             'S6 gap 1-4','S7 gap 5-20'};
    R.cat = struct('name', names, 'n', 0, 'exact', 0, 'unconfirmed', 0, 'wrong', 0, 'missed', 0);
    R.missedSites = zeros(0, 3);   % [first row, length, category] of silent misses
    R.Xinj = Xinj;  R.validInj = valid;  R.Kexp = Kexp;
    for q = 1:nTot
        rows = rowsOf{q};  c = cats(q);
        R.cat(c).n = R.cat(c).n + 1;
        if isequal(K(rows,:), Kexp(rows,:))
            R.cat(c).exact = R.cat(c).exact + 1;
        elseif any(K(rows,:) ~= 0, 'all')
            R.cat(c).wrong = R.cat(c).wrong + 1;
        elseif all(bs.unconfirmed(rows))
            R.cat(c).unconfirmed = R.cat(c).unconfirmed + 1;
        else
            R.cat(c).missed = R.cat(c).missed + 1;
            R.missedSites(end+1, :) = [rows(1), numel(rows), c]; %#ok<AGROW>
        end
    end
    flagged = any(K ~= 0, 2);
    R.nFalseFlagSamples = sum(flagged & ~inject);
    R.nWrongSamples = sum(any(K ~= Kexp, 2) & flagged);
    untouched = ~flagged & ~inject;
    R.untouchedBitwise = isequal(Xc(untouched,:), X0(untouched,:));
    nanEq = isnan(Xc(untouched,:)) & isnan(X0(untouched,:));
    if ~R.untouchedBitwise
        dd = Xc(untouched,:) ~= X0(untouched,:) & ~nanEq;
        R.untouchedBitwise = ~any(dd(:));
    end
    err = abs(Xc(inject,:) - X0(inject,:));
    R.maxErr = max(err(:));
    R.colNormMax = max(vecnorm(Ttrue));
    R.Dinj = inj.Dinj;
    allExact = all([R.cat.exact] == [R.cat.n]);
    R.pass_T2a = allExact && R.nFalseFlagSamples == 0 && R.untouchedBitwise && R.maxErr <= 1e-3;
    exS7 = all([R.cat(1:6).exact] == [R.cat(1:6).n]);
    R.pass_T2a_stormS7exception = exS7 && R.cat(7).wrong == 0 && R.cat(7).missed == 0 && ...
        R.nFalseFlagSamples == 0 && R.untouchedBitwise && ...
        max(abs(Xc(inject & flagged,:) - X0(inject & flagged,:)), [], 'all') <= 1e-3;
    R.pass_T2b = allExact && R.nFalseFlagSamples == 0 && R.untouchedBitwise && ...
        abs(bs.Delta - inj.Dinj) <= 0.010 && ...
        all(max(err, [], 2) <= sum(abs(Kexp(inject,:)), 2) * abs(bs.Delta - inj.Dinj) * R.colNormMax + 1e-9);
end
