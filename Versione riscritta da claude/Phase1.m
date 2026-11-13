%% ========================================================================
%% FASE 1 - Analisi a cascata del catalogo e costruzione della popolazione
%% payload -> LEO -> categorie -> destino (Status) -> popolazione valida
%% ========================================================================
% COSA FA: spiega da dove viene la popolazione usata in tutte le fasi
% successive (che chiamano la stessa funzione prepara_popolazione), con il
% dettaglio di ogni esclusione.
%
% CORREZIONI RISPETTO A Phase1_correct.m
%  1. Catena degli ospiti RICORSIVA (risolvi_ospite.m). Prima si guardava solo
%     il primo ospite: Progress -> Kvant (ATT) -> Mir (R, 2001) restava "in
%     orbita". Con un solo livello: 121 recuperati; con la ricorsione: 186.
%  2. Oggetti in fase chiusa con destino non ricostruibile dal satcat
%     (veicoli visitatori sganciati, ospite nel catalogo A non caricato):
%     ESCLUSI, non censurati. Prima 523 oggetti (Progress, Soyuz, Shuttle,
%     Dragon...) restavano nello stock "in orbita" con eta' mediana 14 anni.
%     Con auxcat.txt nella cartella vengono risolti anche questi.
%  3. Guowang: i satelliti operativi (nome "WHDW", bus "Xingwang C/CL/S/Y")
%     finivano in OtherLEO_pesante. Ora 204 oggetti invece di 27.
%  4. Moduli di stazione (Type con "MU": ISS e Tiangong) in una categoria a
%     parte, con rientro deterministico.
%  5. Data di censura = data di aggiornamento del catalogo (2a riga del
%     file), non una data scritta a mano.
%  6. Nessuna regola duplicata: tutto sta in prepara_popolazione.m.

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
L = D.L;

fprintf('Catalogo aggiornato al: %s   (data di censura OGGI = %s)\n', datestr(D.data_catalogo, 1), datestr(P.OGGI, 1));
fprintf('Auxcat (catalogo A) caricato: %d\n\n', D.auxcat_caricato);
fprintf('[1] Righe nel catalogo:                 %6d\n', D.n_catalogo);
fprintf('[2] Payload:                            %6d\n', D.n_payload);
fprintf('[3] Payload in LEO:                     %6d\n', D.n_leo);

% ---- sottorbite --------------------------------------------------------
[u, ~, j] = unique(L.OpOrbit); c = accumarray(j, 1);
[c, o] = sort(c, 'descend'); u = u(o);
fprintf('\n    Payload LEO per sottorbita:\n');
for k = 1:numel(u), fprintf('    %-8s %6d\n', u{k}, c(k)); end

% ---- categorie (prima del taglio in terzili) ---------------------------
fprintf('\n[4] Payload LEO per categoria (tutti, prima delle esclusioni):\n');
[u, ~, j] = unique(L.categoria); c = accumarray(j, 1);
for k = 1:numel(u), fprintf('    %-16s %6d\n', u{k}, c(k)); end
gw = strcmp(L.categoria, 'Guowang');
fprintf('    di cui Guowang riconosciuti per bus "Xingwang*"/nome "WHDW": %d (prima finivano in OtherLEO)\n', ...
    sum(gw & (strncmp(L.Bus, 'Xingwang', 8) | strncmp(upper(L.Name), 'WHDW', 4))));

% ---- destino (Status) --------------------------------------------------
fprintf('\n[5] Destino dei payload LEO\n');
fprintf('    Rientrati con data (R/D/AR):                         %6d\n', sum(L.evento & ~L.da_catena & ~L.escluso));
fprintf('    Rientrati recuperati dalla catena degli ospiti:      %6d\n', sum(L.da_catena & ~L.escluso));
fprintf('    In orbita (censurati a OGGI):                        %6d\n', sum(~L.evento & ~L.escluso));
fprintf('    Esclusi:                                             %6d\n', sum(L.escluso));
[u, ~, j] = unique(L.motivo(L.escluso)); c = accumarray(j, 1);
for k = 1:numel(u), fprintf('        %-34s %6d\n', u{k}, c(k)); end
fprintf('    Popolazione valida:                                  %6d  (eventi %d, censurati %d)\n', ...
    P.n, sum(P.evento), sum(P.evento == 0));

% ---- fase chiusa: dettaglio della risoluzione --------------------------
fc = ~cellfun('isempty', L.fc_esito);
fprintf('\n[6] Oggetti in "fase chiusa" (DK, GRP, ATT, TFR, N, ...): %d\n', sum(fc));
esiti = {'evento','escluso','orbita','ignoto'};
st_fc = unique(L.Status(fc));
fprintf('    %-8s', 'Status'); fprintf('%10s', esiti{:}); fprintf('\n');
for s = 1:numel(st_fc)
    fprintf('    %-8s', st_fc{s});
    for e = 1:numel(esiti), fprintf('%10d', sum(fc & strcmp(L.Status, st_fc{s}) & strcmp(L.fc_esito, esiti{e}))); end
    fprintf('\n');
end
irr = strcmp(L.motivo, 'fase_chiusa_irrisolta');
fprintf('    Irrisolti ed esclusi: %d, di cui ospite nel catalogo A (manca auxcat.txt): %d\n', ...
    sum(irr), sum(irr & strncmp(L.Dest, 'A', 1)));
% massa ablativa che il satcat da solo non permette di datare (cargo)
cargo = irr & strncmp(L.Type, 'PP', 2) & ~cellfun('isempty', regexp(L.Type, 'V'));
m_c = L.DryMass(cargo); m_c(isnan(m_c)) = 0;
fprintf('    Veicoli cargo irrisolti (Progress, Tianzhou, ATV, HTV, Cygnus...): %d, massa %.0f t\n', sum(cargo), sum(m_c)/1000);
fprintf('    -> rientri distruttivi reali che mancano allo storico: va dichiarato\n');
fprintf('       (o recuperato caricando auxcat.txt).\n');

% ---- composizione finale -----------------------------------------------
fprintf('\n[7] Popolazione valida per categoria finale (terzili OtherLEO: Q1=%.1f kg, Q2=%.1f kg)\n', P.Q1, P.Q2);
fprintf('    %-18s %7s %7s %7s %10s %10s\n', 'Categoria', 'n', 'eventi', 'stock', 'peri>600', 'massa nota');
for k = 1:numel(cfg.CATEGORIE)
    s = strcmp(P.categoria, cfg.CATEGORIE{k});
    fprintf('    %-18s %7d %7d %7d %9.0f%% %9.0f%%\n', cfg.CATEGORIE{k}, sum(s), sum(P.evento(s)), ...
        sum(s & P.evento == 0), 100*mean(P.perigeo(s) > cfg.SOGLIA_PERIGEO_KM), 100*mean(~isnan(P.massa(s))));
end
fprintf('\nNota: il campo Perigee di GCAT e'' l''orbita all''epoca ODate (di solito\n');
fprintf('quella di inserimento): Starlink ~270 km invece dei ~550 operativi.\n');
