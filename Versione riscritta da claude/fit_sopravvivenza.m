function [modelli, i_best] = fit_sopravvivenza(durata, evento, famiglie)
%FIT_SOPRAVVIVENZA  Massima verosimiglianza con censura a destra.
%   modelli(j): .fam .par .nll .n_par .aic .bic .n .eventi
%   i_best: indice del modello con AIC minimo.
%   Famiglie di default: weibull, lognormale, weibull_cure, lognormale_cure.
%
%   Rispetto alla versione precedente:
%   - parametrizzazione non vincolata (log k, log lambda, log sigma, logit p):
%     fminsearch non puo' piu' uscire dal dominio
%   - log S della lognormale calcolato con erfcx (niente log(0) in coda)
%   - piu' punti di partenza e un riavvio dal minimo (fminsearch si ferma
%     spesso troppo presto)
%   - modelli "cure" (mistura con frazione che non rientra): una lognormale
%     con sigma ~ 3-4 sta di fatto imitando una popolazione mista, meglio
%     modellarla esplicitamente
if nargin < 3
    famiglie = {'weibull','lognormale','weibull_cure','lognormale_cure'};
end
t = max(durata(:), 1e-3); e = double(evento(:) ~= 0);
n = numel(t); d = sum(e);
te = t(e == 1); if isempty(te), te = t; end
opts = optimset('TolX', 1e-8, 'TolFun', 1e-8, 'MaxIter', 20000, 'MaxFunEvals', 20000, 'Display', 'off');
modelli = struct('fam', {}, 'par', {}, 'nll', {}, 'n_par', {}, 'aic', {}, 'bic', {}, 'n', {}, 'eventi', {});
base = struct();
for j = 1:numel(famiglie)
    fam = famiglie{j};
    switch fam
        case 'weibull'
            x0s = [log([0.5 1 2])', log(median(te)) * [1 1 1]'];
        case 'lognormale'
            x0s = [log(median(te)) * [1 1 1]', log([0.7 1.2 2])'];
        case 'weibull_cure'
            x0s = [log(1.2), log(median(te)), logit(0.5); ...
                   log(1.0), log(median(te)), logit(min(max(d/n, 0.05), 0.95)); ...
                   log(0.7), log(mean(te)),   logit(0.9)];
            if isfield(base, 'weibull'), x0s = [x0s; base.weibull, logit(0.95)]; end %#ok<AGROW>
        case 'lognormale_cure'
            x0s = [log(median(te)), log(1.0), logit(0.5); ...
                   log(median(te)), log(0.8), logit(min(max(d/n, 0.05), 0.95)); ...
                   log(mean(te)),   log(1.5), logit(0.9)];
            if isfield(base, 'lognormale'), x0s = [x0s; base.lognormale, logit(0.95)]; end %#ok<AGROW>
    end
    f = @(th) nll_famiglia(th, fam, t, e);
    best = Inf; th_best = x0s(1, :);
    for s = 1:size(x0s, 1)
        th = fminsearch(f, x0s(s, :), opts);
        th = fminsearch(f, th, opts);            % riavvio
        v = f(th);
        if v < best, best = v; th_best = th; end
    end
    if any(strcmp(fam, {'weibull','lognormale'})), base.(fam) = th_best; end
    m.fam = fam; m.par = da_theta(th_best, fam); m.nll = best;
    m.n_par = numel(th_best);
    m.aic = 2*m.n_par + 2*best; m.bic = m.n_par*log(n) + 2*best;
    m.n = n; m.eventi = d;
    modelli(j) = m; %#ok<AGROW>
end
[~, i_best] = min([modelli.aic]);
end

%% ------------------------------------------------------------------------
function par = da_theta(th, fam)
switch fam
    case 'weibull',         par = [exp(th(1)), exp(th(2))];
    case 'lognormale',      par = [th(1), exp(th(2))];
    case 'weibull_cure',    par = [exp(th(1)), exp(th(2)), 1/(1+exp(-th(3)))];
    case 'lognormale_cure', par = [th(1), exp(th(2)), 1/(1+exp(-th(3)))];
end
end

function v = nll_famiglia(th, fam, t, e)
par = da_theta(th, fam);
switch fam
    case {'weibull','weibull_cure'}
        k = par(1); lam = par(2);
        zt = (t / lam) .^ k;
        logf0 = log(k) - log(lam) + (k-1) * (log(t) - log(lam)) - zt;
        logS0 = -zt;
    case {'lognormale','lognormale_cure'}
        mu = par(1); sg = par(2);
        z = (log(t) - mu) / sg;
        logf0 = -log(t) - log(sg) - 0.5*log(2*pi) - 0.5*z.^2;
        logS0 = log_sf_normale(z);
end
if numel(par) == 3
    p = par(3);
    logf = log(p) + logf0;
    logS = log((1 - p) + p * exp(logS0));
else
    logf = logf0; logS = logS0;
end
v = -sum(e .* logf + (1 - e) .* logS);
if ~isfinite(v), v = 1e15; end
end

function y = log_sf_normale(z)
% log(1 - Phi(z)) stabile anche per z grande
x = z / sqrt(2);
y = zeros(size(z));
pos = x > 0;
y(pos) = log(0.5) - x(pos).^2 + log(erfcx(x(pos)));
y(~pos) = log(0.5 * erfc(x(~pos)));
end

function y = logit(p)
y = log(p / (1 - p));
end
