startup_puv;
paths = { ...
    'outputs/L4/TBR23/MOP580_5m_L4.mat', ...
    'outputs/L4/TOR24S/MOP586_7m_L4.mat', ...
    'outputs/L4/TBR23/MOP580_7m_L4.mat' ...   % clean reference
    };
for ii = 1:numel(paths)
    fp = paths{ii};
    ld = load(fp, 'L4'); L4 = ld.L4; ref = L4.ref;
    fprintf('\n=== %s ===\n', fp);
    fprintf('  segs=%d, Hs/h median=%.3f, sat fraction=%.0f%%\n', ...
        numel(ref.Hs_over_h), median(ref.Hs_over_h, 'omitnan'), 100*mean(ref.saturation_flag, 'omitnan'));
    for b = {'IG','swell','sea'}
        R = ref.byBand.(b{1}).R2;
        Ein = ref.byBand.(b{1}).Ef_in;
        Eout = ref.byBand.(b{1}).Ef_out;
        ok = ~isnan(R);
        q = quantile(R(ok), [0.05 0.25 0.50 0.75 0.95 0.99]);
        fprintf('  %-5s R2 q5/25/50/75/95/99: %.3f %.3f %.3f %.3f %.3f %.3f  (n=%d/%d)\n', ...
            b{1}, q(1),q(2),q(3),q(4),q(5),q(6), sum(ok), numel(R));
        fprintf('         Ef_in  q5/50/95: %.4f %.4f %.4f W/m\n', quantile(Ein(ok),[0.05 0.5 0.95]));
        fprintf('         Ef_out q5/50/95: %.4f %.4f %.4f W/m\n', quantile(Eout(ok),[0.05 0.5 0.95]));
    end
    R = ref.byBand.swell.R2;
    Ein = ref.byBand.swell.Ef_in;
    Eout = ref.byBand.swell.Ef_out;
    bad = R > 5 & ~isnan(R);
    fprintf('  swell R2>5: %d/%d segments\n', sum(bad), numel(R));
    if any(bad)
        ib = find(bad, 3);
        for j = 1:numel(ib)
            fprintf('    seg %d: R2=%.2f Ein=%.3e Eout=%.3e Hs/h=%.3f sat=%d\n', ...
                ib(j), R(ib(j)), Ein(ib(j)), Eout(ib(j)), ref.Hs_over_h(ib(j)), ref.saturation_flag(ib(j)));
        end
    end
end
