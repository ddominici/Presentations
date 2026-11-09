import { useEffect, useState } from 'react'
import { useUser } from '../lib/context.jsx'
import { useAsync, useDebounced } from '../lib/hooks.js'
import { dabRest, sidecar, qs } from '../lib/api.js'
import { money } from '../lib/format.js'
import { Card, Empty, ErrorBox, Highlight, Loading, PageHeader, PgPanel, SqlBlock } from '../components/ui.jsx'

const MODES = [
  { id: 'list', label: 'Elenco', slide: 'Elenco dal backend Data API Builder (vista v_products_public).' },
  { id: 'jsonb', label: 'Attributi (JSONB)', slide: 'JSONB: @> contenimento, ? esistenza chiave, @? SQL/JSON path. Indice GIN jsonb_path_ops: più piccolo e veloce, ma senza l\'operatore ?.' },
  { id: 'fts', label: 'Testo (FTS)', slide: 'tsvector (documento, colonna generata con pesi A/B/C) + tsquery; operatore @@; indice GIN; configurazione linguistica «italian» esplicita.' },
  { id: 'fuzzy', label: 'Errori di battitura (pg_trgm)', slide: 'Trigrammi: similarity(), word_similarity(), strict_word_similarity(); soglia modificabile; indice GIN gin_trgm_ops.' },
  { id: 'semantic', label: 'Semantica (pgvector)', slide: 'Embedding calcolato fuori dal database; distanza coseno con <=>; indice HNSW con vector_cosine_ops.' },
  { id: 'hybrid', label: 'Ibrida (RRF)', slide: 'FTS + vettoriale uniti con Reciprocal Rank Fusion: score = Σ 1 / (60 + posizione).' },
]

