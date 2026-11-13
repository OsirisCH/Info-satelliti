function stampa_tabella(titolo, righe, M, colonne, fmt, con_totale)
%STAMPA_TABELLA  Tabella anni x categorie in command window.
%   righe: vettore (anni) o cellstr; M: nrighe x ncol; colonne: cellstr
if nargin < 5 || isempty(fmt), fmt = '%10.1f'; end
if nargin < 6, con_totale = true; end
w = 10;
fprintf('\n=== %s ===\n', titolo);
fprintf('%-8s', 'Anno');
for c = 1:numel(colonne), fprintf(['%' num2str(w) 's'], abbrevia(colonne{c}, w-1)); end
if con_totale, fprintf(['%' num2str(w+2) 's'], 'TOTALE'); end
fprintf('\n');
for r = 1:size(M, 1)
    if iscell(righe), fprintf('%-8s', righe{r}); else, fprintf('%-8d', righe(r)); end
    fprintf(fmt, M(r, :));
    if con_totale, fprintf(['  ' fmt], sum(M(r, :))); end
    fprintf('\n');
end
fprintf('%-8s', 'Somma'); fprintf(fmt, sum(M, 1));
if con_totale, fprintf(['  ' fmt], sum(M(:))); end
fprintf('\n');
end

function s = abbrevia(s, n)
s = strrep(s, 'OtherLEO_', 'OL_');
s = strrep(s, 'Starlink_', 'SL_');
if numel(s) > n, s = s(1:n); end
end
