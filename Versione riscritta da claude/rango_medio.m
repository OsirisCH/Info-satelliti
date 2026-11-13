function r = rango_medio(x)
%RANGO_MEDIO  Ranghi con media sui pareggi (come tiedrank), per Spearman.
x = x(:); n = numel(x);
[xs, o] = sort(x);
nuovo = [true; diff(xs) ~= 0];
g = cumsum(nuovo);
pos = (1:n)';
mg = accumarray(g, pos) ./ accumarray(g, 1);
r = zeros(n, 1); r(o) = mg(g);
end