export default function Catalog() {
  const [mode, setMode] = useState('list')
  const [similarTo, setSimilarTo] = useState(null)
  const [meta, setMeta] = useState(null)
  const current = MODES.find((m) => m.id === mode)
  useEffect(() => setMeta(null), [mode])

  return (
    <>
      <PageHeader title="Catalogo e ricerca" subtitle="Lo stesso motore PostgreSQL risponde a ricerche strutturate, testuali, fuzzy e semantiche: nessun Elasticsearch, nessun vector database." />
      <div className="tabs" role="tablist">
        {MODES.map((m) => <button key={m.id} role="tab" aria-selected={mode === m.id} className={`tab ${mode === m.id ? 'on' : ''}`} onClick={() => setMode(m.id)}>{m.label}</button>)}
      </div>
      <div className="split">
        <div className="split-main">
          {mode === 'list' && <ProductList onSimilar={setSimilarTo} />}
          {mode === 'jsonb' && <JsonbSearch onMeta={setMeta} onSimilar={setSimilarTo} />}
          {mode === 'fts' && <FtsSearch onMeta={setMeta} onSimilar={setSimilarTo} />}
          {mode === 'fuzzy' && <FuzzySearch onMeta={setMeta} onSimilar={setSimilarTo} />}
          {mode === 'semantic' && <TextSearch endpoint="semantic" mode="semantic" presets={['computer portatile per lavorare in viaggio', 'qualcosa per non stancare la schiena', 'collegare più schermi con un solo cavo', 'sentire bene le riunioni online']} onMeta={setMeta} onSimilar={setSimilarTo} columns={['distance']} />}
          {mode === 'hybrid' && <TextSearch endpoint="hybrid" mode="hybrid" presets={['sedia schiena', 'cuffie riunioni', 'stampare documenti ufficio', 'monitor 4K']} onMeta={setMeta} onSimilar={setSimilarTo} columns={['fts_rank', 'semantic_rank', 'rrf_score']} />}
          {similarTo && <Similar product={similarTo} onClose={() => setSimilarTo(null)} />}
        </div>
        <PgPanel meta={meta} slide={current.slide} indexTable="products">
          {mode === 'semantic' && <HealthNote />}
          {mode === 'hybrid' && <p className="hint">Una riga senza posizione FTS significa che la ricerca testuale non l'ha trovata: la ricerca vettoriale la recupera comunque.</p>}
        </PgPanel>
      </div>
    </>
  )
}

function HealthNote() {
  const h = useAsync(() => fetch('/sidecar/api/health').then((r) => r.json()), [])
  if (!h.data) return null
  return <p className="hint">Provider embedding: <strong>{h.data.embedding}</strong>, {h.data.dimensions} dimensioni. {h.data.embedding.startsWith('hash') ? 'Il provider offline non è un modello semantico: collega un modello reale (vedi README) per risultati di qualità.' : ''}</p>
}

const Price = ({ p }) => <span className="price">{money(p)}</span>

function ProductRow({ p, extra, onSimilar }) {
  return (
    <tr>
      <td><strong>{p.name}</strong><small className="sku">{p.sku} · {p.category}</small>{p.headline && <div className="headline"><Highlight html={p.headline} /></div>}</td>
      {extra}
      <td className="num"><Price p={p.price} /></td>
      <td><button className="btn btn-small btn-ghost" onClick={() => onSimilar(p)} title="Prodotti simili (pgvector)">Simili</button></td>
    </tr>
  )
}

function ProductList({ onSimilar }) {
  const { user } = useUser()
  const [cat, setCat] = useState('')
  const [sort, setSort] = useState('name')
  const res = useAsync(() => dabRest(user, `/products?$orderby=${sort}${cat ? `&$filter=category eq '${cat}'` : ''}&$first=100`), [user, cat, sort])
  const cats = ['computer', 'monitor', 'periferiche', 'audio', 'video', 'arredo', 'rete', 'accessori', 'storage', 'stampanti']
  return (
    <>
      <div className="filters">
        <div className="chips"><button className={`chip ${!cat ? 'on' : ''}`} onClick={() => setCat('')}>Tutte</button>{cats.map((c) => <button key={c} className={`chip ${cat === c ? 'on' : ''}`} onClick={() => setCat(c)}>{c}</button>)}</div>
        <label>Ordina <select value={sort} onChange={(e) => setSort(e.target.value)}><option value="name">nome</option><option value="price asc">prezzo ↑</option><option value="price desc">prezzo ↓</option></select></label>
      </div>
      <ErrorBox error={res.error} onRetry={res.reload} />
      {res.loading && !res.data ? <Loading /> : (
        <Card><table className="table"><tbody>
          {(res.data?.value ?? []).map((p) => (
            <ProductRow key={p.id} p={p} onSimilar={onSimilar} extra={<td><details><summary>attributi</summary><SqlBlock code={JSON.stringify(p.attributes, null, 1)} /></details></td>} />
          ))}</tbody></table></Card>
      )}
    </>
  )
}

function useSearch(endpoint, params, enabled, onMeta, { plan = true } = {}) {
  const { user } = useUser()
  const [showPlan, setShowPlan] = useState(plan)
  const res = useAsync(() => sidecar(user, `/search/${endpoint}${qs({ ...params, plan: showPlan ? 1 : '', force_index: showPlan ? 1 : '' })}`), [user, endpoint, JSON.stringify(params), showPlan], { enabled })
  useEffect(() => { if (res.data) onMeta(res.data.meta) }, [res.data]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (res.error) onMeta(null) }, [res.error]) // eslint-disable-line react-hooks/exhaustive-deps
  return { ...res, showPlan, setShowPlan }
}

const PlanToggle = ({ s }) => <label className="check"><input type="checkbox" checked={s.showPlan} onChange={(e) => s.setShowPlan(e.target.checked)} /> Mostra il piano (EXPLAIN ANALYZE, indice forzato)</label>

