function m = modello_mega(CV, cfg, cls, i_scen)
%MODELLO_MEGA  Curva di ritiro per una costellazione giovane (ASSUNZIONE).
%   Weibull con la forma k stimata su Starlink V1 e la scala lambda ricavata
%   dalla vita mediana dello scenario:  lambda = mediana / (ln 2)^(1/k).
%   Questi satelliti hanno troppi pochi rientri (0-6) per un fit proprio.
if strcmp(cls, 'Starlink_V1')
    m = CV.modelli.Starlink_V1; return
end
med = cfg.VITA_MEDIANA.(cls)(i_scen);
k = CV.k_V1;
m.fam = 'weibull';
m.par = [k, med / log(2)^(1/k)];
end
