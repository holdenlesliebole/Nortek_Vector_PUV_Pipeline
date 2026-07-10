function qc = puv_channel_qc(DAT, SEN, fs, pMed, cfg, qcOpts, label)
%PUV_CHANNEL_QC  Per-channel QC decisions for one PUV record (channel decoupling).
%
%   qc = puv_channel_qc(DAT, SEN, fs, pMed, cfg, qcOpts, label)
%
% Pure decision function: given the raw (untrimmed) DAT/SEN matrices and the pressure
% reference pMed, it returns every per-sample QC decision the L1 pipeline makes, WITHOUT
% modifying its inputs. PUV_raw_process applies these decisions. Extracting the logic here
% is what makes it testable in isolation -- the previous test suites re-implemented the
% algebra instead of exercising the real code, so this function had no coverage. See
% test_puv_channel_qc.m.
%
% INPUTS
%   DAT    [N x >=15] Nortek velocity table. Columns used:
%            3,4,5   = U, V, W velocity (m/s)
%            12,13,14 = beam correlation 1,2,3 (%)
%            15      = pressure (dBar)
%   SEN    [N x >=14] Nortek sensor table. Columns used:
%            10 = sound speed the instrument USED (m/s)
%            12 = pitch (deg), 13 = roll (deg), 14 = temperature (deg C)
%   fs     sampling rate (Hz)
%   pMed   pressure reference (dBar), from the healthy first-burst window (PUV_raw_process)
%   cfg    deployment config; only cfg.soundSpeedRef is read here (optional scalar c, m/s)
%   qcOpts struct of thresholds (corrMin, Tvalid, TmaxDev, TrefHours, cFactorTol)
%   label  instrument label, for warning text
%
% OUTPUT qc, a struct of per-sample (N x 1) fields and scalars:
%   .valid_corr   min beam correlation >= corrMin
%   .valid_p      pressure within [pMed/2, 2*pMed]
%   .valid_tilt   NOT flagged by the tilt-variability / absolute-tilt QC
%   .valid_T      thermistor usable (see below)
%   .present      the instrument actually wrote this row (U,V not NaN)
%   .tilt_trusted whether the tilt sensor's reading can be believed
%   .valid_vel    Doppler velocity usable
%   .valid_joint  the OLD row-level mask (all channels good), preserved verbatim
%   .vel_c_factor    [single] sound-speed rescale factor, exactly 1 where not applied
%   .vel_c_corrected [logical] rescale materially applied
%   .vel_rotation_static [logical] rotate with a static tilt rather than the sensor
%   .Tref, .c_true, .c_source, .pStat, .rStat  scalars / provenance
%
% The tilt-variability inputs (bad_tilt_var, bad_tilt_abs) are recomputed here from SEN so
% the function is self-contained; they use the same thresholds as PUV_raw_process.
%
% Holden Leslie-Bole, 2026-07-10.

if nargin < 7, label = 'unknown'; end
N = size(DAT,1);

%% --- tilt-variability QC (recomputed here so the function is self-contained) ---
pitch_raw = SEN(:,12);  roll_raw = SEN(:,13);
tiltStdMax = qcOpts.tiltStdMax;  tiltAbsMax = qcOpts.tiltAbsMax;  tiltWindow = qcOpts.tiltWindow;
pitchStd = movstd(pitch_raw, tiltWindow, 'omitnan');
rollStd  = movstd(roll_raw,  tiltWindow, 'omitnan');
bad_tilt_var = pitchStd > tiltStdMax | rollStd > tiltStdMax;
bad_tilt_abs = abs(pitch_raw) >= tiltAbsMax | abs(roll_raw) >= tiltAbsMax;

%% --- temperature validity (F6/F1 fix) ---
% The thermistor is judged on PHYSICAL PLAUSIBILITY, not on deviation from a global median.
% The old test `abs(T - Tref) <= TmaxDev` conflated a genuine far-from-median seasonal
% temperature (fine) with a sensor failure (not fine): a warm-start deployment that later
% saw genuine cold upwelling would have its good cold-water samples flagged and their
% velocities corrupted by the sound-speed rescale. Physical plausibility does not have that
% failure mode -- a genuine seawater temperature is valid whatever the rest of the record did.
%
%   Tvalid   absolute bounds. Default [-2 40] catches freezing/firmware garbage everywhere;
%            SET IT TO THE SITE'S PLAUSIBLE WATER-TEMPERATURE RANGE (e.g. SD coastal [9 26])
%            to catch subtler within-bounds failures. This is the primary discriminant.
%   maxJump  optional rate gate: |T[i]-T[i-1]| beyond this is an instantaneous step no water
%            body can make, so it is a sensor glitch. Default Inf (off). Never fires on
%            genuine drift, however fast, because it is a per-sample jump, not a rate.
Traw  = SEN(:,14);
phys  = isfinite(Traw) & Traw >= qcOpts.Tvalid(1) & Traw <= qcOpts.Tvalid(2);
if isfield(qcOpts,'maxJump') && isfinite(qcOpts.maxJump)
    jump = [false; abs(diff(Traw)) > qcOpts.maxJump];
    fastStep = jump | [jump(2:end); false];      % flag both sides of a step
else
    fastStep = false(size(Traw));
end
valid_T = phys & ~fastStep;
tilt_trusted = valid_T;

