function [t, S, lo, hi, n_rischio] = km_sopravvivenza(durata, evento)
%KM_SOPRAVVIVENZA  Stimatore di Kaplan-Meier con IC 95% (Greenwood, scala log-log).
%   Restituisce i tempi distinti di evento t e S(t) subito dopo ciascuno.
%   Equivalente a ecdf(...,'Censoring',1-evento,'Function','survivor') ma
%   senza toolbox e con gli intervalli di confidenza.
durata = durata(:); evento = evento(:) ~= 0;
[ts, o] = sort(durata); es = evento(o); n = numel(ts);
if n == 0 || ~any(es)
    t = zeros(0,1); S = t; lo = t; hi = t; n_rischio = t; return
end
nuovo = [true; diff(ts) > 0];
primo = find(nuovo);                 % primo indice di ogni tempo distinto
gruppo = cumsum(nuovo);
d = accumarray(gruppo, double(es));
n_r = n - primo + 1;                 % a rischio = oggetti con durata >= t
tu = ts(primo);
k = d > 0;
t = tu(k); d = d(k); n_rischio = n_r(k);
S = cumprod(1 - d ./ n_rischio);
v = cumsum(d ./ (n_rischio .* max(n_rischio - d, 1)));      % Greenwood
% IC su scala log(-log S) (non esce da [0,1])
L = log(-log(max(min(S, 1-1e-12), 1e-12)));
se = sqrt(v) ./ abs(log(max(min(S, 1-1e-12), 1e-12)));
lo = exp(-exp(L + 1.96*se)); hi = exp(-exp(L - 1.96*se));
lo(S == 0) = 0; hi(S == 0) = 0;
end
