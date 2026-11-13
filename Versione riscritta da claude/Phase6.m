%% ========================================================================
%% FASE 6 - Lanci futuri (OGGI-2050) e rientri dei SOLI nuovi lanciati
%% ========================================================================
% COSA FA: (A) quanti satelliti verranno lanciati ogni anno, per categoria;
% (B) quanti di QUESTI rientreranno ogni anno, applicando la stessa curva
% di ritiro/rientro a ciascuna coorte di lancio (eta' 0 al lancio).
%
% CORREZIONI RISPETTO A Phase6_correct.m
%  1. Modello stock-flusso per le costellazioni (proiezione_nuovi.m):
%     lanci(j) = quanto serve per seguire la popolazione obiettivo P*(t),
%     tenendo conto dei ritiri di stock e coorti precedenti.
%     Prima: (a) nessuna sostituzione prima di y_full (la popolazione
%     implicita di V2 arrivava a 25.900 nel 2032 invece di 33.200);
%     (b) il 2026 ricontava come "nuovi" i satelliti gia' in orbita (4.135
%     lanci V2 contro i 1.695 reali, gia' nello stock); (c) l'asintoto non era
%     il target (Qianfan 11.568 invece di 15.000); (d) un crollo artificiale
%     dei lanci nel 2031 e un salto nel 2032.
%  2. Niente formula stock/vita_mediana. Con k~2,2 media/mediana = 1,047,
%     quindi dividere per la mediana SOVRASTIMAVA (non sottostimava) la
%     sostituzione del ~5%. Il modello stock-flusso la calcola direttamente.
%  3. Target e anni di completamento in tre scenari, motivati in
%     config_analisi.m (autorizzazioni FCC/ITU e ritmo di lancio osservato).
%     Lo scenario centrale precedente (34.000 V2, 15.000 Qianfan al 2030) era
%     sopra l'autorizzato o incompatibile con il ritmo osservato.
%  4. PMD: per le costellazioni oltre ~800 km rientra solo la frazione PMD dei
%     satelliti ritirati.
%  5. OtherLEO: tasso per strato (terzile x fascia di perigeo), senza Guowang
%     (prima ~27 lanci/anno di Guowang erano contati due volte, dentro il
%     tasso di OtherLEO_pesante); nel 2026 solo la parte di anno dopo OGGI.
%  6. Coorti lanciate a meta' intervallo (eta' media 0,5 anni a fine anno),
%     non a inizio anno.

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
G = griglia_anni(cfg, P.OGGI);
CV = curve_sopravvivenza(P, cfg);
CAT = cfg.CATEGORIE; i_rif = find(strcmp(cfg.SCENARI, cfg.SCENARIO_RIF));
NEW = [cfg.MEGA, cfg.OTHERLEO]; iN = cellfun(@(x) find(strcmp(CAT, x)), NEW);

NS = cell(1, numel(cfg.SCENARI));
for i = 1:numel(cfg.SCENARI)
    NS{i} = proiezione_nuovi(P, CV, cfg, G, i);
end
N = NS{i_rif};

%% ---- (A) lanci -----------------------------------------------------------
fprintf('Ipotesi di buildout (scenario %s):\n', cfg.SCENARIO_RIF);
for k = 1:numel(cfg.MEGA)
    c = cfg.MEGA{k};
    fprintf('  %-12s stock oggi %5d -> target %6d entro fine %d, vita mediana %.1f anni, PMD %.2f\n', c, ...
        sum(strcmp(P.categoria, c) & P.evento == 0), cfg.COST.(c).target(i_rif), cfg.COST.(c).y_full(i_rif), ...
        cfg.VITA_MEDIANA.(c)(i_rif), cfg.PMD.(c)(i_rif));
end
fprintf('  OtherLEO: tasso medio di lancio %d-%d per strato\n', cfg.ANNI_TASSO{i_rif}(1), cfg.ANNI_TASSO{i_rif}(end));

