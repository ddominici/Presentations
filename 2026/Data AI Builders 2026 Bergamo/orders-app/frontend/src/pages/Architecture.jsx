import { PageHeader, Card } from '../components/ui.jsx'

const ROWS = [
  ['Dati documentali', 'jsonb', 'GIN (jsonb_path_ops / espressione)', 'Attributi prodotto, profilo cliente, spedizione', 'Catalogo → Attributi · Ordini'],
  ['Ricerca testuale', 'tsvector / tsquery', 'GIN', 'Colonna generata con pesi, configurazione «italian»', 'Catalogo → Testo'],
  ['Ricerca fuzzy, LIKE', 'pg_trgm', 'GIN gin_trgm_ops', 'Clienti e prodotti con errori di battitura; «forse cercavi»', 'Clienti · Catalogo → Errori di battitura'],
  ['Semantic search', 'pgvector', 'HNSW vector_cosine_ops', 'Ricerca per significato, prodotti simili, ricerca ibrida RRF', 'Catalogo → Semantica / Ibrida'],
  ['Accesso per riga', 'Row Level Security', '—', 'Un venditore per regione, ordini chiusi in sola lettura', 'Sicurezza (RLS)'],
  ['Eventi', 'LISTEN / NOTIFY', '—', 'Feed ordini in tempo reale', 'Eventi live · Ordini'],
]

export default function Architecture() {
  return (
    <>
      <PageHeader title="Architettura" subtitle="Un solo motore dati. Meno componenti, meno complessità." />
      <Card title="Esigenza → funzionalità PostgreSQL → dove si vede">
        <table className="table"><thead><tr><th>Esigenza</th><th>Funzionalità</th><th>Indice tipico</th><th>Nell'app</th><th>Pagina</th></tr></thead>
          <tbody>{ROWS.map((r) => <tr key={r[0]}>{r.map((c, i) => <td key={i}>{i === 0 ? <strong>{c}</strong> : c}</td>)}</tr>)}</tbody></table>
      </Card>
      <Card title="Come sono collegati i pezzi">
        <pre className="diagram">{`  Browser (React + Vite)
     │  /dab/<utente>/…  REST + GraphQL            /sidecar/…  ricerche, create_order, SSE
     ▼                                                    ▼
  Data API Builder ×3  (stessa config, ruoli DB diversi)   Sidecar Node
  :5001 rep_bergamo  :5002 rep_milano  :5003 shop_manager   :5004  (stessi ruoli, + LISTEN dedicato)
     │                                                    │
     └───────────────────────┬────────────────────────────┘
                             ▼
            PostgreSQL 18 · pg_trgm · pgvector
            RLS · trigger · funzioni · viste security_invoker`}</pre>
        <ul className="plain">
          <li><strong>Data API Builder</strong> espone tabelle e viste (CRUD, filtri, paginazione, GraphQL). Su PostgreSQL non espone funzioni/stored procedure: per questo le ricerche passano dal sidecar.</li>
          <li><strong>Il ruolo di database è l'identità</strong>: ogni istanza DAB si collega con un ruolo diverso, quindi la RLS vale identica da DAB e dal sidecar. L'autenticazione utente non è implementata (demo): in produzione servono un provider e claim mappati sui ruoli.</li>
          <li><strong>Embedding fuori dal database</strong>, calcolati una volta sola e salvati in una colonna <code>vector(256)</code>; il provider è configurabile.</li>
        </ul>
      </Card>
      <Card title="Prima di aggiungere un altro sistema">
        <ul className="plain">
          <li><strong>NOTIFY</strong>: payload sotto 8000 byte e coda da 8 GB bastano? → pagina Eventi live (prova payload oltre il limite).</li>
          <li><strong>pgvector</strong>: i limiti di dimensione indicizzabile (vector fino a 2.000 dimensioni) coprono i tuoi embedding? Qui 256.</li>
          <li><strong>Ricerca vettoriale filtrata</strong>: gli indici approssimati applicano i filtri dopo la scansione e possono restituire meno righe (iterative scan da pgvector 0.8.0).</li>
          <li><strong>RLS</strong>: policy semplici o con sub-SELECT? Qui solo espressioni sulla riga corrente.</li>
          <li><strong>FTS</strong>: configurazione linguistica e tipo di indice (GIN/GiST) scelti consapevolmente? Qui «italian» e GIN.</li>
        </ul>
      </Card>
    </>
  )
}
