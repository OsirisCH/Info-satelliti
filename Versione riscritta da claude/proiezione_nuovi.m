function N = proiezione_nuovi(P, CV, cfg, G, i_scen)
%PROIEZIONE_NUOVI  Lanci futuri (da OGGI al 2050) e rientri dei SOLI nuovi lanciati.
%
%   COSTELLAZIONI (modello stock-flusso, coerente con la Fase 5):
%   P*(t) = popolazione operativa obiettivo: curva logistica che parte dallo
%   stock REALE di oggi e arriva al target dello scenario alla fine di y_full,
%   poi resta costante. I lanci dell'anno j sono quelli necessari a stare sulla
%   curva, tenendo conto dei ritiri di stock e coorti precedenti:
%     N_j = max(P*(b_j+1) - Surv_stock(b_j+1) - sum_k<j N_k S(b_j+1 - m_k), 0)
%           / S(b_j+1 - m_j)
%   (coorte lanciata a meta' intervallo, m_j). Cosi':
%   - la sostituzione dei satelliti ritirati c'e' SEMPRE, anche durante il
%     buildout (prima partiva solo da y_full)
%   - il target dichiarato viene raggiunto davvero (prima la traslazione
%     verticale della curva spostava l'asintoto: Qianfan arrivava a 11.568)
%   - i lanci gia' avvenuti nel 2026 non vengono ricontati (sono nello stock)
%   - non serve la formula stock/vita (che con la mediana sovrastimava)
%   I rientri sono i ritiri moltiplicati per la PMD dello scenario.
%
%   OtherLEO: tasso costante per STRATO (terzile x fascia), media dei lanci
%   osservati negli anni cfg.ANNI_TASSO{i_scen}; nel 2026 solo la parte d'anno
%   dopo OGGI. Massa = media dei lanci di quegli anni.
%
%   N.lanci, N.cont, N.massa (kg), N.pop_obiettivo, N.pop_modello : NY x ncat
CAT = cfg.CATEGORIE; nc = numel(CAT); NY = G.NY;
N.lanci = zeros(NY, nc); N.cont = zeros(NY, nc); N.massa = zeros(NY, nc);
N.pop_obiettivo = NaN(NY, nc); N.pop_modello = NaN(NY, nc);
N.massa_unitaria = NaN(1, nc);
vivo = P.evento == 0;
v = datevec(P.launch); anno_lancio = v(:, 1);
b = G.bordi; mz = G.mezzo;

%% ---- costellazioni -------------------------------------------------------
for i = 1:numel(cfg.MEGA)
    cls = cfg.MEGA{i}; c = find(strcmp(CAT, cls));
    mdl = modello_mega(CV, cfg, cls, i_scen);
    pmd = cfg.PMD.(cls)(i_scen);
    a = P.durata(vivo & strcmp(P.categoria, cls));
    Sa = max(S_modello(mdl, a), 1e-300);
    surv_stock = @(u) sum(S_modello(mdl, a + u) ./ Sa);
    target = cfg.COST.(cls).target(i_scen); y_full = cfg.COST.(cls).y_full(i_scen);
    Pobj = popolazione_obiettivo(numel(a), target, y_full, G);
    Nl = zeros(NY, 1);
    for j = 1:NY
        sopr = surv_stock(b(j+1));
        for k = 1:j-1, sopr = sopr + Nl(k) * S_modello(mdl, b(j+1) - mz(k)); end
        Nl(j) = max(Pobj(j) - sopr, 0) / S_modello(mdl, b(j+1) - mz(j));
        N.pop_modello(j, c) = sopr + Nl(j) * S_modello(mdl, b(j+1) - mz(j));
    end
    N.pop_obiettivo(:, c) = Pobj;
    N.lanci(:, c) = Nl;
    rit = ritiri_coorti(Nl, mdl, b, mz);
    N.cont(:, c) = pmd * rit;
    mu_m = cfg_massa(cfg, cls, mean(P.massa(strcmp(P.categoria, cls) & ~isnan(P.massa))));
    N.massa_unitaria(c) = mu_m;
    N.massa(:, c) = N.cont(:, c) * mu_m;
end

%% ---- OtherLEO: tasso storico per strato -------------------------------
anni_t = cfg.ANNI_TASSO{i_scen};
for i = 1:numel(cfg.OTHERLEO)
    cls = cfg.OTHERLEO{i}; c = find(strcmp(CAT, cls));
    m_tot = 0; n_tot = 0;
    for bnd = 1:numel(cfg.BANDE)
        strato = [cls '_' cfg.BANDE{bnd}];
        nel = strcmp(P.strato, strato) & ismember(anno_lancio, anni_t);
        tasso = sum(nel) / numel(anni_t);                % lanci/anno
        Nl = tasso * G.durata(:);                         % il 1o intervallo e' parziale
        mdl = CV.modelli.(strato);
        rit = ritiri_coorti(Nl, mdl, b, mz);
        mu_m = mean(P.massa(nel & ~isnan(P.massa)));
        if isnan(mu_m), mu_m = mean(P.massa(strcmp(P.strato, strato) & ~isnan(P.massa))); end
        N.lanci(:, c) = N.lanci(:, c) + Nl;
        N.cont(:, c) = N.cont(:, c) + rit;
        N.massa(:, c) = N.massa(:, c) + rit * mu_m;
        m_tot = m_tot + sum(Nl) * mu_m; n_tot = n_tot + sum(Nl);
    end
    N.massa_unitaria(c) = m_tot / max(n_tot, eps);
end
end

%% ========================================================================
function rit = ritiri_coorti(Nl, mdl, b, mz)
% ritiri attesi nell'intervallo j delle coorti lanciate a meta' intervallo k<=j
NY = numel(Nl); rit = zeros(NY, 1);
for j = 1:NY
    for k = 1:j
        rit(j) = rit(j) + Nl(k) * (S_modello(mdl, max(b(j) - mz(k), 0)) - S_modello(mdl, b(j+1) - mz(k)));
    end
end
end

function Pobj = popolazione_obiettivo(N0, target, y_full, G)
% logistica da N0 (OGGI) a target (fine di y_full), costante dopo
u = G.bordi(2:end)';
U = (datenum(y_full + 1, 1, 1) - G.OGGI) / 365.25;
if target <= N0 || U <= 0
    Pobj = target * ones(G.NY, 1);
    return
end
g = @(x) 1 ./ (1 + exp(-(x - U/2) / (U/6)));
fr = (g(u) - g(0)) / (g(U) - g(0));
fr = min(max(fr, 0), 1);
Pobj = N0 + fr * (target - N0);
end

function m = cfg_massa(cfg, cls, default)
m = default;
if isfield(cfg.MASSA_FUTURA_KG, cls) && ~isempty(cfg.MASSA_FUTURA_KG.(cls))
    m = cfg.MASSA_FUTURA_KG.(cls);
end
end
