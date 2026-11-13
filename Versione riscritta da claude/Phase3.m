%% ========================================================================
%% FASE 3 - Che cosa determina la sopravvivenza di OtherLEO?
%% massa, perigeo, area/massa -> come stratificare le curve
%% ========================================================================
% COSA FA: su OtherLEO (terzili con massa, perigeo e diametro noti) misura
% l'effetto di massa, perigeo e rapporto area/massa sulla probabilita' di
% rientro, e ne ricava come suddividere OtherLEO per stimare le curve.
%
% CORREZIONI RISPETTO A Phase3.m
%  1. Diagnostica del confondimento: le MEDIANE del perigeo per terzile
%     (497/543/524 km) sembravano simili, ma le CODE no. La quota di oggetti
%     sopra 600 km e' 5% (leggeri), 34% (medi), 45% (pesanti). Sopra quella
%     quota S(t) resta ~1 per decenni in ogni terzile: i "plateau" di medi e
%     pesanti sono in gran parte un effetto della quota.
%     -> le curve si stimano per terzile x fascia di perigeo (<=600 / >600 km).
%  2. Verifica dell'ipotesi di rischi proporzionali (PH) di Cox: HR stimati
%     su finestre di eta' (0-2, 2-10, >10 anni, con troncamento a sinistra).
%     Se l'HR cambia con l'eta', il singolo HR "medio" non va interpretato
%     come effetto costante.
%  3. Interpretazione fisica corretta: a parita' di area/massa la
%     decelerazione da drag NON dipende dalla massa (a = 1/2 rho v^2 Cd A/m).
%     Un HR<1 per la massa a parita' di A/m segnala variabili non osservate
%     (propulsione e mantenimento d'orbita, tipo di missione, orbita reale vs
%     inserimento), non "inerzia".
%  4. Limite del dato: il campo Perigee e' l'orbita all'epoca ODate (di
%     solito quella di inserimento), e il diametro e' spesso una stima: errori
%     di misura che attenuano gli effetti. Va dichiarato.
%  5. Cox, Spearman e quantili senza Statistics Toolbox (cox_breslow.m,
%     rango_medio.m), verificati contro un'implementazione indipendente.

clear; clc;
cfg = config_analisi();
[P, D] = prepara_popolazione(cfg);

s = ismember(P.categoria, cfg.OTHERLEO);
area = pi * (P.diametro / 2).^2;
amr = area ./ P.massa;
ok = s & P.perigeo > 0 & isfinite(amr) & amr > 0;
du = P.durata(ok); ev = P.evento(ok); m = P.massa(ok); pe = P.perigeo(ok); am = amr(ok);
cat_ok = P.categoria(ok);
fprintf('OtherLEO con massa, perigeo e diametro noti: %d (eventi %d)\n', sum(ok), sum(ev));

lm = log10(m); la = log10(am);
fprintf('\nCorrelazione di Spearman:\n');
fprintf('  log(massa) vs perigeo:   %6.3f\n', corr_spearman(lm, pe));
fprintf('  log(massa) vs log(AMR):  %6.3f\n', corr_spearman(lm, la));
fprintf('  perigeo   vs log(AMR):   %6.3f\n', corr_spearman(pe, la));

%% ---- Cox ----------------------------------------------------------------
X = [lm, pe/100, la];
nomi = {'log10(massa)', 'perigeo (per 100 km)', 'log10(A/m)'};
R = cox_breslow(du, ev, X);
fprintf('\n--- Cox: massa + perigeo + area/massa (tutte le eta'') ---\n');
fprintf('%-22s %9s %9s %20s %10s\n', 'Variabile', 'coeff', 'HR', 'IC95 HR', 'p');
for k = 1:3
    fprintf('%-22s %9.4f %9.4f   [%7.4f - %7.4f] %10.3g\n', nomi{k}, R.b(k), R.HR(k), R.HR_lo(k), R.HR_hi(k), R.p(k));
end

fprintf('\n--- Verifica rischi proporzionali: HR per finestra di eta'' ---\n');
fin = [0 2; 2 10; 10 100];
fprintf('%-14s', 'Finestra'); fprintf('%24s', nomi{:}); fprintf('\n');
for w = 1:size(fin, 1)
    a0 = fin(w, 1); a1 = fin(w, 2);
    q = du > a0;
    tw = min(du(q), a1); ew = ev(q) & du(q) <= a1;
    Rw = cox_breslow(tw, ew, X(q, :), a0 * ones(sum(q), 1));
    fprintf('%3d-%-3d anni  ', a0, a1);
    for k = 1:3, fprintf('   %6.3f [%5.3f-%5.3f]', Rw.HR(k), Rw.HR_lo(k), Rw.HR_hi(k)); end
    fprintf('\n');
