function salva_figura(cfg, h)
%SALVA_FIGURA  Se cfg.SALVA_FIGURE e' vero salva la figura in PNG in
%   cfg.CARTELLA_FIG (nome = UserData impostato da nuova_figura). Se le figure
%   non sono visibili la chiude per non accumularle in memoria.
if cfg.SALVA_FIGURE
    if ~exist(cfg.CARTELLA_FIG, 'dir'), mkdir(cfg.CARTELLA_FIG); end
    nome = get(h, 'UserData');
    nome = regexprep(nome, '[^A-Za-z0-9_\-]', '_');
    print(h, fullfile(cfg.CARTELLA_FIG, [nome '.png']), '-dpng', '-r110');
end
if ~cfg.MOSTRA_FIGURE, close(h); end
end
