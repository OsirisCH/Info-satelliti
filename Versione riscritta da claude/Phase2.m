%% ========================================================================
%% FASE 2 - Kaplan-Meier: probabilita' osservata di restare in orbita S(t)
%% ========================================================================
% COSA FA: per ogni categoria stima S(t) = P(oggetto ancora in orbita dopo t
% anni dal lancio) con Kaplan-Meier, che gestisce la censura a destra (gli
% oggetti in orbita oggi contribuiscono con "almeno fino a oggi").
%
% CORREZIONI RISPETTO A Phase2.m
%  - Stessa popolazione delle altre fasi (catena ricorsiva, veicoli con
%    destino ignoto esclusi, Guowang corretto).
%  - Categorie FINALI (terzili OtherLEO) invece di un OtherLEO unico: prima la
%    Fase 2 mostrava un OtherLEO che conteneva anche equipaggio e oggetti
%    senza massa, mentre le fasi successive usavano i terzili.
%  - Intervalli di confidenza al 95% (Greenwood, scala log-log): senza IC non
%    si puo' dire se due curve sono diverse.
%  - S(t) riportata solo dove ci sono dati (oltre l'ultima eta' osservata e'
%    n.d., non l'ultimo valore trascinato).
%  - KM anche per gli strati OtherLEO (terzile x fascia di perigeo), che sono
%    l'unita' usata per i fit (motivazione in Fase 3).
%  - Kaplan-Meier implementato in km_sopravvivenza.m: niente Statistics
%    Toolbox, stesso risultato di ecdf(...,'function','survivor').

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
fprintf('Popolazione valida: %d oggetti (%d eventi)\n', P.n, sum(P.evento));

TEMPI = [1 3 5 10 20];
gruppi = [cfg.CATEGORIE(1:9), strcat(repmat(cfg.OTHERLEO, 1, 2), '_', ...
          [repmat(cfg.BANDE(1), 1, 3), repmat(cfg.BANDE(2), 1, 3)])];
campo = [repmat({'categoria'}, 1, 9), repmat({'strato'}, 1, 6)];

fprintf('\n%-26s %6s %6s %6s %6s', 'Gruppo', 'n', 'eventi', 'cens', 't_max');
fprintf('   S(%d) [IC95]      ', TEMPI); fprintf('\n');
for g = 1:numel(gruppi)
    s = strcmp(P.(campo{g}), gruppi{g});
    du = P.durata(s); ev = P.evento(s);
    fprintf('%-26s %6d %6d %6d %6.1f', gruppi{g}, sum(s), sum(ev), sum(ev == 0), max([du; 0]));
    if sum(ev) < cfg.MIN_EVENTI_FIT
        fprintf('   <- troppo pochi eventi: S(t) non stimabile in modo affidabile\n'); continue
    end
    [t, S, lo, hi] = km_sopravvivenza(du, ev);
    for k = 1:numel(TEMPI)
        x = TEMPI(k);
        if x > max(du), fprintf('   %-18s', 'n.d.');
        else, fprintf('   %.3f [%.3f-%.3f]', S_km_a(t, S, x), S_km_a(t, lo, x), S_km_a(t, hi, x)); end
    end
    fprintf('\n');

    h = nuova_figura(cfg, ['F2_KM_' gruppi{g}]);
    stairs([0; t], [1; S], 'LineWidth', 2, 'Color', [0.23 0.43 0.66]); hold on;
    stairs([0; t], [1; lo], ':', 'Color', [0.23 0.43 0.66]);
    stairs([0; t], [1; hi], ':', 'Color', [0.23 0.43 0.66]);
    xlabel('Eta'' (anni)'); ylabel('S(t)'); ylim([0 1.02]); xlim([0 max(du)]);
    title(sprintf('Kaplan-Meier - %s (n=%d, eventi=%d)', gruppi{g}, sum(s), sum(ev)), 'Interpreter', 'none');
    legend({'KM', 'IC 95%'}, 'Location', 'southwest'); grid on; hold off;
    salva_figura(cfg, h);
end
fprintf('\nLettura: Starlink V1 e gli strati OtherLEO hanno abbastanza eventi per\n');
fprintf('una stima affidabile. Starlink V2 ha eventi solo nei primi ~3 anni.\n');
fprintf('Kuiper, OneWeb, Guowang, Qianfan: la curva NON e'' stimabile dai dati ->\n');
fprintf('nelle proiezioni sara'' un''assunzione dichiarata (vedi Fase 4).\n');
