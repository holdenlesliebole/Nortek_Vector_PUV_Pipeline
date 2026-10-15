function R = run_all_tests(varargin)
% RUN_ALL_TESTS  Run every self-contained regression test in the repository.
%
%   run_all_tests                        self-contained tests only
%   run_all_tests('includeData', true)   also the read-only tests that need
%                                        this machine's outputs/ tree, the lab
%                                        server or the network
%   R = run_all_tests(...)               struct array: name, status, seconds, note
%
% From a shell (exits nonzero when any test fails):
%   matlab -batch "cd /path/to/PUV_Pipeline; startup_puv; run_all_tests"
%
% A test PASSES when it returns without error AND its printed output carries
% none of the failure markers the older tests print instead of erroring
% ('[FAIL]', 'FAILURES PRESENT', 'SOME FAILED'). Each test runs in its own
% function workspace, and the MATLAB path and working folder are restored after
% it, so one test cannot change what the next one resolves.
%
% SKIP: a test that needs the out-of-repo L3 files (t_tide v1.3 and the lab
% toolbox, shared/external_deps) is skipped, not failed, when any is missing
% from the path at the start of the run. PUV_L3_currents would otherwise add
% them from ~/Documents/Scripps/Research/toolbox/ on its own, so the result
% would depend on the machine. SKIPs are listed and do not count as passes.
%
% Note: on R2025a (macOS) `matlab -nodisplay -batch` exits 0 even when the
% batch command errors; use plain `matlab -batch` when the exit code matters.
%
% Never run here: tests that WRITE into outputs/ (test_resolution_artifact,
% test_harmonic_closure, test_bic_null_overlap). outputs/ is written only by the
% pipeline (docs/catalog_changes/README.md); run those by hand if needed.
%
% Author: Holden Leslie-Bole, 2026

    p = inputParser; addParameter(p, 'includeData', false); parse(p, varargin{:});
    repo = fileparts(fileparts(mfilename('fullpath')));
    if ~exist('deployment_registry', 'file'), run(fullfile(repo, 'startup_puv.m')); end

    % name, folder, kind ('m' or 'sh'), requirement ('' or 'L3deps')
    SELF = {
        'test_channel_decoupling',            'L1_raw_to_qc', 'm',  ''
        'test_puv_channel_qc',                'L1_raw_to_qc', 'm',  ''
        'test_puv_trim_anchor',               'L1_raw_to_qc', 'm',  ''
        'test_enu_declination_closure',       'validation',   'm',  ''
        'test_L2_channel_decoupling',         'L2_spectral',  'm',  ''
        'test_pressure_correction_synthetic', 'L2_spectral',  'm',  ''
        'test_ztest_linear',                  'L2_spectral',  'm',  ''
        'test_qtest_linear',                  'L2_spectral',  'm',  ''
        'test_phase_PU_linear',               'L2_spectral',  'm',  ''
        'test_bonneton_reconstruction',       'L2_spectral',  'm',  ''
        'test_kp_bound_harmonic',             'L2_spectral',  'm',  ''
        'test_fillmissing_endvalues',         'validation',   'm',  'L3deps'
        'test_L3_transport_closure',          'validation',   'm',  ''
        'test_L3_driver_tvalid',              'validation',   'm',  ''
        'test_sediment_modules_20260813',     'validation',   'm',  ''
        'test_ws_to_D_20261014',              'validation',   'm',  ''
        'test_bispectral_bound',              'validation',   'm',  ''
        'test_shoal_bin_synthetic',           'validation',   'm',  ''
        'test_provenance',                    'validation',   'm',  'L3deps'
        'test_driver_loud_failures',          'validation',   'm',  ''
        'test_watchdog_xspec',                'validation',   'sh', ''
    };
    % read-only, but need data that a fresh clone does not have
    DATA = {
        'test_l3_currents_determinism',  'validation',   'm', 'reads outputs/L3 and L2; NOAA tide download'
        'test_shape_metric_sensitivity', 'validation',   'm', 'reads outputs/L2/TBR23'
        'test_sxy_frame',                'validation',   'm', 'CDIP THREDDS download; lab toolbox read_MOPline2'
        'test_sxy_geometry',             'validation',   'm', 'reads outputs/validation and outputs/L2'
        'test_read_VEC',                 'L1_raw_to_qc', 'm', 'raw .VEC/.dat on /Volumes/group'
        'test_L1_comparison',            'L1_raw_to_qc', 'm', 'legacy L1 file not mirrored on the server'
    };
    NEVER = {
        'test_resolution_artifact', 'writes outputs/validation/resolution_artifact_bound.mat'
        'test_harmonic_closure',    'writes outputs/validation/harmonic_closure*.mat'
        'test_bic_null_overlap',    'writes outputs/validation/bic_null_overlap.mat; long Monte Carlo'
    };

    list = SELF;
    if p.Results.includeData, list = [list; [DATA(:, 1:3), repmat({''}, size(DATA,1), 1)]]; end
    ext = external_deps('L3');
    missing = {ext(strcmp({ext.sha256}, 'missing')).name};
    R = struct('name', {}, 'status', {}, 'seconds', {}, 'note', {});
    fprintf('\nrun_all_tests: %d tests from %s\n\n', size(list, 1), repo);
    for i = 1:size(list, 1)
        [nm, dirn, kind, req] = list{i, :};
        f = fullfile(repo, dirn, [nm '.' kind]);
        t0 = tic;
        if strcmp(req, 'L3deps') && ~isempty(missing)
            status = 'SKIP'; note = sprintf('L3 external files not on the path (%d of %d missing)', numel(missing), numel(ext));
        else
            [status, note] = run_one(f, kind);
        end
        dt = toc(t0);
        R(end+1) = struct('name', nm, 'status', status, 'seconds', dt, 'note', note); %#ok<AGROW>
        fprintf('  %-4s  %-36s %6.1f s  %s\n', status, nm, dt, note);
    end

    nPass = sum(strcmp({R.status}, 'PASS')); nSkip = sum(strcmp({R.status}, 'SKIP'));
    nTot = numel(R) - nSkip; nFail = nTot - nPass;
    fprintf('\n=== %d/%d tests passed, %d skipped\n', nPass, nTot, nSkip);
    if nSkip > 0
        fprintf('Skipped because these L3 external files are not on the path: %s\n', strjoin(missing, ', '));
        fprintf('(install t_tide v1.3 and the lab toolbox; see README "External dependencies")\n');
    end
    if ~p.Results.includeData
        fprintf('\nNot run (need data a fresh clone lacks; run_all_tests(''includeData'', true)):\n');
        for i = 1:size(DATA, 1), fprintf('  %-32s %s\n', DATA{i,1}, DATA{i,4}); end
    end
    fprintf('Never run here (they write into outputs/):\n');
    for i = 1:size(NEVER, 1), fprintf('  %-32s %s\n', NEVER{i,1}, NEVER{i,2}); end
    if nFail > 0
        bad = {R(strcmp({R.status}, 'FAIL')).name};
        error('run_all_tests:failed', '%d/%d tests failed: %s', nFail, nTot, strjoin(bad, ', '));
    end
