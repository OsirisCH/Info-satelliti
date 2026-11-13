%% ========================================================================
%% FASE 1b - Andamento storico dei rientri per anno (conteggio)
%% ========================================================================
% COSA FA: conta i rientri osservati per anno solare e per categoria, dal
% primo rientro fino a OGGI. E' il controllo di sanita' della pipeline.
%
% CORREZIONI RISPETTO A Phase1b.m
%  - Stessa popolazione di tutte le altre fasi (prepara_popolazione):
%    catena ricorsiva, esclusione dei veicoli con destino ignoto, Guowang.
%  - L'anno in corso e' marcato come PARZIALE (fino a OGGI) in tabella e nei
%    grafici, per non leggerlo come un calo.
%  - Anche la categoria 'Altro' (equipaggio PH, massa ignota) e' mostrata:
%    prima i suoi rientri entravano nel totale ma in nessuna categoria.

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
CAT = cfg.CATEGORIE;

ev = P.evento == 1;
v = datevec(P.decay(ev)); anno_r = v(:, 1);
cat_r = P.categoria(ev);
vo = datevec(P.OGGI); anno_oggi = vo(1);
anni = (min(anno_r):anno_oggi)';
cont = zeros(numel(anni), numel(CAT));
for c = 1:numel(CAT)
    ar = anno_r(strcmp(cat_r, CAT{c}));
    cont(:, c) = accumarray(ar - anni(1) + 1, 1, [numel(anni) 1]);
end
tot = sum(cont, 2);

fprintf('Rientri osservati (popolazione valida): %d, dal %d al %s\n', sum(ev), anni(1), datestr(P.OGGI, 1));
stampa_tabella('RIENTRI PER ANNO E CATEGORIA (ultimo anno parziale)', anni, cont, CAT, '%10d');
[pv, ip] = max(tot(1:end-1));
fprintf('\nPicco storico (anni completi): %d rientri nel %d\n', pv, anni(ip));
fprintf('%d (parziale, fino al %s): %d rientri\n', anno_oggi, datestr(P.OGGI, 1), tot(end));

h = nuova_figura(cfg, 'F1b_rientri_totali');
bar(anni(1:end-1), tot(1:end-1), 'FaceColor', [0.23 0.43 0.66], 'EdgeColor', 'none'); hold on;
bar(anni(end), tot(end), 'FaceColor', [0.75 0.80 0.88], 'EdgeColor', 'none');
xlabel('Anno'); ylabel('Numero di rientri');
xlim([anni(1)-1 anni(end)+1]);
title(sprintf('Rientri per anno - tutte le categorie (%d parziale al %s)', anno_oggi, datestr(P.OGGI, 1)));
grid on; hold off;
salva_figura(cfg, h);

for c = 1:numel(CAT)
    if sum(cont(:, c)) == 0
        fprintf('Nota: %s non ha rientri osservati.\n', CAT{c}); continue
    end
    h = nuova_figura(cfg, ['F1b_' CAT{c}]);
    bar(anni(1:end-1), cont(1:end-1, c), 'FaceColor', [0.30 0.55 0.35], 'EdgeColor', 'none'); hold on;
    bar(anni(end), cont(end, c), 'FaceColor', [0.70 0.82 0.72], 'EdgeColor', 'none');
    xlabel('Anno'); ylabel('Numero di rientri');
    title(sprintf('%s - rientri per anno (totale %d; %d parziale)', CAT{c}, sum(cont(:, c)), anno_oggi), 'Interpreter', 'none');
    grid on; hold off;
    salva_figura(cfg, h);
end
