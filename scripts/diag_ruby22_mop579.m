% Cross-check RUBY22/MOP579_6m: our L1+L2 vs legacy Ruby2D PUV processing.
% Goal: find the source of unphysical Hs values in our L2.
% Author: Holden Leslie-Bole, 2026

%% Our L1
fprintf('=== Our L1 output ===\n');
P = load('outputs/L1/RUBY22/MOP579_6m_processed.mat');
PUV = P.PUV;
fprintf('Fields: %s\n', strjoin(fieldnames(PUV), ', '));
if isfield(PUV,'time')
    t = PUV.time;
    fprintf('time: %d samples, %s to %s\n', numel(t), char(t(1)), char(t(end)));
end
if isfield(PUV,'P')
    p = PUV.P;
    pV = p(~isnan(p));
    fprintf('P: total=%d, valid=%d (%.0f%%), median=%.3f dBar, range %.3f-%.3f, doffp=%.2f m\n', ...
        numel(p), numel(pV), 100*numel(pV)/numel(p), median(pV), min(pV), max(pV), PUV.doffp);
end
if isfield(PUV,'BuoyCoord')
    u = PUV.BuoyCoord.U; v = PUV.BuoyCoord.V; w = PUV.BuoyCoord.W;
    fprintf('U: valid=%d (%.0f%%), range %.2f to %.2f m/s\n', sum(~isnan(u)), 100*mean(~isnan(u)), min(u,[],'omitnan'), max(u,[],'omitnan'));
    fprintf('V: valid=%d (%.0f%%), range %.2f to %.2f m/s\n', sum(~isnan(v)), 100*mean(~isnan(v)), min(v,[],'omitnan'), max(v,[],'omitnan'));
end

%% Our L2
fprintf('\n=== Our L2 output ===\n');
S = load('outputs/L2/RUBY22/MOP579_6m_L2.mat'); L = S.L2;
fn = fieldnames(L);
fprintf('Fields: %s\n', strjoin(fn(1:min(15,numel(fn))), ', '));
fprintf('time: %d segments, %s to %s\n', numel(L.time), char(L.time(1)), char(L.time(end)));
fprintf('segValid: %d/%d (%.0f%%)\n', sum(L.segValid), numel(L.segValid), 100*mean(L.segValid));
fprintf('depth: median=%.2f m, range %.2f-%.2f\n', median(L.depth(L.segValid)), min(L.depth(L.segValid)), max(L.depth(L.segValid)));
fprintf('Hs (segValid): median=%.3f m, range %.3f-%.3f\n', median(L.Hs(L.segValid)), min(L.Hs(L.segValid)), max(L.Hs(L.segValid)));
% Identify the bad-Hs segments
badHs = L.Hs > 5 & L.segValid;
fprintf('Hs>5 m segments: %d (suspect)\n', sum(badHs));
if sum(badHs)>0
    fprintf('  bad-Hs depths: median=%.2f, range %.2f-%.2f\n', median(L.depth(badHs)), min(L.depth(badHs)), max(L.depth(badHs)));
end

%% Legacy L2
fprintf('\n=== Legacy Ruby2D L2 (Athina pipeline) ===\n');
LFile = '/Volumes/group/Ruby2D/PUV/Level2_QC/Torrey_Ruby2D_579_6m_PUV_process.mat';
if isfile(LFile)
    Lg = load(LFile);
    fprintf('Top-level vars: %s\n', strjoin(fieldnames(Lg)', ', '));
    for tn = fieldnames(Lg)'
        Pl = Lg.(tn{1});
        fprintf('--- %s ---\n', tn{1});
        if isstruct(Pl)
            fnPl = fieldnames(Pl);
            fprintf('  fields: %s\n', strjoin(fnPl, ', '));
            for f = {'Hs','depth','time','pressure','doffp','d_PUV','h'}
                if isfield(Pl, f{1})
                    v = Pl.(f{1});
                    if isnumeric(v) && ~isempty(v)
                        fprintf('  %s: median=%.3f range %.3f-%.3f, n=%d\n', f{1}, median(v(~isnan(v))), min(v,[],'omitnan'), max(v,[],'omitnan'), numel(v));
                    elseif isdatetime(v) && ~isempty(v)
                        fprintf('  %s: %s to %s, n=%d\n', f{1}, char(v(1)), char(v(end)), numel(v));
                    end
                end
            end
        end
    end
else
    fprintf('Legacy L2 not found at %s\n', LFile);
end

%% Also check legacy L1
fprintf('\n=== Legacy Ruby2D L1 ===\n');
LFile1 = '/Volumes/group/Ruby2D/PUV/Level1_QC/Torrey_Ruby2D_579_6m_processed.mat';
if isfile(LFile1)
    L1 = load(LFile1);
    fprintf('Top-level vars: %s\n', strjoin(fieldnames(L1)', ', '));
    for tn = fieldnames(L1)'
        v = L1.(tn{1});
        if isstruct(v)
            fnv = fieldnames(v);
            fprintf('  %s fields: %s\n', tn{1}, strjoin(fnv(1:min(15,numel(fnv))), ', '));
            for f = {'doffp','doffu','depth','P','pressure'}
                if isfield(v, f{1})
                    fv = v.(f{1});
                    if isnumeric(fv)
                        fprintf('    %s.%s: median=%.3f, n=%d\n', tn{1}, f{1}, median(fv(~isnan(fv))), numel(fv));
                    end
                end
            end
        end
    end
end
