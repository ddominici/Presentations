# Gestione ordini clienti: PostgreSQL + Data API Builder + React

Esempio completo a supporto della sessione **PostgreSQL: il database che semplifica la tua architettura web** (Data AI Builders, Bergamo, 8 novembre 2026). Un sistema di gestione degli ordini che usa, in un solo motore, tutto ciò che le slide presentano.

| Tema delle slide | Dove si vede nell'app | Dove sta nel codice |
| --- | --- | --- |
| **JSONB** (`@>`, `?`, `@?`, indici GIN, `jsonb_path_ops`, indice su espressione) | Catalogo → *Attributi (JSONB)*; spedizione e profilo cliente | `db/init/01_schema.sql`, `find_products_by_attributes` |
| **Full Text Search** (`tsvector` generato con pesi, GIN, `websearch_to_tsquery`, `ts_rank`, `ts_headline`, config `italian`) | Catalogo → *Testo (FTS)* con le tre fasi | `products.search_vector`, `search_products_fts`, `explain_text_search` |
| **pg_trgm** (`%`, `<%`, `similarity`, `word_similarity`, GIN, `ILIKE '%…%'`, correzioni da `ts_stat`) | Clienti (ricerca), Catalogo → *Errori di battitura*, «forse cercavi» | `search_customers`, `search_products_fuzzy`, `suggest_terms` |
| **pgvector** (`vector(256)`, HNSW coseno, `<=>`, ricerca ibrida con RRF) | Catalogo → *Semantica*, *Ibrida*, pulsante *Simili* | `search_products_semantic`, `similar_products`, `search_products_hybrid` |
| **Row Level Security** (`USING`, `WITH CHECK`, permissive/restrittive, `security_invoker`, `FORCE`) | Sicurezza (RLS), tutte le pagine cambiando utente | `db/init/03_rls.sql` |
| **LISTEN / NOTIFY** (dopo il commit, rollback, deduplicazione, limite 8000 byte, coda) | Eventi live, toast e aggiornamento automatico della lista ordini | `notify_order_change`, `sidecar/src/events.js` |

## Architettura

```text
Browser (React + Vite)
  │  /dab/<utente>/…   REST + GraphQL            /sidecar/…   ricerche, create_order, SSE
  ▼                                                      ▼
Data API Builder ×3  (stessa config, ruolo DB diverso)   Sidecar Node (stessi ruoli + LISTEN dedicato)
:5001 rep_bergamo  :5002 rep_milano  :5003 shop_manager  :5004
  └──────────────────────────────┬──────────────────────────┘
                                 ▼
              PostgreSQL 18 · pg_trgm · pgvector
              RLS · trigger · funzioni · viste security_invoker
```

Due scelte da conoscere:

