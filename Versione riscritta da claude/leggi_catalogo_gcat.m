function C = leggi_catalogo_gcat(file, usa_cache)
%LEGGI_CATALOGO_GCAT  Legge un catalogo GCAT (satcat.txt / auxcat.txt, TSV).
%   C = leggi_catalogo_gcat(file) restituisce una struct con un campo per
%   colonna (cellstr, gia' strtrim), piu':
%     C.launch, C.decay     date come datenum (NaN se assenti/non parsabili)
%     C.<col>_num           per Mass, DryMass, Perigee, Apogee, Diameter, Inc
%     C.data_catalogo       datenum della riga "# Updated ..."
%     C.n                   numero di righe
%   La lettura e' vettoriale (nessun ciclo su 70.000 righe). Se usa_cache e'
%   vero, il risultato grezzo viene salvato in <file>.cache.mat e riletto
%   finche' il file sorgente non cambia (data e dimensione). La cache contiene
%   SOLO il parsing, nessuna regola di analisi, quindi non puo' diventare
%   "vecchia" rispetto al codice di analisi.
if nargin < 2, usa_cache = true; end
info = dir(file);
if isempty(info), error('File non trovato: %s', file); end
cache = [file '.cache.mat'];
if usa_cache && exist(cache, 'file') == 2
    S = load(cache);
    if isfield(S, 'firma') && isequal(S.firma, [info.datenum info.bytes 2])
        C = S.C; return
    end
end

txt = fileread(file);
righe = regexp(txt, '\r?\n', 'split');
header = righe{1};
nomi = strtrim(strsplit(header, sprintf('\t')));
nomi{1} = strrep(nomi{1}, '#', '');
ncol = numel(nomi);

% data di aggiornamento (2a riga: "# Updated 2026 Sep 21 0845:40")
C.data_catalogo = NaN;
tok = regexp(righe{2}, 'Updated\s+(\d{4}\s+[A-Za-z]{3}\s+\d{1,2})', 'tokens', 'once');
if ~isempty(tok), C.data_catalogo = parse_data_gcat(tok(1)); end

righe = righe(3:end);
righe = righe(~cellfun('isempty', righe));
campi = regexp(righe, '\t', 'split');
nf = cellfun(@numel, campi);
for i = reshape(find(nf ~= ncol), 1, [])
    c = campi{i};
    if numel(c) < ncol, c(end+1:ncol) = {''}; else, c = c(1:ncol); end
    campi{i} = c;
end
M = vertcat(campi{:});           % n x ncol cell
C.n = size(M, 1);
for k = 1:ncol
    C.(nomi{k}) = strtrim(M(:, k));
end
C.colonne = nomi;
C.launch = parse_data_gcat(C.LDate);
C.decay  = parse_data_gcat(C.DDate);
num = {'Mass','DryMass','Perigee','Apogee','Diameter','Inc'};
for k = 1:numel(num)
    if isfield(C, num{k}), C.([num{k} '_num']) = parse_numero_gcat(C.(num{k})); end
end
if usa_cache
    firma = [info.datenum info.bytes 2]; %#ok<NASGU>
    save(cache, 'C', 'firma', '-v7');
end
end