end

function [status, note] = run_one(f, kind)
    oldPath = path; oldDir = pwd; oldWarn = warning;
    restore = onCleanup(@() restore_env(oldPath, oldDir, oldWarn));
    out = ''; note = '';
    try
        if strcmp(kind, 'sh')
            [st, out] = system(sprintf('zsh "%s"', f));
            if st ~= 0, error('run_all_tests:sh', 'exit status %d', st); end
        else
            out = run_isolated(f);
        end
        bad = regexp(out, '\[FAIL\]|FAILURES PRESENT|SOME FAILED', 'match', 'once');
        if isempty(bad), status = 'PASS'; else, status = 'FAIL'; note = sprintf('printed "%s"', bad); end
    catch ME
        status = 'FAIL'; note = strtok(ME.message, newline);
    end
    tot = regexp(out, '(\d+)\s*/\s*(\d+)\s+(checks|cases|pass|sites|scripts)', 'tokens');
    if ~isempty(tot) && isempty(note), note = sprintf('%s/%s %s', tot{end}{:}); end
end

function out = run_isolated(f)
% Its own workspace; scripts that end on an error still throw from here.
    [~, nm] = fileparts(f);
    src = fileread(f);
    if ~isempty(regexp(src, ['^\s*function\s+(\w+\s*=\s*)?' nm '\>'], 'once', 'lineanchors'))
        out = evalc(nm);           % function file: call it
    else
        out = evalc('run(f)');     % script
    end
end

function restore_env(p, d, w)
    path(p); cd(d); warning(w);
end
