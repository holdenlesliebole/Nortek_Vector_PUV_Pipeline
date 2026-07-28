% Second synthetic test, correcting the design of the first.
%
% The first test varied xbar/sd by raising the MEAN at fixed sd(x). R is
% scale-invariant in x, so R could not move and the test was blind to the
% pathology it was meant to probe.
%
% The physical model: model-vs-observation error scales with the MAGNITUDE of
% Sxy (a fractional error on the flux), not with its hour-to-hour variability.
% A unidirectional record has small sd(x) but the same mean|x|, so noise/sd(x)
% blows up there while noise/mean|x| does not. Ground truth is still y = B*x
% plus that noise, with B = 1.20 known, and the frame is CORRECT throughout --
% so every negative R below is a FALSE alarm by construction.
rng(11);
B = 1.20; n = 500; nTrial = 800; err = 0.35;   % noise sd = 0.35 * mean|x|

fprintf('\n  noise sd = %.2f * mean|x|;  frame is CORRECT in every case\n\n', err);
fprintf('  %8s %9s | %8s %8s | %8s %8s | %8s %8s\n', ...
        'sd/mean','|net|/gr','b0','sd(b0)','R','sd(R)','R<0 %','b0<0 %');
NG = []; MR = []; MB = [];
for sdr = [3 2 1.2 0.8 0.5 0.3 0.15 0.07]
    mu = 1; sd = sdr*mu;
    b0 = zeros(nTrial,1); RR = zeros(nTrial,1); ng = zeros(nTrial,1);
    for t = 1:nTrial
        x = mu + sd*randn(n,1);
        y = B*x + err*mean(abs(x))*randn(n,1);
        b0(t) = sum(x.*y)/sum(x.^2);
        cc = corrcoef(x,y); RR(t) = cc(1,2);
        ng(t) = abs(sum(x))/sum(abs(x));
    end
    fprintf('  %8.2f %9.3f | %8.4f %8.4f | %+8.3f %8.3f | %7.1f%% %7.1f%%\n', ...
        sdr, mean(ng), mean(b0), std(b0), mean(RR), std(RR), ...
        100*mean(RR<0), 100*mean(b0<0));
    NG(end+1)=mean(ng); MR(end+1)=mean(RR); MB(end+1)=mean(b0)/B-1; %#ok<SAGROW>
end
fprintf('\n  rho(|net|/gross, R)  = %+.3f   <- catalog value was -0.417\n', corr(NG',MR','type','Spearman'));
fprintf('  rho(|net|/gross, b0 bias) = %+.3f\n', corr(NG',abs(MB)','type','Spearman'));
