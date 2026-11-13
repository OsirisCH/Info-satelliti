function S = S_modello(m, t)
%S_MODELLO  Funzione di sopravvivenza S(t) di un modello parametrico.
%   m.fam: 'weibull'          par = [k, lambda]
%          'lognormale'       par = [mu, sigma]
%          'weibull_cure'     par = [k, lambda, p]   S = (1-p) + p*S_weib
%          'lognormale_cure'  par = [mu, sigma, p]   S = (1-p) + p*S_logn
%          'deterministico'   par = [eta]  (rientra con certezza all'eta' eta)
%   p = frazione che rientra; 1-p = frazione che NON rientra (resta in orbita
%   nell'orizzonte di interesse, tipicamente oggetti sopra ~600-700 km).
%   t <= 0 -> S = 1.
t = max(t, 0);
switch m.fam
    case {'weibull','weibull_cure'}
        S = exp(-(t ./ m.par(2)) .^ m.par(1));
    case {'lognormale','lognormale_cure'}
        z = (log(max(t, 1e-12)) - m.par(1)) ./ m.par(2);
        S = 0.5 * erfc(z / sqrt(2));
    case 'deterministico'
        S = double(t < m.par(1));
        return
    otherwise
        error('Famiglia sconosciuta: %s', m.fam);
end
if numel(m.par) == 3
    S = (1 - m.par(3)) + m.par(3) * S;
end
S(t == 0) = 1;
end
