function n2b_nonlinear_ztest()
%N2B_NONLINEAR_ZTEST  Does the velocity->pressure inversion fail in the harmonic band as
% waves get large? Tested on HEALTHY data only -- no recovery, no sound-speed correction.
%
% N2 showed the Phase-A Hs deficit lives entirely at 0.12-0.20 Hz, while the swell band
% (0.04-0.09 Hz) reproduces the sound-speed ratio exactly. 0.12-0.20 Hz is the bound harmonic
% of the 15-16 s storm swell (2 x 0.065 Hz).
%
% HYPOTHESIS. `Spp_from_vel = (Suu+Svv)*(omega/gk)^2` assumes every frequency is a FREE linear
% wave obeying omega^2 = g k tanh(k h). A bound harmonic does not: it is phase-locked to its
% primary and travels with wavenumber 2*k1, not k_linear(2*omega1). In intermediate depth
% k grows superlinearly with omega, so k_linear(2*omega1) > 2*k1 and the operator uses too
% large a k, giving too small a Spp. The error therefore
%   (a) lives in the harmonic band,
%   (b) makes the reconstruction read LOW there,
%   (c) grows with wave nonlinearity, i.e. with Hs.
%
% All three are checkable on healthy bursts where BOTH Spp and (Suu,Svv) were measured.
% L2 stores Spp, Suu, Svv, Kp, S_eta and f per segment, so the frequency-resolved z-test
%   z(f) = Spp_measured(f) / [ (Suu+Svv)(f) * (omega/gk)^2 ]
% can be formed directly. z(f) = 1 means the inversion is exact at that frequency.
%
% FALSIFIER. If z(f) in 0.12-0.20 Hz is flat in Hs, the hypothesis is wrong and the Phase-A
% harmonic-band deficit needs another explanation.
%
% 2026-07-09.

startup_puv;
L2d='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2/';
deps={'TOR23W','TOR24S','TOR24W','TOR25S'};
g=9.81;
bands=[0.040 0.055; 0.055 0.070; 0.070 0.090; 0.090 0.120; 0.120 0.160; 0.160 0.200; 0.200 0.250];
bn={'0.040-0.055','0.055-0.070','0.070-0.090','0.090-0.120','0.120-0.160','0.160-0.200','0.200-0.250'};

ZB=[]; HS=[]; TP=[];
for d=1:numel(deps)
    f10=[L2d deps{d} '/MOP586_10m_L2.mat']; if ~isfile(f10), continue; end
    S=load(f10,'L2'); L=S.L2; clear S
    f=L.f(:); ok=logical(L.segValid(:)) & isfinite(L.Hs(:)) & isfinite(L.Tp(:));
    idx=find(ok);
    om=2*pi*f;
    zb=nan(numel(idx),size(bands,1));
    for q=1:numel(idx)
        i=idx(q);
        H=L.depth(i); if ~isfinite(H), continue; end
        k=zeros(size(f)); k(2:end)=get_wavenumber(om(2:end),H);
        u2p=zeros(size(f)); u2p(2:end)=om(2:end)./(g*k(2:end));
        Sfv=(L.Suu(:,i)+L.Svv(:,i)).*u2p.^2;
        Spp=L.Spp(:,i);
        for b=1:size(bands,1)
            s=f>=bands(b,1)&f<bands(b,2);
            den=trapz(f(s),Sfv(s));
            if den>0, zb(q,b)=trapz(f(s),Spp(s))/den; end
        end
    end
    ZB=[ZB;zb]; HS=[HS;L.Hs(idx)]; TP=[TP;L.Tp(idx)]; %#ok<AGROW>
    fprintf('%-8s %5d healthy bursts\n', deps{d}, numel(idx));
    clear L
end

fprintf('\nMOP586_10m, %d healthy bursts. Frequency-resolved z(f) = Spp_meas / Spp_from_vel.\n', size(ZB,1));
fprintf('z = 1 means the linear inversion is exact in that band.\n');
fprintf('Reconstruction bias in that band = 1/sqrt(z): z < 1 => reconstruction reads HIGH,\n');
fprintf('z > 1 => reconstruction reads LOW.\n\n');

he=[0 1 1.5 2 2.5 6]; hn={'<1','1-1.5','1.5-2','2-2.5','>2.5'};
fprintf('%-14s','band (Hz)'); fprintf('%11s',hn{:}); fprintf('%12s\n','trend');
for b=1:size(bands,1)
    fprintf('%-14s',bn{b});
    v=nan(1,numel(hn));
    for h=1:numel(hn)
        s=HS>=he(h)&HS<he(h+1)&isfinite(ZB(:,b));
        if sum(s)>=25, v(h)=median(ZB(s,b)); fprintf('%11.3f',v(h)); else, fprintf('%11s',sprintf('n=%d',sum(s))); end
    end
    gd=isfinite(v);
    if sum(gd)>=3
        rho=corr(HS(isfinite(ZB(:,b))),ZB(isfinite(ZB(:,b)),b),'type','Spearman');
        fprintf('%12.3f\n', rho);
    else
        fprintf('%12s\n','-');
    end
end
fprintf('\nlast column: Spearman(Hs, z) within that band, all bursts.\n');

fprintf('\n--- The prediction, restated ---\n');
fprintf('Harmonic bands (0.120-0.200 Hz) should show z RISING with Hs (reconstruction reads\n');
fprintf('increasingly LOW), while swell bands (0.040-0.090 Hz) stay flat near 1.\n');

fprintf('\n--- Practical consequence: reconstruct Hs over the swell band only ---\n');
sw = find(bands(:,1)>=0.040 & bands(:,2)<=0.120);
hb = find(bands(:,1)>=0.120 & bands(:,2)<=0.200);
for h=1:numel(hn)
    s=HS>=he(h)&HS<he(h+1);
    if sum(s)<25, continue; end
    zsw=median(median(ZB(s,sw),2,'omitnan'),'omitnan');
    zhb=median(median(ZB(s,hb),2,'omitnan'),'omitnan');
    fprintf('  Hs %-8s  swell-band z = %.3f (bias %+.1f%%)   harmonic-band z = %.3f (bias %+.1f%%)\n', ...
        hn{h}, zsw, 100*(1/sqrt(zsw)-1), zhb, 100*(1/sqrt(zhb)-1));
end
save('/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/rec/n2b.mat','ZB','HS','TP','bands','-v7.3');
end
