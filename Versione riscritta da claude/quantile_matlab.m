function q = quantile_matlab(x, p)
%QUANTILE_MATLAB  Stesso algoritmo di quantile() di MATLAB (posizioni (i-0.5)/n,
%   interpolazione lineare, estremi saturati), senza Statistics Toolbox.
x = sort(x(~isnan(x))); x = x(:); n = numel(x);
q = NaN(size(p));
if n == 0, return; end
pos = ((1:n)' - 0.5) / n;
for k = 1:numel(p)
    if p(k) <= pos(1), q(k) = x(1);
    elseif p(k) >= pos(end), q(k) = x(end);
    else, q(k) = interp1(pos, x, p(k));
    end
end
end
