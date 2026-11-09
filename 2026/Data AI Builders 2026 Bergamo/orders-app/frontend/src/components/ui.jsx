import { useEffect, useState, Fragment } from 'react'
import { STATUS } from '../lib/format.js'
import { sidecar } from '../lib/api.js'

export const StatusBadge = ({ status }) => {
  const s = STATUS[status] ?? { label: status, tone: 'gray' }
  return <span className={`badge badge-${s.tone}`}>{s.label}</span>
}

export const Loading = ({ label = 'Caricamento…' }) => <div className="state state-loading" role="status"><span className="spinner" />{label}</div>
export const Empty = ({ children }) => <div className="state state-empty">{children}</div>

export function ErrorBox({ error, onRetry }) {
  if (!error) return null
  return (
    <div className="error-box" role="alert">
      <strong>{error.message}</strong>
      {(error.detail || error.code) && (
        <details>
          <summary>Errore originale{error.source ? ` · ${error.source}` : ''}</summary>
          <pre>{[error.code && `SQLSTATE ${error.code}`, error.detail].filter(Boolean).join('\n')}</pre>
        </details>
      )}
      {onRetry && <button className="btn btn-small" onClick={onRetry}>Riprova</button>}
    </div>
  )
}

const KEYWORDS = /\b(SELECT|FROM|WHERE|AND|OR|NOT|ORDER BY|GROUP BY|LIMIT|OFFSET|UPDATE|SET|DELETE|INSERT INTO|VALUES|RETURNING|CREATE|INDEX|USING|WITH|AS|ON|JOIN|LEFT|IN|IS|NULL|CASE|WHEN|THEN|ELSE|END|DESC|ASC|EXPLAIN|ANALYZE|LISTEN|NOTIFY|BEGIN|COMMIT|ROLLBACK|LOCAL|ILIKE|LIKE|true|false|FUNCTION|RETURNS|RETURN|DECLARE|LANGUAGE|STABLE|TABLE|DEFAULT|EXISTS|DISTINCT|FOR|TO|BY)\b/g

/** Evidenziazione minimale (parole chiave, stringhe, commenti, parametri). Nessun innerHTML. */
export function SqlBlock({ code, maxHeight }) {
  const lines = String(code ?? '').split('\n')
  return (
    <pre className="sql" style={maxHeight ? { maxHeight } : undefined}>
      {lines.map((line, i) => (
        <Fragment key={i}>
          {highlightLine(line)}
          {i < lines.length - 1 ? '\n' : ''}
        </Fragment>
      ))}
    </pre>
  )
}

function highlightLine(line) {
  const comment = line.indexOf('--')
  const code = comment >= 0 ? line.slice(0, comment) : line
  const tail = comment >= 0 ? line.slice(comment) : ''
  const parts = []
  const re = /('(?:[^']|'')*')|(\$\d+)|(\b\d+(?:\.\d+)?\b)/g
  let last = 0; let m; let k = 0
  const pushPlain = (txt) => {
    let l = 0; let km
    KEYWORDS.lastIndex = 0
    while ((km = KEYWORDS.exec(txt))) {
      if (km.index > l) parts.push(txt.slice(l, km.index))
      parts.push(<span key={`k${k++}`} className="tok-kw">{km[0]}</span>)
      l = km.index + km[0].length
    }
    if (l < txt.length) parts.push(txt.slice(l))
  }
  while ((m = re.exec(code))) {
    pushPlain(code.slice(last, m.index))
    parts.push(<span key={`t${k++}`} className={m[1] ? 'tok-str' : m[2] ? 'tok-param' : 'tok-num'}>{m[0]}</span>)
    last = m.index + m[0].length
  }
  pushPlain(code.slice(last))
  if (tail) parts.push(<span key="c" className="tok-com">{tail}</span>)
  return parts
}

/** Testo con <mark> di ts_headline, reso senza innerHTML. */
export function Highlight({ html }) {
  const parts = String(html ?? '').split(/(<mark>.*?<\/mark>)/gs)
  return <>{parts.map((p, i) => (p.startsWith('<mark>') ? <mark key={i}>{p.slice(6, -7)}</mark> : <Fragment key={i}>{p}</Fragment>))}</>
}

const FEATURE_LABEL = {
  jsonb: 'JSONB', fts: 'Full Text Search', trgm: 'pg_trgm', vector: 'pgvector', rls: 'Row Level Security', notify: 'LISTEN / NOTIFY',
}