%% --- per-channel masks ---
valid_corr = min(DAT(:,12:14), [], 2) >= qcOpts.corrMin;
valid_p    = DAT(:,15) >= pMed/2 & DAT(:,15) <= pMed*2;
valid_tilt = ~(bad_tilt_var | bad_tilt_abs);
present    = ~isnan(DAT(:,3)) & ~isnan(DAT(:,4));

% Reference water temperature for the c(T) fit, computed ONLY from in-water, physically
% plausible samples (F1 fix): a leading on-deck warm-up or an early sensor failure no longer
% poisons it, the way the old first-48h raw median could.
refSel = valid_T & valid_p;
if any(refSel), Tref = median(Traw(refSel), 'omitnan');
else,           Tref = median(Traw(phys), 'omitnan'); end   % fallback: any plausible sample

% Velocity gating.
%   ABSOLUTE tilt (a toppled frame, |tilt| >= tiltAbsMax) ALWAYS invalidates velocity: a
%     30-degree reading is physically impossible for a seabed frame, so either the frame
%     moved or the sensor is lying -- in neither case can the velocity be rotated correctly.
%     This must not depend on whether the thermistor is healthy (F1 escalation / BT fix):
%     the old `~tilt_trusted | valid_tilt` let a dead thermistor disable the topple gate.
%   VARIABILITY tilt (a jittery reading) invalidates velocity only when the tilt sensor is
%     trusted; when its sensor block has failed, the reading is discarded and a static tilt
%     from the healthy window is substituted instead (below).
valid_vel  = valid_corr & present & ~bad_tilt_abs & (~tilt_trusted | ~bad_tilt_var);

% OLD row-level mask, verbatim, so segValid downstream keeps its meaning.
valid_joint = valid_vel & valid_p & valid_tilt;

%% --- sound-speed rescale ---
c_rec = SEN(:,10);
vel_c_factor    = ones(N,1,'single');
vel_c_corrected = false(N,1);
c_true = NaN;  c_source = 'none';

if any(~valid_T & valid_vel)
    if isfield(cfg,'soundSpeedRef') && isscalar(cfg.soundSpeedRef) && isfinite(cfg.soundSpeedRef)
        c_true = cfg.soundSpeedRef;
        c_source = sprintf('cfg.soundSpeedRef = %.1f m/s', c_true);
    else
        gd = valid_T & isfinite(c_rec);
        if sum(gd) < 1000
            warning('puv_channel_qc:noSoundSpeedRef', ...
                ['%s: thermistor invalid for %.1f%% of samples and too few healthy ' ...
                 'samples to calibrate c(T). Velocities left UNCORRECTED and flagged.'], ...
                label, 100*mean(~valid_T));
        else
            ab = [ones(sum(gd),1) double(Traw(gd))] \ double(c_rec(gd));
            % F7: never EXTRAPOLATE the c(T) fit. The slope is poorly conditioned when the
            % healthy temperature range is narrow, so evaluate it at the nearest in-range
            % temperature rather than beyond the data that built it.
            Tlo = min(Traw(gd));  Thi = max(Traw(gd));
            Teval = min(max(Tref, Tlo), Thi);
            c_true = ab(1) + ab(2)*Teval;
            extrap = '';
            if Tref < Tlo || Tref > Thi
                extrap = sprintf(' [Tref %.2f OUT of fit range [%.2f %.2f]; clamped]', Tref, Tlo, Thi);
            end
            c_source = sprintf('own c(T) fit: c = %.2f %+.4f*T, Teval = %.2f C -> c_true = %.1f m/s%s', ...
                ab(1), ab(2), Teval, c_true, extrap);
        end
    end
    if isfinite(c_true)
        fix = ~valid_T & valid_vel & isfinite(c_rec) & c_rec > 1000;
        f_i = single(c_true ./ c_rec(fix));
        vel_c_factor(fix)    = f_i;
        vel_c_corrected(fix) = abs(f_i - 1) > qcOpts.cFactorTol;
    end
end

%% --- static-tilt substitution decision (F2 fix) ---
% Where the tilt sensor is untrustworthy (its block failed) but the Doppler is fine and the
% frame is not toppled, rotate with a static tilt from the healthy window rather than trust
% the (possibly garbage) live reading. bad_tilt_abs samples are already invalid (gated
% above), so this is the variability case only.
pStat = median(SEN(valid_tilt & tilt_trusted, 12), 'omitnan');
rStat = median(SEN(valid_tilt & tilt_trusted, 13), 'omitnan');
% CRUCIAL: only claim a static substitution where one can ACTUALLY be made. If the whole
% record has no trusted-tilt window (pStat/rStat are NaN), the flag must stay false so a
% segment is never labelled "static tilt applied" on data that received no correction.
haveStatic = isfinite(pStat) && isfinite(rStat);
vel_rotation_static = ~tilt_trusted & bad_tilt_var & ~bad_tilt_abs & valid_vel & haveStatic;

%% --- pack ---
qc = struct('valid_corr',valid_corr,'valid_p',valid_p,'valid_tilt',valid_tilt, ...
    'valid_T',valid_T,'present',present,'tilt_trusted',tilt_trusted,'valid_vel',valid_vel, ...
    'valid_joint',valid_joint,'vel_c_factor',vel_c_factor,'vel_c_corrected',vel_c_corrected, ...
    'vel_rotation_static',vel_rotation_static,'Tref',Tref,'c_true',c_true,'c_source',c_source, ...
    'pStat',pStat,'rStat',rStat);
end
