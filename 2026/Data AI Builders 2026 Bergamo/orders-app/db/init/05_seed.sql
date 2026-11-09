-- Dati sintetici (generati da script, deterministici). Non sono dati reali.
SET search_path = shop, public;
SELECT setseed(0.42);

-- ------------------------------------------------------------------ clienti (60)
INSERT INTO customers (code, name, email, region, profile)
SELECT 'C' || lpad(g::text, 4, '0'),
       (ARRAY['Rossi','Bianchi','Ferrari','Esposito','Colombo','Ricci','Marino','Greco','Bruno','Gallo',
              'Conti','De Luca','Mancini','Costa','Giordano','Rizzo','Lombardi','Moretti','Barbieri','Fontana'])[(g % 20) + 1]
       || ' ' ||
       (ARRAY['Impianti S.r.l.','Studio Associato','Logistica S.p.A.','Informatica S.r.l.','Arredi S.n.c.','Meccanica S.r.l.'])[((g / 20) % 6) + 1],
       'ordini' || g || '@esempio.test',
       (ARRAY['bergamo','milano','roma'])[(g % 3) + 1],
       jsonb_build_object(
           'settore',   (ARRAY['manifattura','servizi','commercio','edilizia','ict','logistica'])[(g % 6) + 1],
           'dipendenti', 3 + (g * 7) % 120,
           'tags',      CASE WHEN g % 4 = 0 THEN '["vip","pagamento-anticipato"]'::jsonb
                             WHEN g % 4 = 1 THEN '["nuovo"]'::jsonb
                             ELSE '[]'::jsonb END,
           'fatturazione', jsonb_build_object('pec', 'amministrazione' || g || '@pec.esempio.test',
                                              'pagamento', (ARRAY['bonifico 30gg','bonifico 60gg','carta','ri.ba.'])[(g % 4) + 1])
       )
FROM generate_series(1, 60) g;

