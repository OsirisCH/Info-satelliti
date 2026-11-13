function r = corr_spearman(a, b)
%CORR_SPEARMAN  Correlazione di Spearman (ranghi con pareggi mediati).
ra = rango_medio(a); rb = rango_medio(b);
c = corrcoef(ra, rb); r = c(1, 2);
end