stampa_tabella(sprintf('NUOVI LANCI PER ANNO (scenario %s; %d solo dopo il %s)', cfg.SCENARIO_RIF, ...
    G.anni(1), datestr(P.OGGI, 1)), G.anni', N.lanci(:, iN), NEW, '%10.0f');

fprintf('\nControllo stock-flusso (costellazioni, fine 2030 / 2040 / 2050):\n');
fprintf('%-12s %26s %26s %26s\n', '', 'obiettivo / modello 2030', 'obiettivo / modello 2040', 'obiettivo / modello 2050');
for k = 1:numel(cfg.MEGA)
    c = find(strcmp(CAT, cfg.MEGA{k}));
    fprintf('%-12s', cfg.MEGA{k});
    for y = [2030 2040 2050]
        j = find(G.anni == y);
        fprintf('%26s', sprintf('%7.0f / %7.0f', N.pop_obiettivo(j, c), N.pop_modello(j, c)));
    end
    fprintf('\n');
end

%% ---- (B) rientri dei nuovi lanciati -----------------------------------
stampa_tabella(sprintf('RIENTRI ATTESI - SOLO NUOVI LANCIATI (scenario %s)', cfg.SCENARIO_RIF), ...
    G.anni', N.cont(:, iN), NEW, '%10.1f');

fprintf('\n%-18s %16s %18s %14s\n', 'Categoria', 'Lanciati <=2050', 'Rientrati <=2050', 'massa/sat kg');
for k = 1:numel(NEW)
    c = iN(k);
    fprintf('%-18s %16.0f %12.0f (%3.0f%%) %14.0f\n', NEW{k}, sum(N.lanci(:, c)), sum(N.cont(:, c)), ...
        100 * sum(N.cont(:, c)) / max(sum(N.lanci(:, c)), 1), N.massa_unitaria(c));
end
fprintf('%-18s %16.0f %18.0f\n', 'TOTALE', sum(N.lanci(:)), sum(N.cont(:)));

fprintf('\nScenari (solo nuovi lanciati):\n');
for i = 1:numel(cfg.SCENARI)
    fprintf('  %-9s lanci %8.0f   rientri %8.0f   massa rientrata %8.0f t\n', cfg.SCENARI{i}, ...
        sum(NS{i}.lanci(:)), sum(NS{i}.cont(:)), sum(NS{i}.massa(:)) / 1000);
end

%% ---- grafici -----------------------------------------------------------
h = nuova_figura(cfg, 'F6_lanci_totali');
bar(G.anni, sum(N.lanci, 2), 'FaceColor', [0.20 0.45 0.25], 'EdgeColor', 'none'); hold on;
plot(G.anni, sum(NS{1}.lanci, 2), 'k:', G.anni, sum(NS{3}.lanci, 2), 'k--', 'LineWidth', 1.2);
legend({'centrale', 'basso', 'alto'}, 'Location', 'northwest');
xlabel('Anno'); ylabel('Nuovi satelliti lanciati'); grid on; hold off;
title(sprintf('Nuovi lanci per anno - totale (%d parziale)', G.anni(1)));
salva_figura(cfg, h);

for k = 1:numel(cfg.MEGA)
    c = find(strcmp(CAT, cfg.MEGA{k}));
    h = nuova_figura(cfg, ['F6_' cfg.MEGA{k}]);
    subplot(2, 1, 1);
    plot(G.anni, N.pop_obiettivo(:, c), 'k-', 'LineWidth', 2); hold on;
    plot(G.anni, N.pop_modello(:, c), 'r--', 'LineWidth', 1.5);
    for i = [1 3], plot(G.anni, NS{i}.pop_obiettivo(:, c), ':', 'Color', [0.5 0.5 0.5]); end
    ylabel('Satelliti in servizio'); grid on; hold off;
    legend({'obiettivo (centrale)', 'popolazione del modello', 'basso / alto'}, 'Location', 'southeast');
    title(sprintf('%s - popolazione, lanci e rientri', cfg.MEGA{k}), 'Interpreter', 'none');
    subplot(2, 1, 2);
    bar(G.anni, N.lanci(:, c), 'FaceColor', [0.25 0.50 0.65], 'EdgeColor', 'none'); hold on;
    plot(G.anni, N.cont(:, c), 'r-', 'LineWidth', 2);
    legend({'lanci', 'rientri dei nuovi'}, 'Location', 'northwest');
    xlabel('Anno'); ylabel('Satelliti/anno'); grid on; hold off;
    salva_figura(cfg, h);
end

h = nuova_figura(cfg, 'F6_rientri_nuovi_totali');
bar(G.anni, sum(N.cont, 2), 'FaceColor', [0.70 0.30 0.20], 'EdgeColor', 'none'); hold on;
plot(G.anni, sum(NS{1}.cont, 2), 'k:', G.anni, sum(NS{3}.cont, 2), 'k--', 'LineWidth', 1.2);
legend({'centrale', 'basso', 'alto'}, 'Location', 'northwest');
xlabel('Anno'); ylabel('Numero atteso di rientri'); grid on; hold off;
title('Rientri attesi - solo nuovi lanciati');
salva_figura(cfg, h);

save(fullfile(cfg.CARTELLA, 'fase6_risultati.mat'), 'NS', 'G', 'CAT', '-v7');
fprintf('\nSalvato: fase6_risultati.mat\n');
