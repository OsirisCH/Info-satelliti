function v = parse_numero_gcat(s)
%PARSE_NUMERO_GCAT  "  7790 ", "84?", "-" -> double (NaN se assente). Vettoriale.
if ischar(s), s = {s}; end
v = str2double(regexprep(strtrim(s(:)), '\?$', ''));
end