function JsonbSearch({ onMeta, onSimilar }) {
  const PRESETS = [
    { label: 'Bluetooth (@>)', contains: '{"connessioni":["bluetooth"]}' },
    { label: 'Garanzia 60 mesi (@>)', contains: '{"garanzia_mesi":60}' },
    { label: 'RAM ≥ 16 GB (@? path)', path: '$.ram_gb ? (@ >= 16)' },
    { label: 'Ha la chiave «poe» (?)', has_key: 'poe' },
    { label: 'Colore nero e USB-C (@>)', contains: '{"colore":"nero","connessioni":["usb-c"]}' },
  ]
  const [f, setF] = useState({ contains: PRESETS[0].contains, has_key: '', path: '' })
  const p = useDebounced(f, 400)
  const s = useSearch('attributes', p, Boolean(p.contains || p.has_key || p.path), onMeta)
  return (
    <>
      <div className="chips">{PRESETS.map((x) => <button key={x.label} className="chip" onClick={() => setF({ contains: x.contains ?? '', has_key: x.has_key ?? '', path: x.path ?? '' })}>{x.label}</button>)}</div>
      <div className="form-grid">
        <label>{'Contiene (@>, JSON)'}<input value={f.contains} onChange={(e) => setF({ ...f, contains: e.target.value })} className="mono" /></label>
        <label>Ha la chiave (?)<input value={f.has_key} onChange={(e) => setF({ ...f, has_key: e.target.value })} className="mono" /></label>
        <label>SQL/JSON path (@?)<input value={f.path} onChange={(e) => setF({ ...f, path: e.target.value })} className="mono" placeholder='$.ram_gb ? (@ >= 16)' /></label>
      </div>
      <PlanToggle s={s} />
      <Results s={s} onSimilar={onSimilar} extra={(p) => <td><SqlBlock code={JSON.stringify(p.attributes)} /></td>} />
    </>
  )
}

function FtsSearch({ onMeta, onSimilar }) {
  const [text, setText] = useState('sedia ergonomica')
  const q = useDebounced(text, 350)
  const s = useSearch('fts', { q }, Boolean(q.trim()), onMeta)
  const phases = useAsync(() => sidecar('manager', `/search/fts-explain${qs({ q })}`), [q], { enabled: Boolean(q.trim()) })
  const suggest = useAsync(() => sidecar('manager', `/search/suggest${qs({ q: q.split(/\s+/).pop() })}`), [q], { enabled: Boolean(q.trim()) && s.data?.data.length === 0 })
  return (
    <>
      <SearchBox value={text} onChange={setText} presets={['sedia ergonomica', 'portatile leggero', 'wifi -ufficio', '"scrivania regolabile"', 'cuffie OR webcam']} placeholder="Cerca nel catalogo (sintassi web: virgolette, OR, -esclusione)" />
      <PlanToggle s={s} />
      {phases.data && (
        <Card title="Le tre fasi: parsing → lexemi → archiviazione/ricerca" className="phases">
          <p><strong>tsquery</strong> (la tua ricerca normalizzata): <code>{phases.data.data[0].tsquery_text || '(vuota: solo stop word)'}</code></p>
          <p><strong>tsvector</strong> (se fosse un documento): <code>{phases.data.data[0].tsvector_text}</code></p>
        </Card>
      )}
      <Results s={s} onSimilar={onSimilar} columns={[['rank', 'Rank', (p) => p.rank.toFixed(3)]]} />
      {s.data?.data.length === 0 && suggest.data?.data.length > 0 && (
        <p className="did-you-mean">Forse cercavi: {suggest.data.data.map((w) => <button key={w.word} className="chip" onClick={() => setText(w.word)}>{w.word}</button>)} <small className="hint">(FTS + pg_trgm su ts_stat; tabella statica da rigenerare)</small></p>
      )}
    </>
  )
}