-- ----------------------------------------------------------------- prodotti (37)
INSERT INTO products (sku, name, description, category, price, stock, attributes) VALUES
('NB-001','Notebook UltraSlim 14','Computer portatile leggero per chi lavora in mobilità, con batteria che dura una giornata intera e schermo opaco da 14 pollici.','computer',1099.00,25,'{"colore":"grigio","ram_gb":16,"storage_gb":512,"peso_kg":1.2,"connessioni":["usb-c","hdmi","wifi 6"],"garanzia_mesi":24}'),
('NB-002','Notebook Pro 16 Creator','Portatile potente per grafica e montaggio video, scheda grafica dedicata e display 16 pollici ad alta fedeltà cromatica.','computer',2399.00,8,'{"colore":"argento","ram_gb":32,"storage_gb":1024,"peso_kg":2.1,"connessioni":["usb-c","hdmi","thunderbolt","wifi 6"],"garanzia_mesi":24}'),
('NB-003','Notebook Office 15','Portatile economico per attività d''ufficio, navigazione web e videoconferenze.','computer',649.00,40,'{"colore":"nero","ram_gb":8,"storage_gb":256,"peso_kg":1.7,"connessioni":["usb-a","hdmi","wifi 5"],"garanzia_mesi":12}'),
('PC-001','Desktop Mini Workstation','Piccolo computer da scrivania silenzioso, adatto a uffici con poco spazio e a lavori di contabilità o gestionale.','computer',799.00,15,'{"colore":"nero","ram_gb":16,"storage_gb":512,"connessioni":["usb-a","usb-c","hdmi","ethernet"],"garanzia_mesi":36}'),
('MN-001','Monitor 27 pollici 4K','Schermo ultra HD da 27 pollici con regolazione in altezza, ideale per scrivania di lavoro e fogli di calcolo estesi.','monitor',389.00,30,'{"colore":"nero","diagonale_pollici":27,"risoluzione":"3840x2160","connessioni":["hdmi","displayport","usb-c"],"garanzia_mesi":36}'),
('MN-002','Monitor 24 pollici Full HD','Schermo da ufficio con filtro luce blu, cornice sottile e supporto inclinabile.','monitor',149.00,60,'{"colore":"nero","diagonale_pollici":24,"risoluzione":"1920x1080","connessioni":["hdmi","vga"],"garanzia_mesi":24}'),
('MN-003','Monitor Ultrawide 34','Schermo curvo panoramico per affiancare più finestre, ottimo per trading, programmazione e progettazione.','monitor',579.00,12,'{"colore":"grigio","diagonale_pollici":34,"risoluzione":"3440x1440","connessioni":["hdmi","displayport","usb-c"],"garanzia_mesi":36}'),
('KB-001','Tastiera meccanica wireless','Tastiera senza fili con tasti meccanici silenziosi, layout italiano e retroilluminazione.','periferiche',99.00,50,'{"colore":"nero","layout":"IT","connessioni":["bluetooth","usb-a"],"autonomia_ore":200,"garanzia_mesi":24}'),
('KB-002','Tastiera compatta USB','Tastiera con cavo, layout italiano, resistente agli schizzi, per postazioni condivise.','periferiche',29.00,120,'{"colore":"nero","layout":"IT","connessioni":["usb-a"],"garanzia_mesi":12}'),
('MS-001','Mouse ergonomico verticale','Mouse verticale che riduce l''affaticamento del polso, utile per chi usa il computer tutto il giorno.','periferiche',59.00,70,'{"colore":"nero","connessioni":["bluetooth","usb-a"],"autonomia_ore":400,"garanzia_mesi":24}'),
('MS-002','Mouse wireless compatto','Mouse senza fili piccolo e leggero da portare in borsa insieme al portatile.','periferiche',24.00,150,'{"colore":"grigio","connessioni":["bluetooth"],"autonomia_ore":500,"garanzia_mesi":12}'),
('HD-001','Cuffie con cancellazione del rumore','Cuffie bluetooth con microfono e cancellazione attiva del rumore per riunioni online e concentrazione in open space.','audio',279.00,35,'{"colore":"nero","connessioni":["bluetooth","jack 3.5"],"autonomia_ore":30,"cancellazione_rumore":true,"garanzia_mesi":24}'),
('HD-002','Cuffie USB con microfono','Cuffia cablata leggera con microfono flessibile, pensata per call center e assistenza clienti.','audio',45.00,90,'{"colore":"nero","connessioni":["usb-a"],"cancellazione_rumore":false,"garanzia_mesi":12}'),
('SP-001','Speakerphone per riunioni','Vivavoce con microfoni a 360 gradi per sale riunioni piccole e conferenze telefoniche.','audio',159.00,20,'{"colore":"nero","connessioni":["usb-a","bluetooth"],"garanzia_mesi":24}'),
('WC-001','Webcam Full HD con autofocus','Telecamera per videochiamate con messa a fuoco automatica e copriobiettivo per la privacy.','video',79.00,65,'{"colore":"nero","risoluzione":"1920x1080","connessioni":["usb-a"],"garanzia_mesi":24}'),
('WC-002','Webcam 4K per sala riunioni','Videocamera grandangolare 4K con inquadratura automatica dei partecipanti.','video',329.00,10,'{"colore":"nero","risoluzione":"3840x2160","connessioni":["usb-c"],"garanzia_mesi":24}'),
('CH-001','Sedia ergonomica da ufficio','Poltrona con supporto lombare regolabile, schienale in rete traspirante e braccioli 4D per lunghe giornate alla scrivania.','arredo',349.00,18,'{"colore":"nero","portata_kg":120,"materiale":"rete","regolazioni":["altezza","lombare","braccioli"],"garanzia_mesi":60}'),
('CH-002','Sedia operativa base','Sedia girevole imbottita con regolazione dell''altezza, adatta a postazioni di uso occasionale.','arredo',119.00,45,'{"colore":"blu","portata_kg":100,"materiale":"tessuto","regolazioni":["altezza"],"garanzia_mesi":24}'),
('DK-001','Scrivania regolabile in altezza','Piano di lavoro elettrico che passa da seduto a in piedi con un tasto, memorizza tre posizioni.','arredo',529.00,14,'{"colore":"bianco","materiale":"laminato","larghezza_cm":160,"regolazioni":["altezza elettrica"],"garanzia_mesi":60}'),
('DK-002','Scrivania lineare 140','Scrivania semplice dal design essenziale con passacavi, struttura in acciaio.','arredo',189.00,33,'{"colore":"rovere","materiale":"laminato","larghezza_cm":140,"garanzia_mesi":24}'),
('LP-001','Lampada da scrivania LED','Lampada con luce regolabile in intensità e temperatura colore, braccio snodato e ricarica wireless integrata.','arredo',69.00,55,'{"colore":"bianco","connessioni":["usb-a"],"potenza_w":10,"garanzia_mesi":24}'),
('RT-001','Router Wi-Fi 6 dual band','Router per ufficio con copertura estesa, quattro porte gigabit e gestione degli ospiti.','rete',129.00,28,'{"colore":"nero","connessioni":["ethernet","wifi 6"],"porte":4,"garanzia_mesi":36}'),
('RT-002','Access point Wi-Fi 6 a soffitto','Punto di accesso alimentato via cavo di rete (PoE) per coprire ampi open space.','rete',189.00,22,'{"colore":"bianco","connessioni":["ethernet","wifi 6"],"poe":true,"garanzia_mesi":36}'),
('SW-001','Switch gigabit 24 porte','Commutatore di rete non gestito a 24 porte per armadi rack e piccoli datacenter.','rete',219.00,12,'{"colore":"nero","connessioni":["ethernet"],"porte":24,"garanzia_mesi":60}'),
('CB-001','Cavo di rete Cat6 5 metri','Cavo ethernet schermato per collegamenti a 1 gigabit, confezione da 5 pezzi.','rete',19.00,300,'{"colore":"blu","connessioni":["ethernet"],"lunghezza_m":5,"garanzia_mesi":12}'),
('DS-001','Docking station USB-C','Stazione di collegamento con doppio HDMI, ethernet e ricarica fino a 100 W: un solo cavo per il portatile.','accessori',149.00,40,'{"colore":"grigio","connessioni":["usb-c","hdmi","ethernet","usb-a"],"potenza_w":100,"garanzia_mesi":24}'),
('HB-001','Hub USB-C 7 porte','Adattatore compatto con HDMI, lettore di schede e porte USB per ultrabook con poche porte.','accessori',49.00,85,'{"colore":"argento","connessioni":["usb-c","hdmi","usb-a"],"garanzia_mesi":24}'),
('BG-001','Zaino imbottito per notebook','Zaino resistente all''acqua con scomparto imbottito fino a 16 pollici, per spostamenti quotidiani.','accessori',65.00,60,'{"colore":"nero","capacita_l":22,"materiale":"poliestere","garanzia_mesi":24}'),
('SD-001','SSD esterno 1 TB','Disco a stato solido portatile veloce per backup e trasferimento di grandi file.','storage',109.00,75,'{"colore":"nero","capacita_gb":1000,"connessioni":["usb-c"],"garanzia_mesi":36}'),
('SD-002','Chiavetta USB 128 GB','Memoria flash tascabile per trasportare documenti, con connettore USB-A.','storage',14.00,250,'{"colore":"nero","capacita_gb":128,"connessioni":["usb-a"],"garanzia_mesi":12}'),
('NS-001','NAS 2 baie per ufficio','Server di archiviazione in rete con due dischi in mirroring, condivisione file e backup automatico per piccoli studi.','storage',329.00,9,'{"colore":"nero","baie":2,"connessioni":["ethernet"],"garanzia_mesi":36}'),
('PR-001','Stampante laser multifunzione','Stampa, copia e scansione in bianco e nero, fronte retro automatico e Wi-Fi, per uffici fino a dieci persone.','stampanti',259.00,16,'{"colore":"bianco","connessioni":["ethernet","wifi 5","usb-a"],"stampa":"laser","fronte_retro":true,"garanzia_mesi":24}'),
('PR-002','Stampante a getto di inchiostro a colori','Stampante domestica e da studio per foto e documenti a colori, cartucce separate.','stampanti',89.00,30,'{"colore":"nero","connessioni":["wifi 5","usb-a"],"stampa":"inkjet","fronte_retro":false,"garanzia_mesi":12}'),
('TN-001','Toner nero alta capacità','Cartuccia di ricambio compatibile con la stampante laser multifunzione, circa 3000 pagine.','stampanti',59.00,100,'{"colore":"nero","resa_pagine":3000,"garanzia_mesi":12}'),
('UP-001','Gruppo di continuità 1000 VA','Alimentatore di emergenza che protegge computer e rete da sbalzi e interruzioni di corrente.','accessori',139.00,24,'{"colore":"nero","potenza_va":1000,"garanzia_mesi":24}'),
('PW-001','Caricabatterie USB-C 65 W','Alimentatore compatto per portatili e telefoni, con due uscite.','accessori',39.00,110,'{"colore":"bianco","connessioni":["usb-c"],"potenza_w":65,"garanzia_mesi":24}'),
('TB-001','Tablet 11 pollici con penna','Tavoletta per appunti e firma digitale di documenti, con penna inclusa e custodia a libro.','computer',459.00,20,'{"colore":"grigio","ram_gb":8,"storage_gb":256,"connessioni":["usb-c","wifi 6","bluetooth"],"garanzia_mesi":24}');

