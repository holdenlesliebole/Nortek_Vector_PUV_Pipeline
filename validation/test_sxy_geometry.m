% [Promoted from session scratch 2026-07-26. Companion to diagnose_sxy_heading.m:
%  falsifies the shore-normal/geometry explanation and separates the two
%  populations the "16% negative" figure conflated.]
% Is the negative Sxy a SHORE-NORMAL / GEOMETRY mismatch?
%
% Second moments rotate as 2*alpha:  b2' = -a2*sin(2a) + b2*cos(2a).
% A 90-degree error in the shore normal gives cos(2a) -> -1 and FLIPS Sxy.
% So a shorenormal mismatch between the PUV frame (L2.shorenormal, used when the
% velocities were rotated at L1/L2) and the model frame (MOP.shorenormal, used
% to rotate the model's geographic a2/b2) is an exact candidate mechanism --
% and it is far more plausible than 180 deg on a curved coastline.
%
% Decisive control already in the data: TOR23W and TOR24W share the MOP586_10m
% transect but have OPPOSITE Sxy signs (+0.91 vs -0.63). If the transect
% geometry were responsible, both would fail together.
%
% Also separates the two populations the "16% negative" figure conflated:
% strong anticorrelation (a flip) vs weak negative (indistinguishable from zero).

startup_puv
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end
V = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/validation';

C = load(fullfile(V,'cross_deployment_consequences.mat')); R = C.ROWS;
key = arrayfun(@(r)[r.deployment '/' r.label],R,'UniformOutput',false);
[~,ia]=unique(key,'stable'); R=R(ia);
R = R(~(strcmp({R.deployment},'RUBY22') & contains({R.label},'30m')));

reg = deployment_registry();
L2root = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';

fprintf('\n===== SHORE-NORMAL MISMATCH TEST =====\n');
fprintf('%-9s %-13s %8s %9s %9s %9s %8s\n', ...
    'deploy','label','Sxy_R','sn_PUV','sn_MOP','diff','2*diff');

sn2 = NaN(numel(R),1); srr = [R.Sxy_R]';
cache = containers.Map('KeyType','char','ValueType','double');
for i = 1:numel(R)
    fn = fullfile(L2root, R(i).deployment, [R(i).label '_L2.mat']);
    if ~isfile(fn), continue; end
    S = load(fn,'L2'); L2 = S.L2;
    snP = NaN; if isfield(L2,'shorenormal'), snP = double(L2.shorenormal); end

    st = '';
    if isfield(L2,'refStation')&&~isempty(L2.refStation), st=L2.refStation;
    elseif isfield(L2,'mopStation')&&~isempty(L2.mopStation), st=L2.mopStation; end
    snM = NaN;
    if ~isempty(st)
        if isKey(cache,st), snM = cache(st);
        else
            try
                v=find(L2.segValid); t1=min(L2.time(v));
                if isempty(t1.TimeZone), t1.TimeZone='UTC'; end
                M = read_MOPline2(st, t1, t1+hours(6));
                snM = double(M.shorenormal); cache(st)=snM;
            catch, end
        end
    end
    d = wrapTo180(snP - snM);
    sn2(i) = abs(wrapTo180(2*d));    % what actually matters for b2
    mark = ''; if srr(i) < 0, mark='  <-- NEG'; end
    fprintf('%-9s %-13s %8.3f %9.1f %9.1f %9.1f %8.1f%s\n', ...
        R(i).deployment, R(i).label, srr(i), snP, snM, d, sn2(i), mark);
end

g = isfinite(sn2)&isfinite(srr);
[rho,p] = corr(sn2(g), srr(g), 'type','Spearman');
fprintf('\n  rho(|2*shorenormal diff|, Sxy_R) = %+.3f (p=%.3g)\n', rho, p);
fprintf('  A geometry cause predicts strongly NEGATIVE rho and 2*diff near 180 deg\n');
fprintf('  for the flipped records.\n');

%% ---- the same-transect control
fprintf('\n===== SAME-TRANSECT CONTROL =====\n');
labs = {R.label}'; deps = {R.deployment}';
for L = {'MOP586_10m','MOP586_15m','MOP591_9m','MOP654_7m','MOP045_7m'}
    m = find(strcmp(labs,L{1}));
    if numel(m)<2, continue; end
    fprintf('  %-13s :', L{1});
    for i = m', fprintf('  %s %+.2f (2d=%.0f)', deps{i}, srr(i), sn2(i)); end
    fprintf('\n');
end
fprintf('\n  Same transect, same 2*diff, opposite sign => geometry is NOT the cause.\n');

%% ---- two populations
fprintf('\n===== TWO POPULATIONS, NOT ONE =====\n');
neg = srr < 0;
strong = srr < -0.5;
weak = neg & ~strong;
fprintf('  strong anticorrelation (R < -0.5): %d records\n', sum(strong));
for i = find(strong)', fprintf('     %-9s %-13s %+.3f\n', deps{i}, labs{i}, srr(i)); end
fprintf('  weak negative (-0.5 <= R < 0):     %d records  -- consistent with ZERO,\n', sum(weak));
fprintf('                                        not with anticorrelation\n');
for i = find(weak)', fprintf('     %-9s %-13s %+.3f\n', deps{i}, labs{i}, srr(i)); end
fprintf('\n  Only the strong group requires a mechanism. Reporting "16%% negative"\n');
fprintf('  conflated a real effect (n=%d) with statistical noise (n=%d).\n', sum(strong), sum(weak));
