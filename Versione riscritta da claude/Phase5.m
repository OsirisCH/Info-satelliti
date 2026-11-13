%% ========================================================================
%% FASE 5 - Applicazione delle curve allo stock in orbita OGGI
%% (quanti dei satelliti gia' in orbita rientrano ogni anno fino al 2050)
%% ========================================================================
% COSA FA: per ogni oggetto ancora in orbita, con la sua eta' reale a, la
% probabilita' di rientrare nell'anno j sapendo che e' in orbita oggi e'
%    p_j = [S(a + b_j) - S(a + b_j+1)] / S(a)
% (sopravvivenza condizionata). Somma su oggetti -> numero atteso di rientri;
% somma di massa_i * p_j -> massa attesa.
%
% CORREZIONI RISPETTO A Phase5c.m
%  1. Curve non piu' copiate a mano: vengono da curve_sopravvivenza.m (gli
%     stessi dati di Fase 4).
%  2. Stock corretto: niente piu' Progress/Soyuz/Shuttle "in orbita"; Guowang
%     con i suoi 203 satelliti (prima 26).
%  3. OtherLEO: ogni oggetto usa la curva del SUO strato (terzile x fascia di
%     perigeo), non una curva unica per terzile.
%  4. Anni SOLARI: il primo intervallo va da OGGI al 31/12 (parziale). Prima
%     "2026" era in realta' 14/9/2026-14/9/2027.
%  5. Massa attesa con la massa REALE di ogni oggetto in orbita (prima: numero
%     x massa mediana di classe, in Fase 7).
%  6. Costellazioni ad alta quota (OneWeb, Guowang, Qianfan): solo la frazione
%     PMD dei satelliti ritirati rientra; gli altri restano in orbita oltre il
%     2050. Prima rientrava il 100% per costruzione.
%  7. Moduli di stazione: rientro deterministico (ISS nel 2031, Tiangong oltre
%     il 2050), non una curva statistica.
%  8. Tre scenari (basso/centrale/alto) da config_analisi.m.

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
G = griglia_anni(cfg, P.OGGI);
CV = curve_sopravvivenza(P, cfg);
CAT = cfg.CATEGORIE; i_rif = find(strcmp(cfg.SCENARI, cfg.SCENARIO_RIF));

fprintf('Stock in orbita al %s: %d oggetti\n', datestr(P.OGGI, 1), sum(P.evento == 0));
fprintf('Primo intervallo: dal %s al 31/12/%d (%.2f anni)\n', datestr(P.OGGI, 1), G.anni(1), G.durata(1));

RS = cell(1, numel(cfg.SCENARI));
for i = 1:numel(cfg.SCENARI)
    RS{i} = proiezione_stock(P, CV, cfg, G, i);
end
R = RS{i_rif};

%% ---- curve usate, estese oltre i dati (una figura per categoria) --------
for c = 1:9
    cls = CAT{c};
    s = strcmp(P.categoria, cls);
    h = nuova_figura(cfg, ['F5_curva_' cls]);
    hold on; leg = {};
    if sum(P.evento(s)) > 0
        [t, S] = km_sopravvivenza(P.durata(s), P.evento(s));
        stairs([0; t], [1; S], 'k-', 'LineWidth', 1.5); leg{end+1} = 'Kaplan-Meier (dati)';
    end
    tg = linspace(0.01, 30, 300);
    if any(strcmp(cls, cfg.OTHERLEO))
        for b = 1:2
            st = [cls '_' cfg.BANDE{b}];
            plot(tg, S_modello(CV.modelli.(st), tg), '--', 'LineWidth', 2);
            leg{end+1} = sprintf('curva usata, perigeo %s (%s)', cfg.BANDE{b}, CV.modelli.(st).fam); %#ok<SAGROW>
        end
    else
        for i = 1:numel(cfg.SCENARI)
            m = modello_mega(CV, cfg, cls, i);
            plot(tg, S_modello(m, tg), '--', 'LineWidth', 1 + (i == i_rif));
            leg{end+1} = sprintf('curva usata (%s)', cfg.SCENARI{i}); %#ok<SAGROW>
            if strcmp(cls, 'Starlink_V1'), break; end
        end
    end
    tmax = max(P.durata(s));
    plot([tmax tmax], [0 1.02], ':', 'Color', [0.5 0.5 0.5]); leg{end+1} = 'fine dati osservati';
    xlabel('Eta'' (anni)'); ylabel('S(t)'); ylim([0 1.02]); xlim([0 30]); grid on;
    title(sprintf('%s - dati osservati e curva usata per la proiezione', cls), 'Interpreter', 'none');
    legend(leg, 'Location', 'northeast', 'Interpreter', 'none'); hold off;
    salva_figura(cfg, h);
