function R = cox_breslow(durata, evento, X, ingresso)
%COX_BRESLOW  Modello di Cox (rischi proporzionali), verosimiglianza parziale
%   con correzione di Breslow per i tempi coincidenti (come coxphfit).
%   Opzionale: ingresso = eta' di ingresso (troncamento a sinistra), per
%   stimare gli HR su finestre di eta' e verificare l'ipotesi PH.
%   R.b, R.se, R.z, R.p, R.HR, R.HR_lo, R.HR_hi, R.iter
%   Senza toolbox (Newton-Raphson con dimezzamento del passo).
t = durata(:); d = evento(:) ~= 0; [n, p] = size(X);
if nargin < 4 || isempty(ingresso), ingresso = zeros(n, 1); end
ingresso = ingresso(:);
% standardizzo per la stabilita' numerica, poi riporto i coefficienti
mu = mean(X, 1); sd = std(X, 0, 1); sd(sd == 0) = 1;
Z = (X - mu) ./ sd;
tev = unique(t(d));
b = zeros(p, 1); ll_old = -Inf;
for it = 1:100
    [ll, U, I] = verosimiglianza(b, Z, t, d, ingresso, tev);
    if it > 1 && abs(ll - ll_old) < 1e-10, break; end
    passo = I \ U;
    s = 1;
    while true
        ll_new = verosimiglianza(b + s*passo, Z, t, d, ingresso, tev);
        if ll_new >= ll - 1e-12 || s < 1e-6, break; end
        s = s / 2;
    end
    b = b + s*passo; ll_old = ll;
end
[~, ~, I] = verosimiglianza(b, Z, t, d, ingresso, tev);
V = inv(I);
R.b = b ./ sd(:);
R.se = sqrt(diag(V)) ./ sd(:);
R.z = R.b ./ R.se;
R.p = erfc(abs(R.z) / sqrt(2));
R.HR = exp(R.b); R.HR_lo = exp(R.b - 1.96*R.se); R.HR_hi = exp(R.b + 1.96*R.se);
R.iter = it; R.n = n; R.eventi = sum(d);
end

function [ll, U, I] = verosimiglianza(b, Z, t, d, ingresso, tev)
p = size(Z, 2);
eta = Z * b; w = exp(eta - max(eta));
ll = 0; U = zeros(p, 1); I = zeros(p, p);
% Ciclo sui tempi distinti di evento (risk set = t >= tj e ingresso < tj).
% Per n ~ 10^4 e ~5.000 tempi e' rapido; ordinare per t accelera.
[ts, o] = sort(t); Zs = Z(o, :); ws = w(o); ds = d(o); es = eta(o) - max(eta); ins = ingresso(o);
inizio = 1;
for j = 1:numel(tev)
    tj = tev(j);
    while inizio <= numel(ts) && ts(inizio) < tj, inizio = inizio + 1; end
    rs = inizio:numel(ts);
    rs = rs(ins(rs) < tj);
    ev = rs(ts(rs) == tj & ds(rs));
    m = numel(ev);
    if m == 0, continue; end
    wr = ws(rs); S0 = sum(wr); S1 = (wr' * Zs(rs, :))';
    S2 = Zs(rs, :)' * (Zs(rs, :) .* wr);
    ll = ll + sum(es(ev)) - m * log(S0);
    U = U + sum(Zs(ev, :), 1)' - m * S1 / S0;
    I = I + m * (S2 / S0 - (S1 / S0) * (S1 / S0)');
end
end
