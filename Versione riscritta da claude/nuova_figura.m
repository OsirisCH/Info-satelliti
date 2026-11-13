function h = nuova_figura(cfg, nome)
%NUOVA_FIGURA  Crea una figura (visibile o no secondo cfg) e la etichetta con
%   un nome usato da salva_figura per il file PNG.
if cfg.MOSTRA_FIGURE
    h = figure('Name', nome, 'NumberTitle', 'off');
else
    h = figure('Visible', 'off', 'Name', nome);
end
set(h, 'Position', [100 100 900 520]);
set(h, 'UserData', nome);
end
