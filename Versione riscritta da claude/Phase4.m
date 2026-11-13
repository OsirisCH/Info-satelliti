%% ========================================================================
%% FASE 4 - Curve parametriche (Weibull, Lognormale, e versioni "cure")
%% per estrapolare S(t) oltre i dati osservati
%% ========================================================================
% COSA FA: Kaplan-Meier descrive S(t) solo dove ci sono dati. Per proiettare
% al 2050 serve una forma funzionale. Per ogni strato si stimano per massima
% verosimiglianza (con censura) quattro modelli e si sceglie quello con AIC
% minimo:
%   Weibull, Lognormale                       (2 parametri)
%   Weibull-cure, Lognormale-cure             (3 parametri)
%   S(t) = (1-p) + p*S0(t): una frazione p rientra secondo S0, la frazione
%   1-p non rientra nell'orizzonte considerato (oggetti in quota alta).
%
% CORREZIONI RISPETTO A Phase4.m
%  1. Strati OtherLEO = terzile x fascia di perigeo (motivazione in Fase 3).
%  2. Modelli "cure": la lognormale con sigma 3-4 della versione precedente
%     stava imitando una popolazione mista (una parte rientra in pochi anni,
%     una parte mai). Con i modelli cure l'AIC migliora di centinaia di punti.
%  3. Scelta per AIC con il DeltaAIC dichiarato: per OtherLEO_pesante la
%     differenza Weibull/Lognormale era 0,8 punti di BIC, cioe' nessun vincitore.
%  4. Ottimizzazione robusta: parametri non vincolati, piu' punti di partenza,
%     riavvio di fminsearch, log S della lognormale stabile (erfcx).
%  5. I parametri NON vanno piu' copiati a mano nelle fasi successive:
%     Fase 5-7 chiamano la stessa curve_sopravvivenza.m (stessi dati -> stessi
%     parametri). Prima Fase 5-7 usavano valori di una vecchia esecuzione.
%  6. Starlink V2: oltre al fit "ingenuo" (2 parametri, inaffidabile), stima
%     della vita mediana con la forma di V1 FISSATA (1 solo parametro, con
%     IC 95% da profilo di verosimiglianza). E' la base dello scenario 'basso'
%     di config_analisi.m (7,0 anni) e mostra che i 5,5 anni del centrale
%     sono un'assunzione prudente, non un dato.

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);
CV = curve_sopravvivenza(P, cfg);
TEMPI = [1 5 10 20 40];

%% ---- tabella dei fit per strato ----------------------------------------
strati = fieldnames(CV.fit);
fprintf('%-26s %6s %6s | %10s %10s %10s %10s | %-16s\n', 'Strato', 'n', 'eventi', ...
    'dAIC Weib', 'dAIC Logn', 'dAIC W-cure', 'dAIC L-cure', 'Scelto');
fprintf('%s\n', repmat('-', 1, 112));
for k = 1:numel(strati)
    M = CV.fit.(strati{k}); ib = CV.best.(strati{k});
    aic = [M.aic]; da = aic - min(aic);
    fprintf('%-26s %6d %6d |', strati{k}, M(1).n, M(1).eventi);
    for j = 1:4
        if j <= numel(M), fprintf(' %10.1f', da(j)); else, fprintf(' %10s', '-'); end
    end
    fprintf(' | %-16s\n', M(ib).fam);
end
fprintf('(dAIC = AIC - AIC minimo; < 2 = modelli indistinguibili, > 10 = differenza netta)\n');

fprintf('\nParametri dei modelli scelti:\n');
for k = 1:numel(strati)
    M = CV.fit.(strati{k}); m = M(CV.best.(strati{k}));
    switch m.fam
        case 'weibull',         d = sprintf('k=%.3f  lambda=%.2f anni', m.par);
        case 'lognormale',      d = sprintf('mu=%.3f  sigma=%.3f  (mediana %.1f anni)', m.par, exp(m.par(1)));
        case 'weibull_cure',    d = sprintf('k=%.3f  lambda=%.2f  frazione che rientra p=%.3f', m.par);
        case 'lognormale_cure', d = sprintf('mu=%.3f  sigma=%.3f  frazione che rientra p=%.3f', m.par);
    end
    fprintf('  %-26s %-16s %s\n', strati{k}, m.fam, d);
end
fprintf('\nForma Weibull di riferimento (Starlink V1): k = %.4f\n', CV.k_V1);

