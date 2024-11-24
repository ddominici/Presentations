-- 
-- Data Saturday Parma 2024
-- 
-- PostgreSQL: il query optimizer in dettaglio
--
-- Demos
--

-- Bonus: codice di creazione e popolamento delle tabelle
-- N.B. Per chi utilizza Docker il database è già creato e popolato
-- dallo script init.sql

drop table if exists ordini ;
drop table if exists dipendenti ;

-- Creazione tabella dipendenti
CREATE TABLE dipendenti (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50),
    cognome VARCHAR(50),
    dipartimento VARCHAR(50),
    data_assunzione DATE,
    stipendio DECIMAL(10,2)
);

-- Creazione tabella ordini
CREATE TABLE ordini (
    id SERIAL PRIMARY KEY,
    dipendente_id INTEGER REFERENCES dipendenti(id),
    data_ordine DATE,
    importo DECIMAL(10,2),
    cliente VARCHAR(100)
);

-- Popolamento tabella dipendenti
INSERT INTO dipendenti (nome, cognome, dipartimento, data_assunzione, stipendio)
SELECT 
    (ARRAY['Mario', 'Luigi', 'Giovanni', 'Paolo', 'Marco', 'Andrea', 'Roberto', 'Giuseppe'])[floor(random() * 8 + 1)],
    (ARRAY['Rossi', 'Bianchi', 'Verdi', 'Neri', 'Ferrari', 'Romano', 'Colombo', 'Ricci'])[floor(random() * 8 + 1)],
    (ARRAY['Vendite', 'Marketing', 'IT', 'Amministrazione', 'Logistica'])[floor(random() * 5 + 1)],
    date '2020-01-01' + floor(random() * 1460)::integer,
    random() * 30000 + 25000
FROM generate_series(1, 1000);

-- Popolamento tabella ordini
INSERT INTO ordini (dipendente_id, data_ordine, importo, cliente)
SELECT 
    floor(random() * 1000 + 1)::integer,
    date '2023-01-01' + floor(random() * 450)::integer,
    random() * 5000 + 100,
    'Cliente_' || floor(random() * 500 + 1)::integer
FROM generate_series(1, 10000);

-- Creazione indici per migliorare le performance
CREATE INDEX idx_dipendenti_dipartimento ON dipendenti(dipartimento);
CREATE INDEX idx_dipendenti_data_assunzione ON dipendenti(data_assunzione);
CREATE INDEX idx_ordini_dipendente ON ordini(dipendente_id);
CREATE INDEX idx_ordini_data ON ordini(data_ordine);

-- Aggiornamento statistiche
ANALYZE dipendenti;
ANALYZE ordini;


-- Query di verifica dei dati inseriti
SELECT 
    'Dipendenti' as tabella,
    COUNT(*) as totale_righe,
    COUNT(DISTINCT dipartimento) as num_dipartimenti,
    MIN(data_assunzione) as prima_assunzione,
    MAX(data_assunzione) as ultima_assunzione
FROM dipendenti
UNION ALL
SELECT 
    'Ordini' as tabella,
    COUNT(*) as totale_righe,
    COUNT(DISTINCT dipendente_id) as num_dipendenti,
    MIN(data_ordine) as primo_ordine,
    MAX(data_ordine) as ultimo_ordine
FROM ordini;


-------------------------------------------------------------------------------
-- INIZIO DEMO
-------------------------------------------------------------------------------

--
-- 1. Esempi dei vari metodi di accesso
--

--
-- Sequential scan
--
EXPLAIN ANALYZE
SELECT * 
FROM dipendenti
WHERE id < 1000;

--
-- Index scan
--
EXPLAIN ANALYZE
SELECT * 
FROM dipendenti
WHERE data_assunzione = '2023-11-02';

/*

Index Scan using idx_dipendenti_data_assunzione on dipendenti  (cost=0.28..8.29 rows=1 width=38) (actual time=0.005..0.007 rows=2 loops=1)
  Index Cond: (data_assunzione = '2023-11-02'::date)

*/

--
-- Index only scan
--

drop index if exists idx_dipendenti_dipartimento_data_assunzione;

CREATE INDEX idx_dipendenti_dipartimento_data_assunzione 
ON dipendenti(dipartimento, data_assunzione desc) 

EXPLAIN (analyze, verbose)
SELECT dipartimento, data_assunzione --, cognome, nome 
FROM dipendenti
WHERE dipartimento = 'Marketing' 
AND data_assunzione = '2023-08-10'
order by data_assunzione DESC;

/*

Index Only Scan using idx_dipendenti_dipartimento_data_assunzione on public.dipendenti  (cost=0.28..8.29 rows=1 width=13) (actual time=0.025..0.026 rows=1 loops=1)
  Output: dipartimento, data_assunzione
  Index Cond: ((dipendenti.dipartimento = 'Marketing'::text) AND (dipendenti.data_assunzione = '2023-08-10'::date))
  Heap Fetches: 1

*/

--
-- Bitmap Heap/Index Scan
--

explain analyze
select *
from dipendenti
where data_assunzione > '2023-08-10';


-------------------------------------------------------------------------------
-- 2. Statistiche mancanti o obsolete
-------------------------------------------------------------------------------

-- Statistiche per dipartimento
SELECT 
    dipartimento,
    COUNT(*) as num_dipendenti,
    ROUND(AVG(stipendio), 2) as stipendio_medio
FROM dipendenti
GROUP BY dipartimento
ORDER BY num_dipendenti DESC;

