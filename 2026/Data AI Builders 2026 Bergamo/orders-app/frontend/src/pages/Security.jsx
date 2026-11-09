import { useState } from 'react'
import { useUser } from '../lib/context.jsx'
import { useAsync } from '../lib/hooks.js'
import { sidecar, USERS } from '../lib/api.js'
import { Card, ErrorBox, Loading, PageHeader, SqlBlock } from '../components/ui.jsx'

const USER_KEYS = Object.keys(USERS)

export default function Security() {
  const { user } = useUser()
  const sessions = useAsync(async () => Object.fromEntries(await Promise.all(USER_KEYS.map(async (u) => [u, (await sidecar(u, '/session')).data]))), [])
  const attempts = useAsync(() => sidecar(user, '/rls/attempts'), [])
  const [results, setResults] = useState({})
  const [running, setRunning] = useState(null)

  const run = async (a) => {
    setRunning(a.key)
    try {
      const entries = await Promise.all(USER_KEYS.map(async (u) => [u, await sidecar(u, `/rls/try/${a.key}`, { method: 'POST' })]))
      setResults((r) => ({ ...r, [a.key]: Object.fromEntries(entries) }))
    } finally { setRunning(null) }
  }

  const sample = sessions.data?.[user]

  return (
    <>
      <PageHeader title="Sicurezza a livello di riga" subtitle="Chi vede quali righe lo decide PostgreSQL. Data API Builder ha tre istanze con la stessa configurazione, collegate con ruoli diversi: nessun filtro nell'applicazione." />
      <ErrorBox error={sessions.error} onRetry={sessions.reload} />

      <Card title="Stessa richiesta, ruoli diversi">
        {sessions.loading && !sessions.data ? <Loading /> : (
          <table className="table matrix">
            <thead><tr><th />{USER_KEYS.map((u) => <th key={u} className={u === user ? 'me' : ''}>{USERS[u].label}<small>:{USERS[u].port} · <code>{USERS[u].role}</code></small></th>)}</tr></thead>
            <tbody>
              {[['region', 'app.region (ALTER ROLE … SET)'], ['visible_orders', 'Ordini visibili'], ['visible_customers', 'Clienti visibili'], ['visible_items', 'Righe d\'ordine visibili'], ['visible_events', 'Eventi visibili']].map(([k, label]) => (
                <tr key={k}><th>{label}</th>{USER_KEYS.map((u) => <td key={u} className={u === user ? 'me' : ''}>{sessions.data?.[u]?.session[k]}</td>)}</tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card title="Prova a violare le regole (ogni tentativo gira in una transazione annullata)">
        <ErrorBox error={attempts.error} />
        {(attempts.data ?? []).map((a) => (
          <div className="attempt" key={a.key}>
            <div className="attempt-head"><strong>{a.title}</strong><button className="btn btn-small btn-primary" disabled={running === a.key} onClick={() => run(a)}>{running === a.key ? '…' : 'Esegui con i tre ruoli'}</button></div>
            <SqlBlock code={a.sql.trim()} />
            {results[a.key] && (
              <div className="attempt-results">
                {USER_KEYS.map((u) => {
                  const r = results[a.key][u]
                  return (
                    <div key={u} className={`outcome ${r.ok ? (r.rowCount === 0 ? 'zero' : 'ok') : 'err'}`}>
                      <strong>{USERS[u].label}</strong>
                      {r.ok
                        ? (r.rows.length ? <span>{r.rows.map((x) => Object.values(x).join(': ')).join(' · ')}</span> : <span>{r.rowCount === 0 ? '0 righe interessate (invisibili o escluse da una policy: nessun errore)' : `${r.rowCount} riga/e interessata/e`}</span>)
                        : <span>Errore {r.error.code}: {r.error.message}</span>}
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        ))}
      </Card>

      <div className="grid-2">
        <Card title={`Policy attive (viste da ${USERS[user].label})`}>
          {!sample ? <Loading /> : (
            <table className="table small">
              <thead><tr><th>Tabella</th><th>Policy</th><th>Tipo</th><th>Comando</th></tr></thead>
              <tbody>{sample && sessions.data[user] && attemptsPolicies(sessions.data[user].policies)}</tbody>
            </table>
          )}
          <p className="hint"><strong>USING</strong> = righe esistenti visibili/modificabili (SELECT, UPDATE, DELETE). <strong>WITH CHECK</strong> = righe nuove o modificate ammesse (INSERT, UPDATE). Policy permissive in OR, restrittive in AND.</p>
        </Card>
        <Card title="Chi bypassa la RLS">
          <ul className="plain">
            <li>Superuser e ruoli con <code>BYPASSRLS</code> ignorano sempre le policy.</li>
            <li>Il proprietario della tabella di norma le bypassa: <code>FORCE ROW LEVEL SECURITY</code> lo include.</li>
            <li>I ruoli applicativi qui non sono proprietari né <code>BYPASSRLS</code>: <code>shop_manager</code> vede tutto perché una policy glielo permette, non perché la aggira.</li>
            <li><code>TRUNCATE</code> e <code>REFERENCES</code> non sono soggette a RLS. Anche i controlli di integrità referenziale la bypassano: attenzione ai covert channel.</li>
            <li>Le viste girano coi privilegi del proprietario: qui sono create con <code>security_invoker = true</code> per rispettare la RLS del chiamante.</li>
            <li>Le policy guardano solo la riga corrente (<code>region</code> è denormalizzata): niente sub-SELECT, nessuna race condition.</li>
          </ul>
        </Card>
      </div>
    </>
  )
}

function attemptsPolicies(rows) {
  return rows.map((p) => (
    <tr key={p.table + p.name} title={`USING: ${p.using ?? '—'}\nWITH CHECK: ${p.with_check ?? '—'}`}>
      <td>{p.table}</td><td><code>{p.name}</code></td><td><span className={`tag ${p.permissive === 'RESTRICTIVE' ? 'tag-red' : ''}`}>{p.permissive}</span></td><td>{p.cmd}</td>
    </tr>
  ))
}
