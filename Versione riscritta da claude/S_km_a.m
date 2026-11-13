function s = S_km_a(t, S, x, t_max)
%S_KM_A  Valore della curva KM (a gradini) al tempo x. NaN se x > t_max
%   (ultima durata osservata: oltre non c'e' informazione).
if nargin < 4, t_max = Inf; end
s = NaN(size(x));
for k = 1:numel(x)
    if x(k) > t_max, continue; end
    i = find(t <= x(k), 1, 'last');
    if isempty(i), s(k) = 1; else, s(k) = S(i); end
end
end
