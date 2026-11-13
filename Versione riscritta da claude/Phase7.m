%% ========================================================================
%% FASE 7 - Rientri e massa rientrata: storico (dal 1957 a OGGI) +
%% proiezione (OGGI-2050) = stock attuale (Fase 5) + nuovi lanciati (Fase 6)
%% ========================================================================
% Quattro output, ognuno totale e per categoria, per i tre scenari:
%   (1) numero di rientri/anno, solo proiezione
%   (2) numero di rientri/anno, storico + proiezione
%   (3) massa rientrata/anno (t), solo proiezione
%   (4) massa rientrata/anno (t), storico + proiezione
%
% CORREZIONI RISPETTO A Phase7_correct.m
%  1. Massa attesa = numero x massa MEDIA (non mediana). Per una somma il
%     valore atteso e' n*E[m]: la mediana sottostima sistematicamente le classi
%     asimmetriche (OtherLEO_pesante: mediana 800 kg, media ~1.400-1.700 kg).
%     La mediana resta stampata accanto, come indicatore di dispersione.
%  2. Stock: massa REALE di ogni oggetto (Fase 5). Nuovi lanci: massa media
%     dei lanci dello stesso strato negli anni usati per il tasso (Fase 6).
%  3. Storico e proiezione con lo stesso stimatore (somme di masse reali o
%     attese), quindi confrontabili. Masse mancanti nello storico: imputate
%     con la media di categoria e contate (prima valevano 0).
%  4. Anno in corso = rientri osservati fino a OGGI + attesi fino al 31/12.
%     Prima lo storico si fermava al 2025 e la proiezione partiva dallo stock
%     al 14/9: i 621 rientri gen-set 2026 non comparivano da nessuna parte.
%  5. Rapporto storico/futuro calcolato sui TASSI annui (t/anno), non sui
%     totali di periodi di durata diversa (prima "37x", in realta' ~100x).
%  6. Tre scenari: il risultato e' un intervallo, non un numero solo.
%  7. Incluse le categorie Stazioni (ISS 2031) e Altro (solo storico).
%  Limite dichiarato: payload LEO soltanto (niente stadi dei razzi); veicoli
%  visitatori con destino non datato dal satcat esclusi (vedi Fase 1).

clear; clc; close all;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
G = griglia_anni(cfg, P.OGGI);
CV = curve_sopravvivenza(P, cfg);
CAT = cfg.CATEGORIE; nc = numel(CAT); NSC = numel(cfg.SCENARI);
i_rif = find(strcmp(cfg.SCENARI, cfg.SCENARIO_RIF));

%% ---- masse di riferimento per categoria ---------------------------------
fprintf('=== MASSA PER CATEGORIA (kg, oggetti con massa nota) ===\n');
fprintf('%-18s %8s %8s %6s %7s\n', 'Categoria', 'Media', 'Mediana', 'CV', 'n');
media_cat = zeros(1, nc);
for c = 1:nc
    m = P.massa(strcmp(P.categoria, CAT{c}) & ~isnan(P.massa));
    media_cat(c) = mean(m);
    fprintf('%-18s %8.1f %8.1f %6.2f %7d\n', CAT{c}, mean(m), median(m), std(m) / mean(m), numel(m));
end
fprintf('(Per il valore atteso della massa totale si usa la MEDIA.)\n');

%% ---- (A) STORICO REALE (fino a OGGI) -------------------------------------
ev = P.evento == 1;
v = datevec(P.decay(ev)); anno_r = v(:, 1);
cat_r = P.categoria(ev); m_r = P.massa(ev);
imputate = isnan(m_r) & ~strcmp(cat_r, 'Altro');
for c = 1:nc
    q = isnan(m_r) & strcmp(cat_r, CAT{c});
    if strcmp(CAT{c}, 'Altro'), m_r(q) = 0; else, m_r(q) = media_cat(c); end
end
anni_s = (min(anno_r):G.anno_oggi)';
NS_ = numel(anni_s);
cont_s = zeros(NS_, nc); massa_s = zeros(NS_, nc);
for c = 1:nc
    q = strcmp(cat_r, CAT{c});
    cont_s(:, c) = accumarray(anno_r(q) - anni_s(1) + 1, 1, [NS_ 1]);
    massa_s(:, c) = accumarray(anno_r(q) - anni_s(1) + 1, m_r(q), [NS_ 1]);
end
fprintf('\nStorico: %d rientri (%d-%s), %.0f t; masse imputate con la media di categoria: %d oggetti\n', ...
    sum(ev), anni_s(1), datestr(P.OGGI, 1), sum(massa_s(:)) / 1000, sum(imputate));
q = isnan(P.massa(ev)) & strcmp(cat_r, 'Altro');
if any(q), fprintf('         %d rientri di categoria Altro senza massa (non sommati)\n', sum(q)); end

%% ---- (B) PROIEZIONE = stock + nuovi, per scenario -----------------------
cont_p = cell(1, NSC); massa_p = cell(1, NSC); cont_stock = cell(1, NSC); cont_nuovi = cell(1, NSC);
for i = 1:NSC
    R = proiezione_stock(P, CV, cfg, G, i);
    N = proiezione_nuovi(P, CV, cfg, G, i);
    cont_stock{i} = R.cont; cont_nuovi{i} = N.cont;
    cont_p{i} = R.cont + N.cont;
    massa_p{i} = R.massa + N.massa;            % kg
end
Cp = cont_p{i_rif}; Mp = massa_p{i_rif};

%% ---- (C) SERIE COMPLETA: anno in corso = osservato + atteso -------------
anni_c = [anni_s(1:end-1); G.anni'];
completa = @(S, Pr) [S(1:end-1, :); S(end, :) + Pr(1, :); Pr(2:end, :)];
Cc = completa(cont_s, Cp); Mc = completa(massa_s, Mp);

%% ---- tabelle --------------------------------------------------------------
stampa_tabella(sprintf('(1) RIENTRI ATTESI %d-%d (stock + nuovi; scenario %s; %d = solo dopo OGGI)', ...
    G.anni(1), cfg.ANNO_FINE, cfg.SCENARIO_RIF, G.anni(1)), G.anni', Cp, CAT, '%10.1f');
stampa_tabella(sprintf('(3) MASSA RIENTRATA ATTESA %d-%d, tonnellate (scenario %s)', G.anni(1), cfg.ANNO_FINE, ...
    cfg.SCENARIO_RIF), G.anni', Mp / 1000, CAT, '%10.2f');

fprintf('\n=== SINTESI PER CATEGORIA ===\n');
fprintf('%-18s | %8s %9s | %26s | %26s\n', 'Categoria', 'Storico', 'Storico t', ...
    sprintf('Rientri OGGI-%d [b/c/a]', cfg.ANNO_FINE), sprintf('Massa t OGGI-%d [b/c/a]', cfg.ANNO_FINE));
for c = 1:nc
    fprintf('%-18s | %8d %9.0f | %8.0f %8.0f %8.0f | %8.0f %8.0f %8.0f\n', CAT{c}, sum(cont_s(:, c)), ...
        sum(massa_s(:, c)) / 1000, cellfun(@(x) sum(x(:, c)), cont_p), cellfun(@(x) sum(x(:, c)) / 1000, massa_p));
end
fprintf('%-18s | %8d %9.0f | %8.0f %8.0f %8.0f | %8.0f %8.0f %8.0f\n', 'TOTALE', sum(cont_s(:)), ...
    sum(massa_s(:)) / 1000, cellfun(@(x) sum(x(:)), cont_p), cellfun(@(x) sum(x(:)) / 1000, massa_p));

% tassi annui confrontabili
anni_compl = anni_s(1:end-1);                        % anni storici completi
v5 = anni_compl >= anni_compl(end) - 4;
fprintf('\n=== TASSI ANNUI (confrontabili) ===\n');
fprintf('Storico %d-%d (anni completi):  %7.0f rientri/anno  %7.0f t/anno\n', anni_compl(1), anni_compl(end), ...
    mean(sum(cont_s(1:end-1, :), 2)), mean(sum(massa_s(1:end-1, :), 2)) / 1000);
fprintf('Storico %d-%d:                  %7.0f rientri/anno  %7.0f t/anno\n', anni_compl(find(v5, 1)), anni_compl(end), ...
    mean(sum(cont_s(v5, :), 2)), mean(sum(massa_s(v5, :), 2)) / 1000);
pa = G.anni >= G.anno_oggi + 1;                      % anni di proiezione completi
for i = 1:NSC
    fprintf('Proiezione %d-%d (%-8s):   %7.0f rientri/anno  %7.0f t/anno\n', G.anni(find(pa, 1)), cfg.ANNO_FINE, ...
        cfg.SCENARI{i}, mean(sum(cont_p{i}(pa, :), 2)), mean(sum(massa_p{i}(pa, :), 2)) / 1000);
end
fprintf('Rapporto tra tassi di massa, proiezione centrale / ultimi 5 anni storici: %.1fx\n', ...
    mean(sum(Mp(pa, :), 2)) / mean(sum(massa_s(v5, :), 2)));
fprintf('Quota della massa proiettata (centrale) dovuta ai nuovi lanci: %.0f%%\n', ...
    100 * (1 - sum(sum(proiezione_stock(P, CV, cfg, G, i_rif).massa)) / sum(Mp(:))));

%% ========================================================================
%% GRAFICI
%% ========================================================================
lo = @(X) sum(X{1}, 2); hi = @(X) sum(X{3}, 2);
col_s = [0.35 0.35 0.35]; col_p = [0.70 0.30 0.20];
etich = {'conteggio', 'massa_t'};
for tipo = 1:2
    if tipo == 1
        Pc = cont_p; Sc = cont_s; Ccomp = Cc; yl = 'Numero di rientri'; f = 1;
    else
        Pc = cellfun(@(x) x / 1000, massa_p, 'UniformOutput', false); Sc = massa_s / 1000; Ccomp = Mc / 1000;
        yl = 'Massa rientrata (t)'; f = 1000;
    end
    % (1)/(3) solo proiezione, totale con stock/nuovi impilati
    h = nuova_figura(cfg, sprintf('F7_%d_proiezione_%s_TOTALE', 2*tipo - 1, etich{tipo}));
    if tipo == 1
        bar(G.anni, [sum(cont_stock{i_rif}, 2), sum(cont_nuovi{i_rif}, 2)], 'stacked', 'EdgeColor', 'none');
        leg = {'stock attuale', 'nuovi lanciati'};
    else
        bar(G.anni, sum(Pc{i_rif}, 2), 'FaceColor', col_p, 'EdgeColor', 'none'); leg = {'centrale'};
    end
    hold on; plot(G.anni, lo(Pc), 'k:', G.anni, hi(Pc), 'k--', 'LineWidth', 1.2);
    legend([leg, {'scenario basso', 'scenario alto'}], 'Location', 'northwest');
    xlabel('Anno'); ylabel(yl); grid on; hold off;
    title(sprintf('Proiezione %d-%d - totale (%d: solo dopo il %s)', G.anni(1), cfg.ANNO_FINE, G.anni(1), datestr(P.OGGI, 1)));
    salva_figura(cfg, h);
    % (2)/(4) storico + proiezione, totale
    h = nuova_figura(cfg, sprintf('F7_%d_storico_proiezione_%s_TOTALE', 2*tipo, etich{tipo}));
    ns = numel(anni_s) - 1;
    bar(anni_c(1:ns), sum(Ccomp(1:ns, :), 2), 'FaceColor', col_s, 'EdgeColor', 'none'); hold on;
    bar(anni_c(ns+1:end), sum(Ccomp(ns+1:end, :), 2), 'FaceColor', col_p, 'EdgeColor', 'none');
    bandlo = completa(Sc, Pc{1}); bandhi = completa(Sc, Pc{3});
    plot(anni_c(ns+1:end), sum(bandlo(ns+1:end, :), 2), 'k:', anni_c(ns+1:end), sum(bandhi(ns+1:end, :), 2), 'k--', 'LineWidth', 1.2);
    legend({'storico osservato', 'proiezione centrale', 'basso', 'alto'}, 'Location', 'northwest');
    xlabel('Anno'); ylabel(yl); grid on; xlim([anni_c(1) - 1, cfg.ANNO_FINE + 1]); hold off;
    title(sprintf('%s per anno - storico %d-%d + proiezione al %d', yl, anni_s(1), G.anno_oggi, cfg.ANNO_FINE));
    salva_figura(cfg, h);
    % per categoria
    for c = 1:nc
        if sum(Ccomp(:, c)) == 0, continue; end
        h = nuova_figura(cfg, sprintf('F7_%d_proiezione_%s_%s', 2*tipo - 1, etich{tipo}, CAT{c}));
        bar(G.anni, Pc{i_rif}(:, c), 'FaceColor', [0.25 0.50 0.65], 'EdgeColor', 'none'); hold on;
        plot(G.anni, Pc{1}(:, c), 'k:', G.anni, Pc{3}(:, c), 'k--');
        legend({'centrale', 'basso', 'alto'}, 'Location', 'northwest');
        xlabel('Anno'); ylabel(yl); grid on; hold off;
        title(sprintf('%s - proiezione %d-%d', CAT{c}, G.anni(1), cfg.ANNO_FINE), 'Interpreter', 'none');
        salva_figura(cfg, h);
        h = nuova_figura(cfg, sprintf('F7_%d_storico_proiezione_%s_%s', 2*tipo, etich{tipo}, CAT{c}));
        bar(anni_c(1:ns), Ccomp(1:ns, c), 'FaceColor', col_s, 'EdgeColor', 'none'); hold on;
        bar(anni_c(ns+1:end), Ccomp(ns+1:end, c), 'FaceColor', col_p, 'EdgeColor', 'none');
        xlabel('Anno'); ylabel(yl); grid on; xlim([anni_c(1) - 1, cfg.ANNO_FINE + 1]); hold off;
        legend({'storico', 'proiezione centrale'}, 'Location', 'northwest');
        title(sprintf('%s - storico + proiezione', CAT{c}), 'Interpreter', 'none');
        salva_figura(cfg, h);
    end
end

save(fullfile(cfg.CARTELLA, 'fase7_risultati.mat'), 'CAT', 'anni_s', 'cont_s', 'massa_s', 'G', ...
    'cont_p', 'massa_p', 'cont_stock', 'cont_nuovi', 'anni_c', 'Cc', 'Mc', 'media_cat', '-v7');
fprintf('\nSalvato: fase7_risultati.mat\n');
