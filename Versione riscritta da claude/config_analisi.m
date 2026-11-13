function cfg = config_analisi()
%CONFIG_ANALISI  Unica sorgente di tutti i parametri e di tutte le ASSUNZIONI.
%
% Prima ogni fase ridefiniva per conto suo liste di Status, target e
% parametri delle curve (copiati a mano). E' cosi' che i parametri lognormali
% di Fase 5-7 sono rimasti fermi a una versione vecchia della popolazione.
% Ora ogni fase chiama questa funzione: si cambia un valore qui e cambia
% ovunque.
%
% Compatibile MATLAB (R2016b+) e GNU Octave (>= 7). Nessun toolbox richiesto.

%% ---- percorsi ----------------------------------------------------------
cfg.CARTELLA = 'C:\Users\Utente\Desktop\Analisi Detriti';
if ~isempty(getenv('ANALISI_CARTELLA')), cfg.CARTELLA = getenv('ANALISI_CARTELLA'); end
if ~exist(cfg.CARTELLA, 'dir'), cfg.CARTELLA = pwd; end
cfg.FILE_SATCAT = fullfile(cfg.CARTELLA, 'satcat.txt');
% OPZIONALE ma raccomandato: catalogo ausiliario GCAT (oggetti con JCAT "A...").
% Scaricalo da https://planet4589.org/space/gcat/tsv/cat/auxcat.tsv e salvalo
% come auxcat.txt nella stessa cartella: la risoluzione degli ospiti (Dest)
% potra' attraversare anche gli oggetti A (es. complesso ISS, veicoli sganciati).
cfg.FILE_AUXCAT = fullfile(cfg.CARTELLA, 'auxcat.txt');

%% ---- data di riferimento -----------------------------------------------
% [] = usa la data di aggiornamento scritta nella 2a riga del catalogo.
% La censura deve coincidere con la data del catalogo: lo Status "O" e'
% vero a quella data, non a una data scelta a mano.
cfg.OGGI = [];
cfg.ANNO_FINE = 2050;

%% ---- semantica Status GCAT ---------------------------------------------
cfg.ST_EVENTO  = {'R','D','AR'};
cfg.ST_ESCLUSI = {'L','L?','LF','AL','AL IN','S','AS','F','AF','E','C','DSO','DSA','DSA IN', ...
                  'EVA DP','EVA RP','TX','LO','LOA','TO','TOA','REFLT','ERR'};
cfg.ST_FASE_CHIUSA = {'DK','GRP','ATT','TFR','TFR E','TFR IN','UDK','REL','DEP','N','NA','LEASE'};

%% ---- categorie ---------------------------------------------------------
cfg.CATEGORIE = {'Starlink_V1','Starlink_V2','Kuiper','OneWeb','Guowang','Qianfan', ...
                 'OtherLEO_leggero','OtherLEO_medio','OtherLEO_pesante','Stazioni','Altro'};
cfg.MEGA      = {'Starlink_V2','Kuiper','OneWeb','Guowang','Qianfan'};   % costellazioni con buildout
cfg.OTHERLEO  = {'OtherLEO_leggero','OtherLEO_medio','OtherLEO_pesante'};
% OtherLEO: la curva di sopravvivenza si stima per TERZILE DI MASSA x FASCIA
% DI PERIGEO (Fase 3 mostra che la quota domina). La categoria di output resta
% il terzile (serve per la massa).
cfg.SOGLIA_PERIGEO_KM = 600;
cfg.BANDE = {'bassa','alta'};       % bassa: perigeo <= soglia; alta: > soglia
cfg.MIN_EVENTI_FIT = 10;

%% ---- stazioni spaziali (moduli, Type con "MU") -------------------------
% Rientro deterministico pianificato, non statistico.
cfg.ANNO_DEORBIT_ISS = 2031;        % NASA: fine operazioni 2030, deorbit controllato (USDV) a inizio 2031
cfg.ANNO_DEORBIT_CSS = NaN;         % Tiangong: nessuna data annunciata -> oltre il 2050