function FuzzySearch({ onMeta, onSimilar }) {
  const [text, setText] = useState('tastera')
  const [threshold, setThreshold] = useState(0.3)
  const q = useDebounced(text, 350)
  const th = useDebounced(threshold, 300)
  const s = useSearch('fuzzy', { q, threshold: th }, Boolean(q.trim()), onMeta)
  const grams = useAsync(() => sidecar('manager', `/search/trigrams${qs({ q })}`), [q], { enabled: Boolean(q.trim()) })
  return (
    <>
      <SearchBox value={text} onChange={setText} presets={['tastera', 'monitr 4k', 'stampnate', 'webcamm', 'scrivnia']} placeholder="Scrivi con errori di battitura…" />
      <label className="slider">Soglia pg_trgm.similarity_threshold: {threshold.toFixed(2)}<input type="range" min="0.05" max="0.9" step="0.05" value={threshold} onChange={(e) => setThreshold(Number(e.target.value))} /></label>
      <PlanToggle s={s} />
      {grams.data && <p className="grams">Trigrammi di «{q}»: {grams.data.data.map((g) => <code key={g.trigram}>{g.trigram.replace(/ /g, '·')}</code>)}</p>}
      <Results s={s} onSimilar={onSimilar} columns={[['similarity', 'similarity', (p) => p.similarity.toFixed(2)], ['word_similarity', 'word_sim.', (p) => p.word_similarity.toFixed(2)], ['strict_word_similarity', 'strict', (p) => p.strict_word_similarity.toFixed(2)]]} />
    </>
  )
}

function TextSearch({ endpoint, mode, presets, onMeta, onSimilar, columns }) {
  const [text, setText] = useState(presets[0])
  const q = useDebounced(text, 400)
  const s = useSearch(endpoint, { q }, Boolean(q.trim()), onMeta, { plan: mode === 'semantic' })
  const defs = {
    distance: ['distance', 'Distanza coseno', (p) => p.distance.toFixed(3)],
    fts_rank: ['fts_rank', 'Pos. FTS', (p) => p.fts_rank ?? '—'],
    semantic_rank: ['semantic_rank', 'Pos. vettoriale', (p) => p.semantic_rank ?? '—'],
    rrf_score: ['rrf_score', 'Score RRF', (p) => p.rrf_score.toFixed(4)],
  }
  return (
    <>
      <SearchBox value={text} onChange={setText} presets={presets} placeholder="Descrivi cosa cerchi con parole tue…" />
      {mode === 'semantic' && <PlanToggle s={s} />}
      <Results s={s} onSimilar={onSimilar} columns={columns.map((c) => defs[c])} />
    </>
  )
}

function SearchBox({ value, onChange, presets, placeholder }) {
  return (
    <>
      <input type="search" className="big-input" value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} aria-label="Testo di ricerca" />
      <div className="chips">{presets.map((p) => <button key={p} className="chip" onClick={() => onChange(p)}>{p}</button>)}</div>
    </>
  )
}

function Results({ s, columns = [], extra, onSimilar }) {
  if (s.error) return <ErrorBox error={s.error} onRetry={s.reload} />
  if (s.loading && !s.data) return <Loading />
  if (!s.data) return <Empty>Scrivi qualcosa da cercare.</Empty>
  if (s.data.data.length === 0) return <Empty>Nessun risultato.</Empty>
  return (
    <Card>
      <table className="table">
        <thead><tr><th>Prodotto</th>{columns.map((c) => <th key={c[0]} className="num">{c[1]}</th>)}{extra && <th>Attributi</th>}<th className="num">Prezzo</th><th /></tr></thead>
        <tbody>
          {s.data.data.map((p) => (
            <ProductRow key={p.id} p={p} onSimilar={onSimilar} extra={<>{columns.map((c) => <td key={c[0]} className="num">{c[2](p)}</td>)}{extra?.(p)}</>} />
          ))}
        </tbody>
      </table>
    </Card>
  )
}

function Similar({ product, onClose }) {
  const { user } = useUser()
  const res = useAsync(() => sidecar(user, `/search/similar${qs({ product_id: product.id, limit: 5 })}`), [user, product.id])
  return (
    <Card title={`Prodotti simili a «${product.name}» (pgvector, distanza coseno)`} actions={<button className="btn btn-small" onClick={onClose}>Chiudi</button>}>
      <ErrorBox error={res.error} />
      {res.loading ? <Loading /> : (
        <ol className="similar">{(res.data?.data ?? []).map((p) => <li key={p.id}>{p.name} <small className="sku">distanza {p.distance.toFixed(3)}</small></li>)}</ol>
      )}
      <p className="hint">Il vettore di partenza è già nel database: la ricerca per similarità non richiede nessun provider esterno.</p>
    </Card>
  )
}
