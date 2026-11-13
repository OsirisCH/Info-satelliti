function [esito, data, catena] = risolvi_ospite(dest, LK, cfg)
%RISOLVI_OSPITE  Segue RICORSIVAMENTE la catena Dest -> ospite -> ospite...
%   LK e' la tabella di lookup (vedi prepara_popolazione): mappa JCAT -> riga,
%   con Status, decay, Dest. Esiti possibili:
%     'evento'  : la catena termina in un oggetto rientrato (R/D/AR) con data;
%                 data = data di rientro di quell'oggetto
%     'escluso' : la catena termina in un oggetto atterrato/esploso/... (ST_ESCLUSI)
%     'orbita'  : la catena termina in un oggetto ancora in orbita (O, AO, ...)
%     'ignoto'  : ospite non presente nei cataloghi caricati (es. JCAT "A..."
%                 senza auxcat.txt), Dest = '-', o ciclo
%   La versione precedente si fermava al PRIMO ospite: un Progress agganciato a
%   Kvant (Status ATT -> Mir) risultava "in orbita" perche' Kvant non ha Status R.
data = NaN; catena = {};
visti = {};
for prof = 1:25
    if isempty(dest) || strcmp(dest, '-') || ~isKey(LK.map, dest) || any(strcmp(visti, dest))
        esito = 'ignoto'; return
    end
    visti{end+1} = dest; %#ok<AGROW>
    k = LK.map(dest);
    st = LK.Status{k};
    catena{end+1} = sprintf('%s(%s)', dest, st); %#ok<AGROW>
    if any(strcmp(st, cfg.ST_EVENTO))
        if ~isnan(LK.decay(k)), esito = 'evento'; data = LK.decay(k);
        else, esito = 'ignoto'; end
        return
    elseif any(strcmp(st, cfg.ST_ESCLUSI))
        esito = 'escluso'; return
    elseif any(strcmp(st, cfg.ST_FASE_CHIUSA))
        dest = LK.Dest{k};          % sali di un livello
    else
        esito = 'orbita'; return
    end
end
esito = 'ignoto';
end
