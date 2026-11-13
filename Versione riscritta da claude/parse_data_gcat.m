function d = parse_data_gcat(s)
%PARSE_DATA_GCAT  Converte date GCAT ("1957 Oct  4 1933?", "1983 Jan") in datenum.
%   Vettoriale su cellstr. Solo anno+mese -> giorno 15. Altro -> NaN.
%   Giorni fuori range (es. "Feb 30") fanno rollover come datetime di MATLAB.
if ischar(s), s = {s}; end
n_in = numel(s);
s = [s(:); {''}];   % elemento fittizio: regexp su cell 1x1 restituisce forme diverse in MATLAB/Octave
s = regexprep(strtrim(s), '\?$', '');
d = NaN(numel(s), 1);
MESI = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};

tok = regexp(s, '^(\d{4})\s+([A-Za-z]{3})\s+(\d{1,2})', 'tokens', 'once');
ok = ~cellfun('isempty', tok);
if any(ok)
    t = righe_token(tok(ok));              % m x 3
    [~, mese] = ismember(t(:,2), MESI);
    y = str2double(t(:,1)); g = str2double(t(:,3));
    v = datenum(y, max(mese,1), 1) + g - 1;
    v(mese == 0) = NaN;
    d(ok) = v;
end
rest = ~ok;
tok2 = regexp(s(rest), '^(\d{4})\s+([A-Za-z]{3})', 'tokens', 'once');
ok2 = ~cellfun('isempty', tok2);
if any(ok2)
    t = righe_token(tok2(ok2));
    [~, mese] = ismember(t(:,2), MESI);
    v = datenum(str2double(t(:,1)), max(mese,1), 15);
    v(mese == 0) = NaN;
    idx = find(rest);
    d(idx(ok2)) = v;
end
d = d(1:n_in);
end

function t = righe_token(tok)
% MATLAB restituisce i token come cell 1x3, Octave come 3x1: normalizziamo.
tok = cellfun(@(x) reshape(x, 1, []), tok, 'UniformOutput', false);
t = vertcat(tok{:});
end
