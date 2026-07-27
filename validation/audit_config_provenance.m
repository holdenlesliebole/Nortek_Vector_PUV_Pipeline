% AUDIT_CONFIG_PROVENANCE  Check that every site-geometry value in a config
% carries a source on its own line, and flag the ones that do not.
%
%   MOTIVATION. Four config headers asserted that field data "is not recorded
%   for these years" or was "a placeholder — fill from notes before running L2".
%   Every one was wrong: the data was sitting in a DeploymentNotes /
%   SoCal_instruments workbook the whole time, and L1-L4 had been built on the
%   placeholder for months.
%
%     Cardiff, Coronado   "doffp is not recorded for these years"  -> it was
%     Catalina            "fill from notes before running L2"      -> never done;
%                         also a 21.9 km lat/lon error, unset serial
%     TorreyOffshore      0.63 m is real, but carried back across 2014-2019
%
%   WHY THIS IS LINE-ORIENTED. A first version of this audit scanned the whole
%   config header for words like "placeholder". That fails in both directions:
%   it flagged a header that merely *described* a placeholder it had already
%   fixed, and it could not tell a measured 0.75 m from a default 0.75 m. The
%   check that actually works is per-line: does the assignment carry a comment
%   naming where the number came from?
%
%   Each geometry value is classified from its own trailing comment:
%     SOURCED       cites a measurement or a workbook -- "cm above sand",
%                   "from notes", "surveyed", a DeploymentNotes/SoCal filename
%     PLACEHOLDER   says so -- "placeholder", "typical", "verify from",
%                   "fill from", "approximate", "program-typical", "carried"
%     UNANNOTATED   no comment at all: provenance unknown, which is the state
%                   that let all four cases above survive
%
%   CONVENTION THIS ENFORCES. Put the source on the line:
%       cfg.instruments(k).doffp = 0.71;   % m, port 71cm above sand (S/N 15032)
%   not in a header paragraph that will not age with the value.
%
%   This is a LINT, not a gate. UNANNOTATED is not proof of a bad value -- it
%   means nobody can tell without reopening the workbook.
%
%   Run from PUV_Pipeline/:
%     >> run validation/audit_config_provenance

startup_puv;

cfgDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'config');
% Scope: the values that actually caused trouble. serialNum is unambiguous
% and heading=NaN is a legitimate default (auto-compute from the .sen compass).
FIELDS = {'doffp','latlon','shorenormal'};

SOURCED = {'cm above','above sand','below sand','from notes','deploymentnotes', ...
           'socal_instruments','surveyed','per notes','s/n','field log','notes)', ...
           'measured','deployment notes','xls','see header','at deployment', ...
           'on recovery','set per deployment','auto-compute','auto from', ...
           'data-derived','station frame'};
PLACE   = {'placeholder','typical','verify from','fill from','approximate', ...
           'program-typical','refine from','pending','carried from','not recorded', ...
           'assumed','guess','eyeball'};

files = dir(fullfile(cfgDir, '*_config.m'));
files = files(~startsWith({files.name}, 'TEMPLATE'));

fprintf('\n%-26s %-13s %-9s %s\n', 'config', 'field', 'state', 'line');
fprintf('%s\n', repmat('-', 1, 110));

nS = 0; nP = 0; nU = 0;
placeList = {}; unannList = {};

for i = 1:numel(files)
    fname = files(i).name;
    txt   = fileread(fullfile(cfgDir, fname));
    lines = strsplit(txt, newline);
    for L = 1:numel(lines)
        ln = lines{L};
        if startsWith(strtrim(ln), '%'), continue, end     % pure comment line
        for f = 1:numel(FIELDS)
            pat = ['\.' FIELDS{f} '\s*='];
            if isempty(regexp(ln, pat, 'once')), continue, end

            cpos = strfind(ln, '%');
            comment = ''; if ~isempty(cpos), comment = lower(ln(cpos(1):end)); end

            if isempty(strtrim(comment))
                state = 'UNANNOT'; nU = nU + 1;
                unannList{end+1} = sprintf('%s : %s', fname, strtrim(ln)); %#ok<SAGROW>
            elseif any(cellfun(@(p) contains(comment, p), PLACE))
                state = 'PLACEHLD'; nP = nP + 1;
                placeList{end+1} = sprintf('%s : %s', fname, strtrim(ln)); %#ok<SAGROW>
            elseif any(cellfun(@(p) contains(comment, p), SOURCED))
                state = 'sourced'; nS = nS + 1;
            else
                state = 'UNANNOT'; nU = nU + 1;
                unannList{end+1} = sprintf('%s : %s', fname, strtrim(ln)); %#ok<SAGROW>
            end

            if ~strcmp(state, 'sourced')
                shown = strtrim(ln); if numel(shown) > 62, shown = [shown(1:59) '...']; end
                fprintf('%-26s %-13s %-9s %s\n', fname, FIELDS{f}, state, shown);
            end
        end
    end
end

fprintf('\n%d sourced | %d declared placeholder | %d unannotated\n', nS, nP, nU);

fprintf('\nDECLARED PLACEHOLDERS (%d) — the value itself says it is provisional:\n', nP);
for i = 1:numel(placeList), fprintf('  %s\n', placeList{i}); end
if isempty(placeList), fprintf('  none\n'); end

fprintf('\nUNANNOTATED (%d) — provenance unknown; add the source to the line:\n', nU);
for i = 1:numel(unannList), fprintf('  %s\n', unannList{i}); end
if isempty(unannList), fprintf('  none\n'); end

fprintf(['\nSee config/DOFFP_LOOKUP_CHECKLIST.md for where to look and how to match\n' ...
         '(serial AND deployment ordinal AND season -- serials are reused across years).\n\n']);
