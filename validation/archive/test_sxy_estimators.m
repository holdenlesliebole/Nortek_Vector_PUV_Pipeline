% Synthetic closure test for the alongshore metric replacement.
%
% Ground truth: y = B*x + noise, with B KNOWN. A good metric recovers B
% regardless of how one-signed x is. The derivation predicts:
%   Var(b_free)/Var(b0) = 1 + xbar^2/var(x)
% so as the record becomes more unidirectional (xbar/sd rising), the
% free-intercept slope and the correlation degrade while b0 does not.
%
% If b0 degrades too, the proposed fix is wrong and this stops here.

rng(7);
B      = 1.20;          % known multiplicative bias to recover
n      = 500;           % segments per record, realistic
nTrial = 2000;
sd     = 1;             % sd of x held FIXED; only the mean moves
snr    = 0.30;          % noise sd as a fraction of sd(x)

ratios = [0 0.5 1 2 3 5 8];   % xbar/sd -- degree of one-sidedness

fprintf('\n  B = %.2f, n = %d, noise sd = %.2f*sd(x), %d trials\n\n', B, n, snr, nTrial);
fprintf('  %6s %8s | %-22s | %-22s | %-16s\n', 'xbar/sd','|net|/gr', ...
        'b0 (through origin)','b (free intercept)','R');
fprintf('  %6s %8s | %8s %8s %5s | %8s %8s %5s | %8s %8s\n', '','', ...
        'mean','sd','bias','mean','sd','bias','mean','sd');

for r = ratios
    mu = r*sd;
    b0 = zeros(nTrial,1); bf = zeros(nTrial,1); RR = zeros(nTrial,1); ng = zeros(nTrial,1);
    for t = 1:nTrial
        x = mu + sd*randn(n,1);
        y = B*x + snr*sd*randn(n,1);
        b0(t) = sum(x.*y)/sum(x.^2);
        p = polyfit(x,y,1); bf(t) = p(1);
        cc = corrcoef(x,y); RR(t) = cc(1,2);
        ng(t) = abs(sum(x))/sum(abs(x));      % |net|/gross, as in the sweep
    end
    fprintf('  %6.1f %8.3f | %8.4f %8.4f %+5.1f%% | %8.4f %8.4f %+5.1f%% | %8.4f %8.4f\n', ...
        r, mean(ng), mean(b0), std(b0), 100*(mean(b0)/B-1), ...
        mean(bf), std(bf), 100*(mean(bf)/B-1), mean(RR), std(RR));
end

% Does the predicted variance ratio hold?
fprintf('\n  predicted Var(b)/Var(b0) = 1 + (xbar/sd)^2 :\n');
fprintf('  %6s %12s %12s\n','xbar/sd','predicted','observed');
for r = ratios
    mu = r*sd; b0 = zeros(nTrial,1); bf = zeros(nTrial,1);
    for t = 1:nTrial
        x = mu + sd*randn(n,1); y = B*x + snr*sd*randn(n,1);
        b0(t) = sum(x.*y)/sum(x.^2);
        p = polyfit(x,y,1); bf(t) = p(1);
    end
    fprintf('  %6.1f %12.2f %12.2f\n', r, 1+r^2, var(bf)/var(b0));
end

% SIGN/HANDEDNESS: the frame gate. Flip the frame (B < 0) and check that each
% statistic catches it on a strongly one-signed record, which is where the
% correlation was failing.
fprintf('\n  handedness detection on a one-signed record (xbar/sd = 5):\n');
mu = 5*sd; nBadR = 0; nBad0 = 0;
for t = 1:nTrial
    x = mu + sd*randn(n,1);
    y = -B*x + snr*sd*randn(n,1);        % frame IS flipped; truth = "not ok"
    if sum(x.*y)/sum(x.^2) > 0, nBad0 = nBad0+1; end
    cc = corrcoef(x,y); if cc(1,2) > 0, nBadR = nBadR+1; end
end
fprintf('    missed flips: b0 %d/%d, R %d/%d\n', nBad0, nTrial, nBadR, nTrial);

% And the converse -- the case that actually bit us: frame is CORRECT but the
% record is one-signed and noisy. How often does each statistic FALSELY
% condemn it?
fprintf('\n  false alarms, frame correct but record one-signed + noisy:\n');
for s = [0.3 1.0 3.0]
    for r = [0.5 3 8]
        mu = r*sd; fa0 = 0; faR = 0;
        for t = 1:500
            x = mu + sd*randn(n,1); y = B*x + s*sd*randn(n,1);
            if sum(x.*y)/sum(x.^2) <= 0, fa0 = fa0+1; end
            cc = corrcoef(x,y); if cc(1,2) <= 0, faR = faR+1; end
        end
        fprintf('    noise %.1f*sd, xbar/sd %3.1f : b0 %3d/500, R %3d/500\n', s, r, fa0, faR);
    end
end
