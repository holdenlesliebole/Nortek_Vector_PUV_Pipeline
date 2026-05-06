% SMOKE_TEST  Verify headline output .mat files load cleanly with the
% fields downstream code expects. Run before committing/pushing.
% Author: Holden Leslie-Bole, 2026

fprintf('\n=== Smoke test: headline aggregate outputs ===\n');
% After May 2026 rename: mean_flow/ holds canonical 1-hour analysis,
% mean_flow_17min/ holds the legacy 17-min Phase 2 archive.
checks = { ...
    'outputs/validation/mean_flow/_aggregate/phase2_summary.mat',          {'summary'}, {'deployment','label','alpha','beta'};
    'outputs/validation/mean_flow_17min/_aggregate/phase2_summary.mat',    {'summary'}, {'deployment','label','alpha','beta'};
    'outputs/validation/mean_flow/_aggregate/robustness_summary.mat',      {'results'}, {'deployment','label','alpha_u_60','alpha_v_60'};
    'outputs/validation/mean_flow/_aggregate/wave_direction_check.mat',    {'results'}, {'deployment','label','alpha_v0','alpha_v1'};
    'outputs/validation/mean_flow/_aggregate/mean_flow_timeseries.mat',    {'records'}, {'deployment','label','time','uMean','vMean'} };

allOK = true;
for k = 1:size(checks,1)
    f = checks{k,1}; topVars = checks{k,2}; subFields = checks{k,3};
    if ~isfile(f)
        fprintf('  MISSING: %s\n', f); allOK = false; continue
    end
    S = load(f);
    fprintf('  %s\n', f);
    for v = topVars
        if ~isfield(S, v{1})
            fprintf('    MISSING top-level: %s\n', v{1}); allOK = false; continue
        end
        x = S.(v{1});
        for fld = subFields
            if isstruct(x) && isfield(x, fld{1}) || (isstruct(x) && numel(x)>0 && isfield(x(1), fld{1}))
                fprintf('    OK   .%s.%s\n', v{1}, fld{1});
            else
                fprintf('    MISSING field: .%s.%s\n', v{1}, fld{1}); allOK = false;
            end
        end
    end
end

fprintf('\n=== Smoke test result: %s ===\n', ternary(allOK, 'PASS', 'FAIL'));

function s = ternary(b, a, c)
if b, s = a; else, s = c; end
end