/** Pannello "Cosa fa PostgreSQL": SQL, parametri, tempo, piano, indici e sorgente della funzione. */
export function PgPanel({ meta, slide, children, indexTable }) {
  const [source, setSource] = useState(null)
  const [indexes, setIndexes] = useState(null)
  useEffect(() => { setSource(null) }, [meta?.function])
  useEffect(() => {
    if (!indexTable) return
    sidecar('manager', `/indexes?table=${indexTable}`).then((r) => setIndexes(r.data)).catch(() => setIndexes(null))
  }, [indexTable])

  const loadSource = async () => {
    const r = await sidecar('manager', `/source?fn=${meta.function}`)
    setSource(r.definition)
  }

  return (
    <aside className="pg-panel" aria-label="Cosa fa PostgreSQL">
      <h3>🐘 Cosa fa PostgreSQL</h3>
      {slide && <p className="pg-slide">{slide}</p>}
      {children}
      {meta ? (
        <>
          <dl className="pg-meta">
            <div><dt>Funzionalità</dt><dd>{FEATURE_LABEL[meta.feature] ?? meta.feature}</dd></div>
            <div><dt>Ruolo DB</dt><dd><code>{meta.role}</code></dd></div>
            {meta.ms !== undefined && <div><dt>Tempo</dt><dd>{meta.ms} ms</dd></div>}
            {meta.rows !== undefined && <div><dt>Righe</dt><dd>{meta.rows}</dd></div>}
          </dl>
          {meta.sql && <><h4>SQL eseguito</h4><SqlBlock code={meta.sql} /></>}
          {meta.params?.length > 0 && (
            <><h4>Parametri</h4><pre className="params">{meta.params.map((p, i) => `$${i + 1} = ${typeof p === 'string' ? JSON.stringify(p) : String(p)}`).join('\n')}</pre></>
          )}
          {meta.plan && (
            <><h4>Piano (EXPLAIN ANALYZE){meta.plan.forced_index ? ' · seq scan disattivato' : ''}</h4>
              <SqlBlock code={meta.plan.sql} />
              <pre className="plan">{meta.plan.text}</pre>
              {meta.plan.forced_index && <p className="hint">Con poche righe il planner sceglie spesso la scansione sequenziale: qui l'uso dell'indice è forzato per mostrarlo. Le prestazioni vanno verificate su dati reali.</p>}
            </>
          )}
          {meta.function && (
            <details onToggle={(e) => e.target.open && !source && loadSource()}>
              <summary>Definizione della funzione <code>shop.{meta.function}</code></summary>
              {source ? <SqlBlock code={source} maxHeight={320} /> : <Loading />}
            </details>
          )}
        </>
      ) : <p className="hint">Esegui un'azione per vedere la query.</p>}
      {indexTable && indexes && (
        <details>
          <summary>Indici su <code>{indexTable}</code></summary>
          <table className="mini-table">
            <tbody>{indexes.map((ix) => (
              <tr key={ix.name}><td><code>{ix.name}</code></td><td>{ix.size}</td><td className="idx-def">{ix.definition.replace(/^CREATE (UNIQUE )?INDEX \S+ ON \S+ /, '')}</td></tr>
            ))}</tbody>
          </table>
        </details>
      )}
    </aside>
  )
}

export function Modal({ title, onClose, children, wide }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal ${wide ? 'modal-wide' : ''}`} role="dialog" aria-modal="true" aria-label={title}>
        <header><h2>{title}</h2><button className="btn-icon" onClick={onClose} aria-label="Chiudi">✕</button></header>
        <div className="modal-body">{children}</div>
      </div>
    </div>
  )
}

export function Toasts({ toasts }) {
  return (
    <div className="toasts" aria-live="polite">
      {toasts.map((t) => <div key={t.id} className={`toast toast-${t.tone ?? 'info'}`}>{t.text}</div>)}
    </div>
  )
}

export function useToasts() {
  const [toasts, setToasts] = useState([])
  const push = (text, tone) => {
    const id = crypto.randomUUID()
    setToasts((t) => [...t, { id, text, tone }])
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 4500)
  }
  return [toasts, push]
}

export const Card = ({ title, actions, children, className = '' }) => (
  <section className={`card ${className}`}>
    {(title || actions) && <header className="card-head">{title && <h2>{title}</h2>}{actions}</header>}
    {children}
  </section>
)

export const PageHeader = ({ title, subtitle, children }) => (
  <div className="page-header"><div><h1>{title}</h1>{subtitle && <p className="subtitle">{subtitle}</p>}</div><div className="page-actions">{children}</div></div>
)
