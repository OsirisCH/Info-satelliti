function CV = curve_sopravvivenza(P, cfg)
%CURVE_SOPRAVVIVENZA  Stima (dai dati, ogni volta) le curve S(t) usate nelle
%   proiezioni. Nessun parametro e' scritto a mano: prima Fase 5-7 usavano
%   valori copiati da una vecchia esecuzione di Fase 4 (per OtherLEO_pesante
%   mu=4,93 / sigma=4,34 contro 4,56 / 4,10 della popolazione corretta).
%
%   CV.modelli.(strato) : modello scelto (min AIC) per ogni strato OtherLEO
%                         (terzile x fascia di perigeo) e per Starlink_V1
%   CV.fit.(strato)     : tutti i modelli stimati (per tabelle e grafici)
%   CV.k_V1             : forma Weibull di Starlink V1 (usata per le
%                         costellazioni giovani, vedi modello_mega)
CV = struct(); CV.modelli = struct(); CV.fit = struct(); CV.best = struct();

% ---- Starlink V1: Weibull (forma di riferimento per le costellazioni) ----
s = strcmp(P.strato, 'Starlink_V1');
[M, ib] = fit_sopravvivenza(P.durata(s), P.evento(s), {'weibull','lognormale'});
CV.fit.Starlink_V1 = M; CV.best.Starlink_V1 = ib;
CV.modelli.Starlink_V1 = M(1);            % Weibull (vince anche per AIC/BIC)
CV.k_V1 = M(1).par(1);

% ---- OtherLEO: un fit per terzile x fascia ------------------------------
for c = 1:numel(cfg.OTHERLEO)
    for b = 1:numel(cfg.BANDE)
        nome = [cfg.OTHERLEO{c} '_' cfg.BANDE{b}];
        s = strcmp(P.strato, nome);
        if sum(P.evento(s)) >= cfg.MIN_EVENTI_FIT
            [M, ib] = fit_sopravvivenza(P.durata(s), P.evento(s));
        else
            % troppo pochi eventi: si usa il terzile intero (entrambe le fasce)
            warning('%s: solo %d eventi, uso il fit del terzile intero', nome, sum(P.evento(s)));
            s2 = strcmp(P.categoria, cfg.OTHERLEO{c});
            [M, ib] = fit_sopravvivenza(P.durata(s2), P.evento(s2));
        end
        CV.fit.(nome) = M; CV.best.(nome) = ib;
        CV.modelli.(nome) = M(ib);
    end
end
end
