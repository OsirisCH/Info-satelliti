function [P, D] = prepara_popolazione(cfg)
%PREPARA_POPOLAZIONE  Lettura, classificazione e popolazione di analisi.
%   Unico punto in cui sono scritte le regole sulla popolazione (prima erano
%   copiate in 7 script e andavano corrette 7 volte).
%
%   P : popolazione valida per la sopravvivenza (una riga per oggetto)
%       .evento (1 rientrato, 0 censurato a OGGI), .durata (anni),
%       .massa (kg, NaN se ignota), .perigeo (km), .categoria, .banda, .strato
%   D : diagnostica (tutti i payload LEO, motivo di esclusione, conteggi)
%
%   Regole:
%   1) payload (Type che inizia per 'P') con OpOrbit contenente 'LEO'
%   2) evento = Status R/D/AR con data di rientro <= OGGI
%   3) esclusi = Status in ST_ESCLUSI (atterrati, esplosi, ...) e Status
%      R/D/AR senza data (anomali)
%   4) Status di "fase chiusa" (DK, GRP, ATT, TFR, ...): catena dell'ospite
%      seguita RICORSIVAMENTE fino a un oggetto con destino noto:
%        - ospite finale rientrato -> evento alla sua data
%        - ospite finale escluso   -> escluso
%        - nessun ospite (Dest '-') -> l'oggetto vola libero: censurato
%        - modulo di stazione (Type con 'MU') -> in orbita con la stazione
%        - altrimenti (veicolo visitatore sganciato, ospite nel catalogo A non
%          caricato, ospite ancora in orbita) -> destino NON ricostruibile
%          dal satcat: ESCLUSO, non censurato. Censurarlo vorrebbe dire
%          affermare che un Progress del 2011 e' ancora in orbita.
%   5) categoria: costellazioni per nome/bus (Guowang anche per bus
%      'Xingwang*' / nome 'WHDW'), moduli di stazione, OtherLEO per terzile
%      di massa; PH (equipaggio) e oggetti senza massa -> 'Altro'
%   6) strato di sopravvivenza: per OtherLEO terzile x fascia di perigeo.

C = leggi_catalogo_gcat(cfg.FILE_SATCAT);
if isempty(cfg.OGGI)
    OGGI = C.data_catalogo;
else
    OGGI = cfg.OGGI;
    if OGGI > C.data_catalogo
        warning('OGGI (%s) e'' successiva alla data del catalogo (%s)', datestr(OGGI), datestr(C.data_catalogo));
    end
end

%% ---- lookup per gli ospiti (satcat + auxcat opzionale) -----------------
LK.JCAT = C.JCAT; LK.Status = C.Status; LK.decay = C.decay; LK.Dest = C.Dest;
D.auxcat_caricato = false;
if exist(cfg.FILE_AUXCAT, 'file') == 2
    A = leggi_catalogo_gcat(cfg.FILE_AUXCAT);
    LK.JCAT = [LK.JCAT; A.JCAT]; LK.Status = [LK.Status; A.Status];
    LK.decay = [LK.decay; A.decay]; LK.Dest = [LK.Dest; A.Dest];
    D.auxcat_caricato = true;
end
[uj, iu] = unique(LK.JCAT, 'stable');
LK.map = containers.Map(uj, num2cell(iu));

%% ---- payload LEO ---------------------------------------------------------
is_payload = strncmp(C.Type, 'P', 1);
is_leo = ~cellfun('isempty', strfind(C.OpOrbit, 'LEO'));
sel = find(is_payload & is_leo);
campi = {'JCAT','Name','Type','Status','Dest','Bus','State','OpOrbit','LDate','DDate'};
for k = 1:numel(campi), L.(campi{k}) = C.(campi{k})(sel); end
L.launch = C.launch(sel); L.decay = C.decay(sel);
L.Mass = C.Mass_num(sel); L.DryMass = C.DryMass_num(sel);
L.perigeo = C.Perigee_num(sel); L.diametro = C.Diameter_num(sel);
n = numel(sel);
D.n_catalogo = C.n; D.n_payload = sum(is_payload); D.n_leo = n;
D.OGGI = OGGI; D.data_catalogo = C.data_catalogo;

%% ---- classificazione per costellazione ---------------------------------
L.categoria = classifica(L.Name, L.Bus, L.Type);

%% ---- Status, catena ricorsiva, esclusioni --------------------------------
st = L.Status;
ha_data = ~isnan(L.decay);
is_ev  = ismember(st, cfg.ST_EVENTO);
is_esc = ismember(st, cfg.ST_ESCLUSI);
is_fc  = ismember(st, cfg.ST_FASE_CHIUSA);
is_staz = strcmp(L.categoria, 'Stazioni');

