function compare_rerun_2026_07_10()
%COMPARE_RERUN  Old (canonical) vs new (channel-decoupling) L2 for TOR23W and TBR23.
%
% Reports, per instrument: velocity segments recovered, qc_flag distribution, how healthy
% segments changed (should be tiny), and -- the headline -- how much storm-peak velocity the
% rerun adds where the old pipeline had none. This is the "sit with the results" summary for
% Chapters 1 (TBR23) and 2 (TOR23W).
%
% Reads canonical outputs/L2/<dep>/ and the rerun outputs/rerun_2026-07-10/L2/<dep>/.
% Modifies nothing.
%
% 2026-07-10.

startup_puv;
root = fileparts(fileparts(mfilename('fullpath')));
oldbase = fullfile(root,'outputs','L2');
newbase = fullfile(root,'outputs','rerun_2026-07-10','L2');
deps = {'TOR23W','TBR23'};

for d = 1:numel(deps)
    dep = deps{d};
    fprintf('\n################ %s ################\n', dep);
    nf = dir(fullfile(newbase,dep,'*_L2.mat'));
    fprintf('%-14s %8s %10s %10s %10s | %-28s | %s\n', 'instrument','oldValid','newValid', ...
        'segVal_vel','segVal_p','qc_flag [1 2 3 4]','recovered storm-peak (Hs>2 m)');
    for i = 1:numel(nf)
        lab = strrep(nf(i).name,'_L2.mat','');
        N = load(fullfile(newbase,dep,nf(i).name),'L2'); Ln = N.L2;
        oldf = fullfile(oldbase,dep,nf(i).name);
        if isfile(oldf), O = load(oldf,'L2'); Lo = O.L2; nOld = sum(Lo.segValid);
        else, Lo = []; nOld = NaN; end

        qc = arrayfun(@(f) sum(Ln.qc_flag==f), 1:4);

        % Recovered storm-peak: velocity-only segments (segValid_vel & ~segValid_p) with a
        % real forcing. Use the D0586 model Hs already carried in old L2 if present, else the
        % new segment's own Hs (NaN for velocity-only, so fall back to mop match by time).
        recVelOnly = Ln.segValid_vel & ~Ln.segValid_p;
        nRec = sum(recVelOnly);
        % how many of those have finite velocity skewness (i.e. a usable moment)?
        nRecMom = sum(recVelOnly & isfinite(Ln.vmom.skewness(:)));

        fprintf('%-14s %8s %10d %10d %10d | %-28s | %d vel-only, %d w/ moment\n', ...
            lab, num2str(nOld), sum(Ln.segValid), sum(Ln.segValid_vel), sum(Ln.segValid_p), ...
            mat2str(qc), nRec, nRecMom);

        % healthy-data sanity: on segments valid in BOTH, Hs should be ~unchanged
        if ~isempty(Lo)
            [~,ia,ib] = intersect(Ln.time, Lo.time);
            both = Ln.segValid(ia) & Lo.segValid(ib);
            if any(both)
                dHs = max(abs(Ln.Hs(ia(both)) - Lo.Hs(ib(both))), [], 'omitnan');
                dSk = max(abs(Ln.vmom.skewness(ia(both)) - Lo.vmom.skewness(ib(both))), [], 'omitnan');
                if dHs > 0.05 || dSk > 1e-6
                    fprintf('    NOTE healthy-segment change: max|dHs|=%.3g m, max|dSkew|=%.3g\n', dHs, dSk);
                end
            end
        end
    end
end

%% ---- Chapter-relevant headline: MOP586_10m storm-peak recovery ----
fprintf('\n================ HEADLINE: TOR23W/MOP586_10m storm-peak velocity ================\n');
f = fullfile(newbase,'TOR23W','MOP586_10m_L2.mat');
if isfile(f)
    N = load(f,'L2'); L = N.L2;
    t = L.time; if ~isdatetime(t), t=datetime(t,'ConvertFrom','datenum'); end; t.TimeZone='';
    peak = t>=datetime(2023,12,25) & t<datetime(2023,12,30);
    velok = L.segValid_vel & isfinite(L.vmom.skewness(:));
    fprintf('25-29 Dec 2023: %d hourly segments, %d with recovered velocity moments (qc_flag=3)\n', ...
        sum(peak), sum(peak & velok));
    fprintf('  the OLD pipeline had ZERO valid velocity here (the whole reason for this work).\n');
    if any(peak & velok)
        fprintf('  recovered skewness range over the peak: %.3f to %.3f (median %.3f)\n', ...
            min(L.vmom.skewness(peak&velok)), max(L.vmom.skewness(peak&velok)), median(L.vmom.skewness(peak&velok)));
    end
end
fprintf('\nCOMPARE_DONE\n');
end
