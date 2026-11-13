function G = griglia_anni(cfg, OGGI)
%GRIGLIA_ANNI  Asse temporale della proiezione in ANNI SOLARI.
%   L'intervallo 1 va da OGGI al 31/12 dell'anno corrente (parziale), poi un
%   intervallo per ogni anno fino a ANNO_FINE.
%   Prima la Fase 5 contava "anni da oggi" (14/9 -> 14/9) e li etichettava
%   come anni solari, mentre storico e Fase 6 usavano anni solari: i rientri
%   gen-set 2026 sparivano e le serie erano sfasate di ~3,5 mesi.
%   G.anni      1 x NY
%   G.bordi     1 x (NY+1)  anni trascorsi da OGGI all'inizio/fine di ciascun anno
%   G.mezzo     1 x NY      istante medio dell'intervallo (lancio delle coorti)
%   G.durata    1 x NY      durata dell'intervallo (anni)
v = datevec(OGGI);
G.anno_oggi = v(1);
G.anni = G.anno_oggi:cfg.ANNO_FINE;
fine = datenum(G.anni + 1, 1, 1);
G.bordi = [0, (fine - OGGI) / 365.25];
G.mezzo = (G.bordi(1:end-1) + G.bordi(2:end)) / 2;
G.durata = diff(G.bordi);
G.NY = numel(G.anni);
G.OGGI = OGGI;
end
