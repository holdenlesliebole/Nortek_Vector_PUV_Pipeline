function pass = test_l1_velocity_gap_mask()
%TEST_L1_VELOCITY_GAP_MASK  Synthetic closure + break tests for l1_velocity_gap_mask,
%   plus an optional real-record agreement check against L2.velGap.
%
%   Synthetic: 100 samples at 2 Hz; 3 flagged unconfirmed (samples 10, 11, 40);
%   cutoff at sample 81 (t = 40 s). Expected mask: those 3 plus 81..100 = 23 samples,
%   nUnconfirmed = 3, nCutoff = 20. Criteria fixed before running: exact equality.
%   Break tests (each must FAIL the exact check): (1) drop the unconfirmed flag field;
%   (2) move the cutoff one sample later.
%
%   Real record (skipped with a printed reason if the files are absent):
%   TOR23W MOP586_10m, which has both unconfirmed samples and a velInvalidFrom cutoff.
%   The mask counts must equal the published L2.velGap counts exactly.
%
%   Written 2026-11-17.

nPass = 0; nTot = 0;
t0 = datetime(2023,1,1,0,0,0);
P.time = t0 + seconds((0:99)'/2);
P.qc.vel_beamstep_unconfirmed = false(100,1);
P.qc.vel_beamstep_unconfirmed([10 11 40]) = true;
I.velInvalidFrom = t0 + seconds(40);
expect = P.qc.vel_beamstep_unconfirmed; expect(81:100) = true;

[m, info] = l1_velocity_gap_mask(P, I);
ok = isequal(m, expect) && info.nUnconfirmed == 3 && info.nCutoff == 20;
nTot = nTot + 1; nPass = nPass + ok;
fprintf('  synthetic closure: %s (mask %d/%d samples as expected)\n', tf(ok), sum(m == expect), 100);

% Break 1: unconfirmed flag missing -> must no longer match
Pb = rmfield(P, 'qc');
mb = l1_velocity_gap_mask(Pb, I);
fired = ~isequal(mb, expect);
nTot = nTot + 1; nPass = nPass + fired;
fprintf('  break 1 (flag field removed) fires: %s\n', tf(fired));

% Break 2: cutoff one sample later -> must no longer match
Ib = I; Ib.velInvalidFrom = I.velInvalidFrom + seconds(0.5);
mb = l1_velocity_gap_mask(P, Ib);
fired = ~isequal(mb, expect);
nTot = nTot + 1; nPass = nPass + fired;
fprintf('  break 2 (cutoff shifted one sample) fires: %s\n', tf(fired));

% Real record agreement with published L2
root = fileparts(fileparts(mfilename('fullpath')));
l1f = fullfile(root, 'outputs', 'L1', 'TOR23W', 'MOP586_10m_processed.mat');
l2f = fullfile(root, 'outputs', 'L2', 'TOR23W', 'MOP586_10m_L2.mat');
if isfile(l1f) && isfile(l2f)
    addpath(fullfile(root, 'config'));
    cfg = TOR23W_config();
    k = find(strcmp({cfg.instruments.label}, 'MOP586_10m'), 1);
    S1 = load(l1f, 'PUV'); S2 = load(l2f, 'L2');
    [m, info] = l1_velocity_gap_mask(S1.PUV, cfg.instruments(k));
    g = S2.L2.velGap;
    ok = info.nUnconfirmed == g.nUnconfirmed && info.nCutoff == g.nCutoff;
    nTot = nTot + 1; nPass = nPass + ok;
    fprintf('  real TOR23W MOP586_10m vs L2.velGap: %s (unconfirmed %d vs %d, cutoff %d vs %d, mask %d)\n', ...
        tf(ok), info.nUnconfirmed, g.nUnconfirmed, info.nCutoff, g.nCutoff, sum(m));
else
    fprintf('  real-record check SKIPPED: L1 or L2 for TOR23W MOP586_10m not on disk\n');
end

pass = nPass == nTot;
fprintf('test_l1_velocity_gap_mask: %d/%d\n', nPass, nTot);
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