SELECT refresh_product_words();

-- ------------------------------------------------------------------ ordini (400)
-- Le notifiche non servono durante il caricamento
ALTER TABLE orders DISABLE TRIGGER orders_notify;
ALTER TABLE orders DISABLE TRIGGER orders_status_transition;

DO $$
DECLARE
    v_n        integer := 400;
    v_i        integer;
    v_cust     customers%ROWTYPE;
    v_order    bigint;
    v_status   text;
    v_roll     double precision;
    v_lines    integer;
BEGIN
    FOR v_i IN 1..v_n LOOP
        SELECT * INTO v_cust FROM customers ORDER BY id OFFSET floor(random() * 60)::int LIMIT 1;
        v_roll := random();
        v_status := CASE WHEN v_i > v_n - 25 THEN (ARRAY['new','confirmed'])[1 + floor(random() * 2)::int]
                         WHEN v_roll < 0.58 THEN 'delivered'
                         WHEN v_roll < 0.72 THEN 'shipped'
                         WHEN v_roll < 0.82 THEN 'paid'
                         WHEN v_roll < 0.90 THEN 'confirmed'
                         WHEN v_roll < 0.95 THEN 'new'
                         ELSE 'cancelled' END;

        INSERT INTO orders (customer_id, region, status, placed_at, shipping, notes)
        VALUES (v_cust.id, v_cust.region, v_status,
                now() - ((v_n - v_i) * interval '7 hours'),
                jsonb_build_object(
                    'indirizzo', 'Via ' || (ARRAY['Roma','Garibaldi','Mazzini','Dante','Verdi','Manzoni'])[1 + floor(random() * 6)::int] || ' ' || (1 + floor(random() * 120)::int),
                    'citta',     initcap(v_cust.region),
                    'corriere',  (ARRAY['BRT','GLS','SDA','DHL'])[1 + floor(random() * 4)::int],
                    'consegna',  jsonb_build_object('fascia', (ARRAY['mattina','pomeriggio'])[1 + floor(random() * 2)::int],
                                                    'telefono_richiesto', random() < 0.3)),
                CASE WHEN random() < 0.15 THEN 'Consegnare al piano terra' END)
        RETURNING id INTO v_order;

        v_lines := 1 + floor(random() * 4)::int;
        INSERT INTO order_items (order_id, product_id, region, quantity, unit_price)
        SELECT v_order, p.id, v_cust.region, 1 + floor(random() * 5)::int, p.price
          FROM (SELECT id, price FROM products ORDER BY random() LIMIT v_lines) p;
    END LOOP;
END $$;

ALTER TABLE orders ENABLE TRIGGER orders_notify;
ALTER TABLE orders ENABLE TRIGGER orders_status_transition;

INSERT INTO order_events (order_id, region, event_type, new_status, changed_by, created_at)
SELECT id, region, 'created', status, 'seed', placed_at FROM orders;

ANALYZE;