evento = is_ev & ha_data;
motivo = repmat({''}, n, 1);
motivo(is_esc) = {'status_escluso'};
motivo(is_ev & ~ha_data) = {'anomalo_evento_senza_data'};
fc_esito = repmat({''}, n, 1);
da_catena = false(n, 1);
for i = reshape(find(is_fc), 1, [])
    [esito, dh] = risolvi_ospite(L.Dest{i}, LK, cfg);
    fc_esito{i} = esito;
    if strcmp(esito, 'evento')
        evento(i) = true; L.decay(i) = dh; da_catena(i) = true;
    elseif strcmp(esito, 'escluso')
        motivo{i} = 'fase_chiusa_ospite_escluso';
    elseif is_staz(i) || strcmp(L.Dest{i}, '-')
        % modulo di stazione o oggetto senza ospite: in orbita (censurato)
    else
        motivo{i} = 'fase_chiusa_irrisolta';
    end
end
% rientri successivi a OGGI (se OGGI e' scelta prima della data del catalogo)
dopo = evento & L.decay > OGGI;
evento(dopo) = false;
% date incoerenti
fine = OGGI * ones(n, 1); fine(evento) = L.decay(evento);
durata = (fine - L.launch) / 365.25;
motivo(cellfun('isempty', motivo) & ~(durata > 0)) = {'date_incoerenti'};
escluso = ~cellfun('isempty', motivo);

L.evento = evento; L.durata = durata; L.motivo = motivo; L.fc_esito = fc_esito;
L.da_catena = da_catena; L.escluso = escluso;
D.L = L;
D.n_fase_chiusa = sum(is_fc);
D.fc_esiti = fc_esito(is_fc);
D.n_catena = sum(da_catena);
D.n_escluso = sum(escluso);

%% ---- popolazione valida -------------------------------------------------
v = ~escluso;
P.OGGI = OGGI;
f = {'JCAT','Name','Type','Status','Dest','Bus','State','launch','decay','perigeo','diametro','categoria','da_catena'};
for k = 1:numel(f), P.(f{k}) = L.(f{k})(v); end
P.evento = double(L.evento(v)); P.durata = L.durata(v);
P.decay(P.evento == 0) = NaN;   % per i censurati DDate non e' un rientro (es. data di aggancio)
m = L.DryMass(v); manca = isnan(m) | m <= 0; mt = L.Mass(v); m(manca) = mt(manca);
m(m <= 0) = NaN;
P.massa = m;
P.n = sum(v);

%% ---- terzili di massa per OtherLEO ------------------------------------
is_o = strcmp(P.categoria, 'OtherLEO');
is_ph = strncmp(P.Type, 'PH', 2);
con_m = is_o & ~is_ph & ~isnan(P.massa);
Q = quantile_matlab(P.massa(con_m), [1/3 2/3]);
P.Q1 = Q(1); P.Q2 = Q(2);
cg = P.categoria;
cg(con_m & P.massa <= P.Q1) = {'OtherLEO_leggero'};
cg(con_m & P.massa > P.Q1 & P.massa <= P.Q2) = {'OtherLEO_medio'};
cg(con_m & P.massa > P.Q2) = {'OtherLEO_pesante'};
cg(is_o & ~con_m) = {'Altro'};
cg(strcmp(cg, 'Starlink_altro')) = {'Altro'};
P.categoria = cg;

%% ---- fascia di perigeo e strato di sopravvivenza -----------------------
P.banda = repmat({'bassa'}, P.n, 1);
P.banda(P.perigeo > cfg.SOGLIA_PERIGEO_KM) = {'alta'};
P.strato = P.categoria;
is_ot = ismember(P.categoria, cfg.OTHERLEO);
P.strato(is_ot) = strcat(P.categoria(is_ot), '_', P.banda(is_ot));
P.strato(ismember(P.categoria, {'Stazioni','Altro'})) = {''};
D.n_perigeo_mancante = sum(isnan(P.perigeo));
end

%% ========================================================================
function cg = classifica(nome, bus, tipo)
n = numel(nome);
cg = repmat({'OtherLEO'}, n, 1);
N = upper(nome);
has = @(c, p) ~cellfun('isempty', strfind(c, p));
is_sl = has(N, 'STARLINK');
cg(is_sl) = {'Starlink_altro'};
cg(is_sl & strcmp(bus, 'Starlink')) = {'Starlink_V1'};
cg(is_sl & ismember(bus, {'Starlink V2M','Starlink V2MO','Starlink V2MD'})) = {'Starlink_V2'};
r = ~is_sl;
cg(r & has(N, 'ONEWEB')) = {'OneWeb'};
r = r & ~has(N, 'ONEWEB');
k = r & (has(N, 'KUIPER') | has(bus, 'Kuiper'));
cg(k) = {'Kuiper'}; r = r & ~k;
% CORREZIONE: i satelliti operativi Guowang si chiamano "WHDW xx-yy" e hanno
% bus "Xingwang C/CL/S/Y"; prima finivano in OtherLEO_pesante.
g = r & (has(N, 'XINGWANG') | strcmp(bus, 'ZXW') | strncmp(bus, 'Xingwang', 8) | strncmp(N, 'WHDW', 4));
cg(g) = {'Guowang'}; r = r & ~g;
q = r & (has(N, 'QIANFAN') | has(N, 'SPACESAIL') | has(N, 'G60'));
cg(q) = {'Qianfan'}; r = r & ~q;
cg(r & has(tipo, 'MU')) = {'Stazioni'};      % moduli di stazione (ISS, Tiangong)
end