explain
select *
from dipendenti 
where dipartimento = 'Marketing';

/*

Bitmap Heap Scan on dipendenti  (cost=5.72..18.26 rows=212 width=38)
  Recheck Cond: ((dipartimento)::text = 'Marketing'::text)
  ->  Bitmap Index Scan on idx_dipendenti_dipartimento  (cost=0.00..5.67 rows=212 width=0)
        Index Cond: ((dipartimento)::text = 'Marketing'::text)

*/

-- Inserisco altri 1000 dipendenti in un nuovo reparto
INSERT INTO dipendenti (nome, cognome, dipartimento, data_assunzione, stipendio)
SELECT 
    (ARRAY['Mario', 'Luigi', 'Giovanni', 'Paolo', 'Marco', 'Andrea', 'Roberto', 'Giuseppe'])[floor(random() * 8 + 1)],
    (ARRAY['Rossi', 'Bianchi', 'Verdi', 'Neri', 'Ferrari', 'Romano', 'Colombo', 'Ricci'])[floor(random() * 8 + 1)],
    'R&D',
    date '2020-01-01' + floor(random() * 1460)::integer,
    random() * 30000 + 25000
FROM generate_series(1, 1000);


-- Senza statistiche aggiornate, le righe stimate sono pari a 1 !!!
explain (verbose, analyze)
select *
from dipendenti 
where dipartimento = 'R&D'

/*

Index Scan using idx_dipendenti_dipartimento on public.dipendenti  
    (cost=0.28..8.29 rows=1 width=38)  -- Righe stimate = 1 !!!!
    (actual time=0.024..0.239 rows=1000 loops=1)
  Output: id, nome, cognome, dipartimento, data_assunzione, stipendio
  Index Cond: ((dipendenti.dipartimento)::text = 'R&D'::text)

*/

-- Aggiorno le statistiche
analyze dipendenti;

-- Ora le righe stimate sono 1000
explain (verbose, analyze)
select nome,cognome, dipartimento
from dipendenti 
where dipartimento = 'R&D';


-------------------------------------------------------------------------------
-- 3. Indice covering
-------------------------------------------------------------------------------

DROP INDEX IF EXISTS idx_dipendenti_d_n_c;

CREATE INDEX idx_dipendenti_d_n_c ON dipendenti(dipartimento, nome, cognome);

explain (verbose, analyze)
select nome,cognome, dipartimento
from dipendenti 
where dipartimento = 'Marketing'

/*

Index Only Scan using idx_dipendenti_d_n_c on public.dipendenti  (cost=0.28..7.83 rows=203 width=19) (actual time=0.072..0.103 rows=203 loops=1)
  Output: nome, cognome, dipartimento
  Index Cond: (dipendenti.dipartimento = 'Marketing'::text)
  Heap Fetches: 0

*/

-- Funziona anche con il reparto più numeroso ?
explain (verbose, analyze)
select nome,cognome, dipartimento
from dipendenti 
where dipartimento = 'R&D'


-------------------------------------------------------------------------------
-- 4. Query Rewriter - Riscrittura e semplificazione delle query
-------------------------------------------------------------------------------

-- Esempio 1: riscrittura della query con una join in sostituzione
-- della subquery
explain verbose
SELECT nome, cognome 
FROM dipendenti 
WHERE id IN (SELECT dipendente_id 
             FROM ordini 
             WHERE importo > 1000);

/*

Nel piano di esecuzione si nota che la query è stata trasformata in una HASH JOIN
con la condizione di join: (dipendenti.id = ordini.dipendente_id)

Hash Join  (cost=242.08..296.46 rows=1000 width=13) (actual time=4.254..4.917 rows=1000 loops=1)
  Hash Cond: (dipendenti.id = ordini.dipendente_id)
  ->  Seq Scan on dipendenti  (cost=0.00..38.00 rows=2000 width=17) (actual time=0.006..0.216 rows=2000 loops=1)
  ->  Hash  (cost=229.58..229.58 rows=1000 width=4) (actual time=4.236..4.236 rows=1000 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 44kB
        ->  HashAggregate  (cost=219.58..229.58 rows=1000 width=4) (actual time=3.917..4.071 rows=1000 loops=1)
              Group Key: ordini.dipendente_id
              Batches: 1  Memory Usage: 129kB
              ->  Seq Scan on ordini  (cost=0.00..199.00 rows=8232 width=4) (actual time=0.005..2.247 rows=8238 loops=1)
                    Filter: (importo > '1000'::numeric)
                    Rows Removed by Filter: 1762

*/
            
-- Esempio 2: riscrittura di una vista            
CREATE OR REPLACE VIEW vista_ordini_totale AS
SELECT dipendente_id, SUM(importo) AS totale_importi
FROM ordini
GROUP BY dipendente_id;

explain verbose
SELECT *
FROM vista_ordini_totale
WHERE totale_importi > 10000;

/*

Nessun riferimento alla vista, la query è stata riscritta
sostituendo la vista con la sua definizione

HashAggregate  (cost=224.00..239.00 rows=333 width=36)
  Output: ordini.dipendente_id, sum(ordini.importo)
  Group Key: ordini.dipendente_id
  Filter: (sum(ordini.importo) > '10000'::numeric)
  ->  Seq Scan on public.ordini  (cost=0.00..174.00 rows=10000 width=10)
        Output: ordini.id, ordini.dipendente_id, ordini.data_ordine, ordini.importo, ordini.cliente

*/

drop view if exists vista_ordini_totale;

-- THE END

