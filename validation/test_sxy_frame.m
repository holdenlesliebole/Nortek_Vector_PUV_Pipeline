% [Promoted from session scratch 2026-07-26. Supports the findings docs in
%  ../../PUV_paper/docs/. Kept in the repo because those docs cite it by name
%  as the reproduction path for published numbers.]
% FRAME CLOSURE TEST for radiation stress Sxy.
%
% Sxy = rho*g * int S(f) * (cg/c) * <sin(theta)cos(theta)> df
%     = rho*g * int S(f) * (cg/c) * (b2/2) df
% since b2 = <sin 2theta>.
%
% The frame of MOP's a2/b2 is NOT documented in this codebase, and the PUV's
% are shore-relative (velocities rotated to shore-normal before the
% cross-spectra). Getting this wrong silently flips the sign of alongshore
% forcing. read_MOPline2 returns MOP's OWN Sxy, so the frame can be
% established by reproducing it rather than assumed.
%
% Rule 18: do not propagate a report about the convention -- re-derive it.

startup_puv;
toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox');
if ~exist('read_MOPline2','file'), addpath(toolboxPath); end

rho = 1025; g = 9.81;

MOP = read_MOPline2('D0586', datetime(2023,5,10,0,0,0,'TimeZone','UTC'), ...
                            datetime(2023,5,20,0,0,0,'TimeZone','UTC'));

f = double(MOP.frequency(:)); fbw = double(MOP.fbw(:)); h = double(MOP.depth);
om = 2*pi*f; k = get_wavenumber(om, h);
c  = om ./ k(:);  cg = reshape(get_cg(k,h), [], 1);
n  = cg ./ c;

fprintf('\n===== Sxy FRAME CLOSURE TEST (D0586, h = %.1f m) =====\n', h);
fprintf('MOP provides Sxx and Sxy directly; reproduce them from spec1D + a2/b2.\n');
fprintf('shorenormal = %.1f deg\n', MOP.shorenormal);

nT = min(200, numel(MOP.time));
mySxy_raw = NaN(nT,1); mySxy_rot = NaN(nT,1); mySxx_raw = NaN(nT,1);
for t = 1:nT
    S  = double(MOP.spec1D(t,:))';
    a2 = double(MOP.a2(t,:))';
    b2 = double(MOP.b2(t,:))';
    if all(~isfinite(S)), continue; end
    S(~isfinite(S)) = 0; a2(~isfinite(a2)) = 0; b2(~isfinite(b2)) = 0;

    % As-is frame
    mySxy_raw(t) = rho*g*sum(S .* n .* (b2/2) .* fbw);
    % Sxx = rho g int S [ n(1+a2)/2 + (n - 0.5) ] df  (Longuet-Higgins)
    mySxx_raw(t) = rho*g*sum(S .* ( n.*(1+a2)/2 + (n - 0.5) ) .* fbw);

    % Rotated into the shore-normal frame by alpha = shorenormal.
    % Second moments rotate at 2*alpha.
    al = deg2rad(MOP.shorenormal);
    b2r = -a2*sin(2*al) + b2*cos(2*al);
    mySxy_rot(t) = rho*g*sum(S .* n .* (b2r/2) .* fbw);
end

refSxy = double(MOP.Sxy(1:nT)); refSxy = refSxy(:);
refSxx = double(MOP.Sxx(1:nT)); refSxx = refSxx(:);

gd = isfinite(mySxy_raw) & isfinite(refSxy);
fprintf('\nn = %d hours compared\n', sum(gd));

report = @(name, mine, ref) fprintf(...
    '  %-22s ratio(med) %8.3f   R %6.3f   RMS/|ref| %6.3f\n', name, ...
    median(mine(gd)./ref(gd)), corrfix(mine(gd), ref(gd)), ...
    sqrt(mean((mine(gd)-ref(gd)).^2))/mean(abs(ref(gd))));

fprintf('\nAgainst MOP.Sxy:\n');
report('as-is frame',      mySxy_raw, refSxy);
report('rotated by shorenormal', mySxy_rot, refSxy);
fprintf('\nAgainst MOP.Sxx:\n');
report('as-is frame',      mySxx_raw, refSxx);

fprintf('\nmagnitudes: MOP.Sxy median %.1f N/m, mine(as-is) %.1f, mine(rot) %.1f\n', ...
    median(refSxy(gd)), median(mySxy_raw(gd)), median(mySxy_rot(gd)));
fprintf('            MOP.Sxx median %.1f N/m, mine(as-is) %.1f\n', ...
    median(refSxx(gd)), median(mySxx_raw(gd)));

fprintf('\nVERDICT: whichever row gives ratio ~1 and R ~1 identifies the frame.\n');
fprintf('If NEITHER does, do not compute alongshore transport -- the convention\n');
fprintf('is not understood and a sign error is silent.\n\n');

function r = corrfix(a,b)
    if numel(a) < 3 || std(a)==0 || std(b)==0, r = NaN; return; end
    cc = corrcoef(a,b); r = cc(1,2);
end