%% ---- confronto KM / modello scelto + grafici -----------------------------
fprintf('\nAderenza ai dati: S(t) Kaplan-Meier vs modello scelto\n');
fprintf('%-26s', 'Strato'); fprintf('      t=%-2d KM / mod', TEMPI); fprintf('\n');
stili = {'-', '--', '-.', ':'}; col = lines(4);
for k = 1:numel(strati)
    M = CV.fit.(strati{k}); ib = CV.best.(strati{k});
    s = strcmp(P.strato, strati{k});
    if sum(P.evento(s)) < cfg.MIN_EVENTI_FIT, s = strcmp(P.categoria, regexprep(strati{k}, '_(bassa|alta)$', '')); end
    [t, S] = km_sopravvivenza(P.durata(s), P.evento(s)); tmax = max(P.durata(s));
    fprintf('%-26s', strati{k});
    for x = TEMPI
        fprintf('   %13s', strrep(sprintf('%.3f/%.3f', S_km_a(t, S, x, tmax), S_modello(M(ib), x)), 'NaN', ' n.d.'));
    end
    fprintf('\n');
    h = nuova_figura(cfg, ['F4_fit_' strati{k}]);
    stairs([0; t], [1; S], 'k-', 'LineWidth', 1.5); hold on;
    tg = linspace(0.01, max(tmax * 1.2, 30), 400);
    leg = {'Kaplan-Meier'};
    for j = 1:numel(M)
        lw = 1 + 1.5*(j == ib);
        plot(tg, S_modello(M(j), tg), stili{j}, 'Color', col(j, :), 'LineWidth', lw);
        leg{end+1} = sprintf('%s (dAIC %.0f)%s', M(j).fam, M(j).aic - M(ib).aic, repmat(' *', 1, j == ib)); %#ok<SAGROW>
    end
    plot([tmax tmax], [0 1.02], ':', 'Color', [0.5 0.5 0.5]);
    leg{end+1} = 'fine dati osservati';
    xlabel('Eta'' (anni)'); ylabel('S(t)'); ylim([0 1.02]); grid on;
    title(sprintf('%s - KM e modelli parametrici (* = scelto)', strati{k}), 'Interpreter', 'none');
    legend(leg, 'Location', 'northeast', 'Interpreter', 'none'); hold off;
    salva_figura(cfg, h);
end

%% ---- costellazioni giovani: cosa dicono (e non dicono) i dati -----------
fprintf('\n--- Costellazioni con pochi rientri: vita mediana stimata a k = k_V1 fissato ---\n');
fprintf('(lambda MLE in forma chiusa: lambda = (sum t^k / eventi)^(1/k); IC95 da profilo)\n');
fprintf('%-14s %7s %8s %12s %22s %16s\n', 'Classe', 'eventi', 't_max', 'mediana', 'IC 95%', 'centrale config');
k = CV.k_V1; f = log(2)^(1/k);
for c = {'Starlink_V1', 'Starlink_V2', 'Kuiper', 'OneWeb', 'Guowang', 'Qianfan'}
    s = strcmp(P.categoria, c{1}); t = P.durata(s); e = P.evento(s); d = sum(e);
    if d == 0
        fprintf('%-14s %7d %8.1f %12s\n', c{1}, d, max(t), 'non stimabile'); continue
    end
    lam = (sum(t.^k) / d)^(1/k);
    ll = @(L) sum(e .* (log(k) - log(L) + (k-1)*(log(t) - log(L)))) - sum((t/L).^k);
    g = @(x) ll(lam) - ll(exp(x)) - 1.92;
    lo = exp(fzero(g, [log(lam) - 5, log(lam)])); hi = exp(fzero(g, [log(lam), log(lam) + 5]));
    conf = '-';
    if isfield(cfg.VITA_MEDIANA, c{1}), conf = sprintf('%.1f', cfg.VITA_MEDIANA.(c{1})(2)); end
    fprintf('%-14s %7d %8.1f %9.2f a   [%6.2f - %6.2f] a %16s\n', c{1}, d, max(t), lam*f, lo*f, hi*f, conf);
end
fprintf('Attenzione: con t_max piccolo (V2: 3,4 anni) la mediana e'' FUORI dai dati e\n');
fprintf('dipende interamente dalla forma k presa da V1. Kuiper (6 eventi) e OneWeb\n');
fprintf('(2 eventi, 1.200 km) non sono informativi: restano assunzioni.\n');

% Starlink V2: KM, fit ingenuo, curve degli scenari
s = strcmp(P.categoria, 'Starlink_V2');
[t, S] = km_sopravvivenza(P.durata(s), P.evento(s));
Mi = fit_sopravvivenza(P.durata(s), P.evento(s), {'weibull'});
fprintf('\nStarlink V2, fit ingenuo a 2 parametri: k=%.3f lambda=%.1f (mediana %.1f anni) -> NON usato:\n', ...
    Mi.par, Mi.par(2) * log(2)^(1/Mi.par(1)));
fprintf('con 3,4 anni di dati la forma non e'' identificabile (k~1,2 contro 2,2 di V1).\n');
h = nuova_figura(cfg, 'F4_Starlink_V2_assunzioni');
stairs([0; t], [1; S], 'k-', 'LineWidth', 1.8); hold on;
tg = linspace(0.01, 15, 300);
plot(tg, S_modello(Mi, tg), ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 2);
leg = {'Kaplan-Meier', 'fit ingenuo 2 par. (non usato)'};
cs = [0.2 0.6 0.3; 0.23 0.43 0.66; 0.75 0.2 0.2];
for i = 1:3
    plot(tg, S_modello(modello_mega(CV, cfg, 'Starlink_V2', i), tg), '--', 'Color', cs(i, :), 'LineWidth', 2);
    leg{end+1} = sprintf('scenario %s: mediana %.1f anni', cfg.SCENARI{i}, cfg.VITA_MEDIANA.Starlink_V2(i)); %#ok<SAGROW>
end
xlabel('Eta'' (anni)'); ylabel('S(t)'); ylim([0 1.02]); grid on;
title('Starlink V2 - dati osservati e curve assunte (forma k di V1)');
legend(leg, 'Location', 'southwest'); hold off;
salva_figura(cfg, h);

save(fullfile(cfg.CARTELLA, 'fase4_risultati.mat'), 'CV', '-v7');
fprintf('\nSalvato: fase4_risultati.mat (solo per consultazione: le fasi 5-7 ristimano\n');
fprintf('le curve con curve_sopravvivenza.m, cosi'' non possono mai restare indietro).\n');