1. **Il ruolo di database è l'identità.** Data API Builder su PostgreSQL non ha un equivalente di `sp_set_session_context`, quindi si avviano tre istanze con la stessa `dab-config.json` e un ruolo diverso (`rep_bergamo`, `rep_milano`, `shop_manager`). Ogni ruolo porta il proprio contesto con `ALTER ROLE … SET app.region`, e le policy RLS leggono quel valore. L'interfaccia sceglie l'istanza dal selettore «Utente». L'autenticazione degli utenti **non** è implementata (è una demo): in produzione servono un provider di identità e il mapping claim → ruolo.
2. **Il sidecar copre ciò che DAB non espone su PostgreSQL.** Data API Builder 2.0.12 espone tabelle e viste, ma non funzioni/stored procedure su PostgreSQL (verificato: l'avvio fallisce con `Invalid collection name`). Quindi:
   - **DAB** (REST + GraphQL): ordini, clienti, catalogo, righe, storico, statistiche, con filtri, ordinamento, paginazione e mutazioni.
   - **Sidecar** (`sidecar/`, Node): le funzioni di ricerca (FTS, trigram, vettori, JSONB), `create_order` (ordine + righe in un'unica transazione), l'inoltro `LISTEN/NOTIFY → SSE`, e il calcolo degli embedding. Non accetta SQL libero: elenco chiuso di query parametrizzate, con lo **stesso ruolo** dell'utente, quindi la RLS vale identica.

Ogni risposta del sidecar include SQL, parametri, tempo e (su richiesta) il piano `EXPLAIN ANALYZE`, mostrati nel pannello **«Cosa fa PostgreSQL»**.

## Avvio

Servono Docker e Node.js 20+.

```bash
cd orders-app
docker compose up -d --build        # PostgreSQL + 3×DAB + sidecar (la prima volta scarica le immagini)
cd frontend && npm install && npm run dev
```

Poi aprire <http://localhost:5173>.

| Servizio | Porta | Note |
| --- | --- | --- |
| PostgreSQL 18 + pgvector | `15440` | `postgres` / `postgres`, database `shop` (modificabile in `.env`) |
| DAB `rep_bergamo` | `5001` | REST `/api/…`, GraphQL `/graphql` |
| DAB `rep_milano` | `5002` | idem |
| DAB `shop_manager` | `5003` | idem |
| Sidecar | `5004` | `/api/health` per verificare |
| Frontend (Vite) | `5173` | inoltra `/dab/*` e `/sidecar/*` |

Gli script in `db/init/` sono eseguiti **solo alla prima creazione del volume**. Per ripartire da zero (dati, ruoli, embedding):

```bash
docker compose down -v && docker compose up -d --build
```

Gli embedding dei prodotti vengono calcolati dal sidecar al primo avvio (una volta sola) e salvati in `products.embedding`.

### Dati

Dati **sintetici**, generati in modo deterministico da `db/init/05_seed.sql`: 60 clienti in tre regioni (Bergamo, Milano, Roma), 37 prodotti con attributi JSONB, 400 ordini. Roma è visibile solo al manager. I confronti di prestazione su questa dimensione non sono significativi: con poche righe il planner preferisce spesso la scansione sequenziale, per questo la UI offre «indice forzato» solo per mostrare l'indice usato. Le misure vanno ripetute su un dataset reale.

## Percorso di demo suggerito

1. **Dashboard** con l'utente *Venditore Bergamo*, poi *Manager*: gli stessi numeri cambiano senza che l'app filtri nulla.
2. **Ordini**: filtri via GraphQL, apri un ordine, avanza lo stato (il trigger valida le transizioni), prova «Salta a Consegnato» e «Sposta in altra regione» (errori originali PostgreSQL), poi crea un ordine.
3. In un secondo browser/finestra con *Venditore Milano*, cambia lo stato di un ordine: la lista di Bergamo non si muove (RLS + filtro SSE); con *Manager* sì.
4. **Eventi live**: i pulsanti mostrano consegna dopo il commit, scarto con rollback, deduplicazione e rifiuto oltre 8000 byte.
5. **Catalogo**: JSONB → FTS (con `monitr` per vedere «forse cercavi») → *Errori di battitura* → *Semantica* → *Ibrida* con «sedia schiena» (la FTS non trova nulla, la ricerca vettoriale sì).
6. **Sicurezza (RLS)**: «Esegui con i tre ruoli» su ciascun tentativo; leggere la differenza tra *errore* (WITH CHECK, privilegi) e *0 righe* (USING, policy restrittive).

## Embedding

I vettori sono calcolati **fuori dal database**. Il provider è configurabile in `.env`:

- `EMBEDDING_PROVIDER=hash` (default): offline, deterministico, nessuna chiave. **Non è un modello semantico**: combina radici di parola, gruppi di sinonimi scritti a mano e trigrammi di caratteri in 256 dimensioni. Basta per mostrare pgvector (HNSW, distanza coseno, ricerca ibrida), non per giudicare la qualità della ricerca semantica.
- `EMBEDDING_PROVIDER=openai`: qualunque endpoint compatibile con `/v1/embeddings` (OpenAI, Ollama, …) con `EMBEDDING_BASE_URL`, `EMBEDDING_MODEL` ed eventualmente `EMBEDDING_API_KEY`. Il modello deve accettare `dimensions=256` (la colonna è `vector(256)`); altrimenti cambiare la dimensione in `01_schema.sql` e in `embedding.js`. Dopo il cambio: `UPDATE shop.products SET embedding = NULL;` e riavviare il sidecar.

Nessuna chiave è nel repository.

## Struttura

```text
orders-app/
├── compose.yaml            PostgreSQL, 3× DAB, sidecar
├── .env.example
├── db/init/                00_roles.sh · 01_schema · 02_triggers_notify · 03_rls · 04_functions · 05_seed
├── dab/dab-config.json     entità DAB (tabelle e viste)
├── sidecar/                ricerche, create_order, LISTEN/NOTIFY→SSE, embedding (+ test)
└── frontend/               React + Vite (7 pagine)
```

## Test

```bash
cd sidecar && npm test            # embedding: dimensione, determinismo, vicinanza
```

La verifica end-to-end (RLS, trigger, NOTIFY, ricerche, interfaccia) è stata eseguita a mano e con un percorso Playwright; non è inclusa come suite nel repository.

## Limiti noti

- Nessuna autenticazione: il selettore «Utente» sceglie il ruolo di database. Le tre istanze DAB sono in modalità `development` (GraphQL introspection attiva).
- Il filtro per regione dell'SSE è una comodità dell'interfaccia, non un confine di sicurezza: il payload contiene solo chiave e stato, e i dati si rileggono con il ruolo dell'utente.
- Il catalogo è in sola lettura da DAB: la tabella `products` ha colonne `vector`/`tsvector` che DAB non mappa, quindi espone la vista `v_products_public`.
- `PATCH`/`PUT` REST di DAB richiedono il permesso `create`; per questo le modifiche agli ordini passano da GraphQL (`updateorder`), e la creazione dal sidecar.
- DAB su PostgreSQL non scrive colonne `jsonb` (REST e GraphQL inviano il valore come `text`: `42804 column is of type jsonb but expression is of type text`). Il form «Nuovo cliente» lascia quindi `profile` al default; i JSONB si scrivono dal sidecar (`create_order` salva `shipping`).
- Il GraphQL di DAB non serializza le colonne `jsonb` (errore `The shipping value could not be parsed for configured GraphQL data type String`): i campi JSONB si leggono dal REST, che li restituisce come JSON nativo.
- La ricerca per testo nell'elenco ordini usa `contains` di DAB, che distingue le maiuscole.
- Le password dei ruoli sono valori di demo (`demo_only`), modificabili in `.env`; non usare in produzione.
- Il recall degli indici approssimati non è misurato su questo dataset.