end
fprintf('Se gli HR cambiano molto tra finestre l''ipotesi PH non regge: il modello\n');
fprintf('di Cox serve qui solo come diagnostica (direzione e ordine di grandezza).\n');

%% ---- confondimento: distribuzione della quota per terzile ---------------
fprintf('\n--- Perigeo per terzile di massa (Q1=%.1f kg, Q2=%.1f kg) ---\n', P.Q1, P.Q2);
fprintf('%-18s %6s %8s %8s %8s %8s\n', 'Terzile', 'n', 'mediana', '>500km', '>600km', '>800km');
for c = 1:3
    q = strcmp(cat_ok, cfg.OTHERLEO{c});
    fprintf('%-18s %6d %8.0f %7.0f%% %7.0f%% %7.0f%%\n', cfg.OTHERLEO{c}, sum(q), median(pe(q)), ...
        100*mean(pe(q) > 500), 100*mean(pe(q) > 600), 100*mean(pe(q) > 800));
end
fprintf('Mediane simili NON bastano: conta la frazione in quota.\n');

%% ---- KM per terzile x fascia di quota -----------------------------------
fasce = [0 450; 450 600; 600 800; 800 1e5];
fprintf('\n--- KM per terzile x fascia di perigeo: S(10), S(25) ---\n');
fprintf('%-18s', 'Terzile'); for f = 1:size(fasce, 1), fprintf('%22s', sprintf('%g-%g km', fasce(f, 1), min(fasce(f, 2), 9999))); end; fprintf('\n');
for c = 1:3
    fprintf('%-18s', cfg.OTHERLEO{c});
    for f = 1:size(fasce, 1)
        q = strcmp(cat_ok, cfg.OTHERLEO{c}) & pe > fasce(f, 1) & pe <= fasce(f, 2);
        if sum(q) < 30 || sum(ev(q)) < 1, fprintf('%22s', sprintf('n=%d', sum(q))); continue; end
        [t, S] = km_sopravvivenza(du(q), ev(q));
        v10 = S_km_a(t, S, 10, max(du(q))); v25 = S_km_a(t, S, 25, max(du(q)));
        fprintf('%22s', strrep(sprintf('%.2f / %.2f (n=%d)', v10, v25, sum(q)), 'NaN', 'n.d.'));
    end
    fprintf('\n');
end
fprintf('-> Sopra 600 km S(t) resta alta per decenni in OGNI terzile: la quota\n');
fprintf('   spiega i plateau. Sotto 600 km la massa (cioe'' il coefficiente\n');
fprintf('   balistico) separa ancora le curve. Servono quindi entrambe:\n');
fprintf('   curve per terzile x fascia di perigeo (soglia %d km) in Fase 4-7.\n', cfg.SOGLIA_PERIGEO_KM);

colori = [0.23 0.43 0.66; 0.71 0.26 0.24; 0.30 0.62 0.44];
for c = 1:3
    h = nuova_figura(cfg, ['F3_KM_' cfg.OTHERLEO{c} '_per_quota']);
    hold on; leg = {};
    for b = 1:2
        q = strcmp(P.strato, [cfg.OTHERLEO{c} '_' cfg.BANDE{b}]);
        [t, S] = km_sopravvivenza(P.durata(q), P.evento(q));
        stairs([0; t], [1; S], 'LineWidth', 2, 'Color', colori(c, :) * (0.5 + 0.5*(b == 1)));
        segni = {'<=', '>'};
        leg{end+1} = sprintf('perigeo %s %d km (n=%d)', segni{b}, cfg.SOGLIA_PERIGEO_KM, sum(q)); %#ok<SAGROW>
    end
    xlabel('Eta'' (anni)'); ylabel('S(t)'); ylim([0 1.02]); grid on;
    title(sprintf('Kaplan-Meier - %s per fascia di perigeo', cfg.OTHERLEO{c}), 'Interpreter', 'none');
    legend(leg, 'Location', 'southwest'); hold off;
    salva_figura(cfg, h);
end