end

%% ---- tabelle -----------------------------------------------------------
stampa_tabella(sprintf('RIENTRI ATTESI DALLO STOCK (scenario %s; %d parziale)', cfg.SCENARIO_RIF, G.anni(1)), ...
    G.anni', R.cont, CAT, '%10.1f');

fprintf('\n%-18s %10s %14s %16s %14s\n', 'Categoria', 'Stock oggi', 'Rientri <=2050', 'In orbita >2050', 'Massa stock t');
for c = 1:numel(CAT)
    fprintf('%-18s %10d %14.1f %11.1f (%3.0f%%) %12.1f\n', CAT{c}, R.n_stock(c), sum(R.cont(:, c)), ...
        R.rimasti(c), 100 * R.rimasti(c) / max(R.n_stock(c), 1), R.massa_stock(c) / 1000);
end
fprintf('%-18s %10d %14.1f %16.1f %14.1f\n', 'TOTALE', sum(R.n_stock), sum(R.cont(:)), sum(R.rimasti), sum(R.massa_stock) / 1000);
if R.non_proiettati > 0
    fprintf('Nota: %d oggetti di categoria Altro (massa ignota/equipaggio) non proiettati.\n', R.non_proiettati);
end
fprintf('Controllo di bilancio: stock - rientri - rimasti = %.2e (deve essere ~0)\n', ...
    sum(R.n_stock) - sum(R.cont(:)) - sum(R.rimasti));

fprintf('\nScenari (stock attuale):\n');
for i = 1:numel(cfg.SCENARI)
    fprintf('  %-9s rientri entro il %d: %8.0f   massa %8.0f t\n', cfg.SCENARI{i}, cfg.ANNO_FINE, ...
        sum(RS{i}.cont(:)), sum(RS{i}.massa(:)) / 1000);
end

%% ---- grafici -----------------------------------------------------------
h = nuova_figura(cfg, 'F5_stock_totale');
bar(G.anni, sum(R.cont, 2), 'FaceColor', [0.70 0.30 0.20], 'EdgeColor', 'none'); hold on;
plot(G.anni, sum(RS{1}.cont, 2), 'k:', G.anni, sum(RS{3}.cont, 2), 'k--');
legend({'centrale', 'basso', 'alto'}); xlabel('Anno'); ylabel('Numero atteso di rientri');
title(sprintf('Rientri attesi dallo stock attuale (n=%d), nessun nuovo lancio', sum(R.n_stock)));
grid on; hold off; salva_figura(cfg, h);
for c = 1:numel(CAT)
    if R.n_stock(c) == 0 || sum(R.cont(:, c)) == 0, continue; end
    h = nuova_figura(cfg, ['F5_stock_' CAT{c}]);
    bar(G.anni, R.cont(:, c), 'FaceColor', [0.25 0.50 0.65], 'EdgeColor', 'none');
    xlabel('Anno'); ylabel('Numero atteso di rientri'); grid on;
    title(sprintf('%s - rientri attesi dallo stock (n=%d; %.0f%% in orbita dopo il %d)', CAT{c}, ...
        R.n_stock(c), 100 * R.rimasti(c) / R.n_stock(c), cfg.ANNO_FINE), 'Interpreter', 'none');
    salva_figura(cfg, h);
end

save(fullfile(cfg.CARTELLA, 'fase5_risultati.mat'), 'RS', 'G', 'CAT', '-v7');
fprintf('\nSalvato: fase5_risultati.mat\n');