%% ---- scenari -----------------------------------------------------------
% Tre scenari che racchiudono le assunzioni, in termini di NUMERO DI RIENTRI
% entro il 2050: 'basso' (meno rientri), 'centrale', 'alto' (piu' rientri).
% Ogni riga: [basso centrale alto].
cfg.SCENARI = {'basso','centrale','alto'};
cfg.SCENARIO_RIF = 'centrale';

% Costellazioni: target operativo (satelliti in servizio) e anno in cui viene
% raggiunto. FONTI / MOTIVAZIONI (da tenere aggiornate e da citare nel paper):
%  Starlink V2: FCC ha autorizzato 15.000 Gen2 (gen 2026). Alto = intera
%               richiesta Gen2 (~30.000). Il bus V2 alimenta solo Gen2.
%  Kuiper:      3.232 autorizzati, milestone FCC del 100% al 30/7/2029
%               (milestone del 50% di luglio 2026 sospesa). Ritmo osservato:
%               ~400 in orbita a set 2026 -> centrale con ritardo.
%  OneWeb:      Gen1 ~650 mantenuta (centrale); alto = espansione a ~1.200.
%  Guowang:     ~13.000 depositati in ITU; ritmo osservato ~200 in 2 anni.
%  Qianfan:     obiettivo ufficiale 15.000 al 2030; ~240 in orbita a set 2026
%               (~8/mese) -> 2030 irrealistico: alto=2035, centrale=2040,
%               basso = solo milestone ITU del 10% (~1.500) al 2032.
cfg.COST.Starlink_V2 = struct('target',[15000 15000 30000], 'y_full',[2031 2029 2032]);
cfg.COST.Kuiper      = struct('target',[3232  3232  3232 ], 'y_full',[2033 2031 2029]);
cfg.COST.OneWeb      = struct('target',[650   650   1200 ], 'y_full',[2027 2027 2030]);
cfg.COST.Guowang     = struct('target',[6500  13000 13000], 'y_full',[2038 2038 2034]);
cfg.COST.Qianfan     = struct('target',[1500  15000 15000], 'y_full',[2032 2040 2035]);

% Vita operativa MEDIANA (anni) prima del ritiro, Weibull con la forma k
% stimata su Starlink V1 (Fase 4). Vita piu' lunga = meno rientri.
%  - Starlink V2 'basso' = 7,0 anni: stima MLE dai dati V2 a k fissato
%    (Fase 4 la stampa); 'centrale' = vita di progetto dichiarata ~5,5 anni.
cfg.VITA_MEDIANA.Starlink_V2 = [7.0 5.5 4.5];
cfg.VITA_MEDIANA.Kuiper      = [7.0 5.5 4.5];
cfg.VITA_MEDIANA.OneWeb      = [9.0 7.0 5.5];
cfg.VITA_MEDIANA.Guowang     = [7.0 5.5 4.5];
cfg.VITA_MEDIANA.Qianfan     = [7.0 5.5 4.5];

% Affidabilita' dello smaltimento a fine vita (PMD): frazione dei satelliti
% ritirati che rientra davvero. Sotto ~650 km il decadimento naturale chiude
% comunque il ciclo in pochi anni (PMD=1). OneWeb (~1.200 km), Guowang
% (~860-1.150 km), Qianfan (~800-1.000 km): chi non viene deorbitato resta in
% orbita per secoli, quindi non rientra entro il 2050.
cfg.PMD.Starlink_V2 = [1    1    1];
cfg.PMD.Kuiper      = [1    1    1];
cfg.PMD.OneWeb      = [0.90 0.95 1];
cfg.PMD.Guowang     = [0.90 0.95 1];
cfg.PMD.Qianfan     = [0.90 0.95 1];
cfg.PMD.Starlink_V1 = [1    1    1];

% OtherLEO: tasso di lancio = media annua per strato (terzile x fascia) negli
% anni indicati. Basso = 2016-2020 (prima del boom), centrale = 2021-2025,
% alto = 2023-2025 (solo il trend recente, in crescita).
cfg.ANNI_TASSO = {2016:2020, 2021:2025, 2023:2025};

% Massa dei satelliti FUTURI per categoria: [] = media osservata della
% categoria (per OtherLEO: media dei lanci negli anni ANNI_TASSO del rispettivo
% scenario). Per uno scenario Starlink V3 (~1.900 kg) metti qui un numero.
cfg.MASSA_FUTURA_KG.Starlink_V2 = [];

%% ---- output ------------------------------------------------------------
cfg.MOSTRA_FIGURE = isempty(getenv('ANALISI_NO_FIG'));
cfg.SALVA_FIGURE  = ~isempty(getenv('ANALISI_SALVA_FIG'));   % PNG in CARTELLA/figure
cfg.CARTELLA_FIG  = fullfile(cfg.CARTELLA, 'figure');
end
