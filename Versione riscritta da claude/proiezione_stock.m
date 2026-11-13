function R = proiezione_stock(P, CV, cfg, G, i_scen)
%PROIEZIONE_STOCK  Rientri attesi per anno solare dello stock in orbita a OGGI
%   (senza nuovi lanci).
%   Per ogni oggetto con eta' attuale a, la probabilita' di rientrare
%   nell'intervallo [b_j, b_j+1] (anni da OGGI) dato che e' in orbita oggi e':
%        p_j = [S(a+b_j) - S(a+b_j+1)] / S(a)
%   Il numero atteso e' la somma delle p_j; la massa attesa e' la somma di
%   m_i * p_j con la massa REALE di ciascun oggetto (non una massa di classe).
%   Per le costellazioni ad alta quota i rientri sono moltiplicati per la PMD.
%   Stazioni: rientro deterministico (cfg.ANNO_DEORBIT_ISS / _CSS).
%
%   R.cont, R.massa : NY x ncat (massa in kg)
%   R.n_stock, R.massa_stock, R.rimasti, R.massa_rimasta : 1 x ncat
CAT = cfg.CATEGORIE; nc = numel(CAT); NY = G.NY;
R.cont = zeros(NY, nc); R.massa = zeros(NY, nc);
R.n_stock = zeros(1, nc); R.massa_stock = zeros(1, nc);
R.rimasti = zeros(1, nc); R.massa_rimasta = zeros(1, nc);
R.non_proiettati = 0;
vivo = P.evento == 0;
for c = 1:nc
    cls = CAT{c};
    sel = vivo & strcmp(P.categoria, cls);
    R.n_stock(c) = sum(sel);
    if ~any(sel), continue; end
    m_ogg = P.massa(sel);
    m_media = mean(P.massa(strcmp(P.categoria, cls) & ~isnan(P.massa)));
    if isnan(m_media) || strcmp(cls, 'Altro'), m_media = 0; end   % Altro: nessuna imputazione
    m_ogg(isnan(m_ogg)) = m_media;
    R.massa_stock(c) = sum(m_ogg);
    a = P.durata(sel);
    switch cls
        case 'Stazioni'
            css = strcmp(P.State(sel), 'CN');
            anno_rientro = repmat(cfg.ANNO_DEORBIT_ISS, numel(a), 1);
            anno_rientro(css) = cfg.ANNO_DEORBIT_CSS;
            for j = 1:NY
                q = anno_rientro == G.anni(j);
                R.cont(j, c) = sum(q); R.massa(j, c) = sum(m_ogg(q));
            end
            resta = ~ismember(anno_rientro, G.anni);
            R.rimasti(c) = sum(resta); R.massa_rimasta(c) = sum(m_ogg(resta));
            continue
        case 'Altro'
            % equipaggio / massa ignota: nessuna curva affidabile -> non proiettati
            R.non_proiettati = sum(sel);
            R.rimasti(c) = sum(sel); R.massa_rimasta(c) = sum(m_ogg);
            continue
    end
    % modello per oggetto (per OtherLEO dipende dalla fascia di perigeo)
    strati = P.strato(sel);
    us = unique(strati);
    pmd = 1;
    if isfield(cfg.PMD, cls), pmd = cfg.PMD.(cls)(i_scen); end
    for u = 1:numel(us)
        q = strcmp(strati, us{u});
        if any(strcmp(cls, cfg.MEGA)) || strcmp(cls, 'Starlink_V1')
            mdl = modello_mega(CV, cfg, cls, i_scen);
        else
            mdl = CV.modelli.(us{u});
        end
        aq = a(q); mq = m_ogg(q);
        Sa = S_modello(mdl, aq);
        Sb = zeros(numel(aq), NY + 1);
        for j = 1:NY + 1
            Sb(:, j) = S_modello(mdl, aq + G.bordi(j));
        end
        cond = Sb ./ max(Sa, 1e-300);
        cond(Sa < 1e-12, :) = 0;   % per il modello sarebbe gia' rientrato: rientra subito
        cond(Sa < 1e-12, 1) = 1;
        pj = max(-diff(cond, 1, 2), 0);          % n x NY
        R.cont(:, c) = R.cont(:, c) + pmd * sum(pj, 1)';
        R.massa(:, c) = R.massa(:, c) + pmd * (pj' * mq);
        resto = cond(:, end);
        R.rimasti(c) = R.rimasti(c) + sum(resto) + (1 - pmd) * sum(pj(:));
        R.massa_rimasta(c) = R.massa_rimasta(c) + resto' * mq + (1 - pmd) * sum(pj, 2)' * mq;
    end
end
end
