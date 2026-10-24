CREATE DATABASE demo;
\c demo;

-- Creazione tabella dipendenti
CREATE TABLE IF NOT EXISTS dipendenti (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50),
    cognome VARCHAR(50),
    dipartimento VARCHAR(50),
    data_assunzione DATE,
    stipendio DECIMAL(10,2)
);

-- Creazione tabella ordini
CREATE TABLE IF NOT EXISTS ordini (
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