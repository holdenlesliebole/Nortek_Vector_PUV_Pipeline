function s = tex_label(label)
% TEX_LABEL  Render instrument labels with proper TeX subscripting.
%
%   tex_label('MOP580_7m')  →  'MOP580_{7m}'
%   tex_label('MOP586_5m')  →  'MOP586_{5m}'
%
% MATLAB's default 'tex' interpreter only subscripts the single character
% after '_'. This wraps the trailing token in braces so the full depth
% suffix renders as a subscript.
%
% Cell-array input returns a cell array; struct field-name input is fine
% because no '_' regex is needed for plain strings without underscores.
% Author: Holden Leslie-Bole, 2026

if iscell(label)
    s = cellfun(@tex_label, label, 'UniformOutput', false);
    return
end
if isstring(label) && numel(label) > 1
    s = arrayfun(@tex_label, label);
    return
end

label = char(label);
s = regexprep(label, '_(\w+)$', '_{$1}');
end
