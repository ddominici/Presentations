import { useState } from 'react'
import { useUser, useEvents } from '../lib/context.jsx'
import { useAsync, useDebounced } from '../lib/hooks.js'
import { dabRest, dabGql, sidecar, qs } from '../lib/api.js'
import { REGIONS } from '../lib/format.js'
import { Card, Empty, ErrorBox, Loading, Modal, PageHeader, PgPanel, Toasts, useToasts, SqlBlock } from '../components/ui.jsx'

export default function Customers() {
  const { user } = useUser()
  const { tick } = useEvents()
  const [text, setText] = useState('')
  const [threshold, setThreshold] = useState(0.3)
  const q = useDebounced(text, 300)
  const th = useDebounced(threshold, 300)
  const [selected, setSelected] = useState(null)
  const [creating, setCreating] = useState(false)
  const [toasts, toast] = useToasts()

  const all = useAsync(() => dabRest(user, '/customers?$orderby=name&$first=200'), [user, tick], { enabled: !q })
  const fuzzy = useAsync(() => sidecar(user, `/search/customers${qs({ q, threshold: th, plan: 1, force_index: 1 })}`), [user, q, th], { enabled: Boolean(q) })

  const rows = q ? fuzzy.data?.data : all.data?.value
  const state = q ? fuzzy : all

  return (
    <>
      <PageHeader title="Clienti" subtitle="Elenco tramite REST di Data API Builder; la ricerca tollerante agli errori usa pg_trgm. Ogni venditore vede solo i clienti della propria regione.">
        <button className="btn btn-primary" onClick={() => setCreating(true)}>+ Nuovo cliente</button>
      </PageHeader>

      <div className="split">
        <div className="split-main">
          <div className="filters">
            <input type="search" placeholder="Cerca un cliente, anche con errori: «rosi», «inpianti»…" value={text} onChange={(e) => setText(e.target.value)} aria-label="Cerca clienti" />
            <label className="slider">Soglia similarità {threshold.toFixed(2)}
              <input type="range" min="0.05" max="0.9" step="0.05" value={threshold} onChange={(e) => setThreshold(Number(e.target.value))} disabled={!q} />
            </label>
          </div>
          <ErrorBox error={state.error} onRetry={state.reload} />
          {state.loading && !rows ? <Loading /> : !rows || rows.length === 0 ? <Empty>{q ? 'Nessun cliente abbastanza simile. Abbassa la soglia.' : 'Nessun cliente visibile.'}</Empty> : (
            <Card>
              <table className="table table-click">
                <thead><tr><th>Codice</th><th>Nome</th><th>Regione</th><th>Email</th>{q ? <th className="num">Similarità</th> : <th>Profilo (JSONB)</th>}</tr></thead>
                <tbody>
                  {rows.map((c) => (
                    <tr key={c.id} onClick={() => setSelected(c.id)} tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && setSelected(c.id)}>
                      <td>{c.code}</td><td><strong>{c.name}</strong></td><td>{REGIONS[c.region]}</td><td>{c.email}</td>
                      {q ? <td className="num"><span className="score" style={{ '--s': c.score }}>{c.score.toFixed(2)}</span></td>
                        : <td>{c.profile?.settore} · {c.profile?.dipendenti} dip. {(c.profile?.tags ?? []).map((t) => <span className="tag" key={t}>{t}</span>)}</td>}
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
          )}
        </div>
        <PgPanel meta={q ? fuzzy.data?.meta : null} indexTable="customers" slide="pg_trgm: trigrammi di tre caratteri; % usa la soglia di similarità, <% la word similarity; l'indice GIN serve anche ILIKE '%…%'.">
          {!q && <p className="hint">Elenco: <code>GET /api/customers</code> di Data API Builder. Digita per usare la ricerca trigram.</p>}
        </PgPanel>
      </div>

      {selected && <CustomerDetail id={selected} onClose={() => setSelected(null)} toast={toast} onChanged={() => { all.reload(); fuzzy.reload() }} />}
      {creating && <NewCustomer onClose={() => setCreating(false)} onCreated={() => { setCreating(false); toast('Cliente creato', 'ok'); all.reload() }} />}
      <Toasts toasts={toasts} />
    </>
  )
}

function CustomerDetail({ id, onClose, toast, onChanged }) {
  const { user } = useUser()
  const c = useAsync(() => dabRest(user, `/customers/id/${Number(id)}`), [user, id])
  const orders = useAsync(() => dabGql(user, `{ orderOverviews(filter: {customer_id: {eq: ${Number(id)}}}, orderBy: {placed_at: DESC}, first: 10) { items { id order_number status total placed_at } } }`), [user, id])
  const [email, setEmail] = useState(null)
  const [error, setError] = useState(null)
  const row = c.data?.value?.[0]

  const save = async () => {
    setError(null)
    try { await dabGql(user, `mutation { updatecustomer(id: ${Number(id)}, item: {email: ${JSON.stringify(email)}}) { id } }`); toast('Email aggiornata', 'ok'); setEmail(null); c.reload(); onChanged() }
    catch (e) { setError(e) }
  }
  const tryDelete = async () => {
    setError(null)
    try { await dabRest(user, `/customers/id/${Number(id)}`, { method: 'DELETE' }) }
    catch (e) { setError(e) }
  }

  return (
    <Modal title={row?.name ?? 'Cliente'} onClose={onClose} wide>
      <ErrorBox error={c.error} />
      {c.loading && !row ? <Loading /> : !row ? <Empty>Cliente non visibile con questo ruolo.</Empty> : (
        <>
          <p><strong>{row.code}</strong> · regione {REGIONS[row.region]} · {email === null
            ? <>{row.email} <button className="btn btn-small" onClick={() => setEmail(row.email ?? '')}>Modifica email</button></>
            : <span className="inline-form"><input value={email} onChange={(e) => setEmail(e.target.value)} aria-label="Email" /><button className="btn btn-small btn-primary" onClick={save}>Salva</button><button className="btn btn-small" onClick={() => setEmail(null)}>Annulla</button></span>}</p>
          <div className="grid-2">
            <Card title="Profilo (JSONB)"><SqlBlock code={JSON.stringify(row.profile, null, 2)} /></Card>
            <Card title="Ultimi ordini">
              {orders.loading ? <Loading /> : (orders.data?.orderOverviews.items ?? []).length === 0 ? <Empty>Nessun ordine.</Empty> : (
                <table className="table"><tbody>{orders.data.orderOverviews.items.map((o) => <tr key={o.id}><td>{o.order_number}</td><td>{o.status}</td><td className="num">{o.total.toFixed(2)} €</td></tr>)}</tbody></table>
              )}
            </Card>
          </div>
          <div className="actions try"><span>Prova le regole:</span><button className="btn btn-small btn-ghost" onClick={tryDelete}>Elimina cliente</button><span className="hint">nessun ruolo di vendita ha DELETE sui clienti: privilegio, prima ancora della RLS</span></div>
          <ErrorBox error={error} />
        </>
      )}
    </Modal>
  )
}

function NewCustomer({ onClose, onCreated }) {
  const { user } = useUser()
  const [f, setF] = useState({ name: '', email: '', region: user === 'milano' ? 'milano' : 'bergamo' })
  const [error, setError] = useState(null)
  const submit = async (e) => {
    e.preventDefault(); setError(null)
    try {
      await dabRest(user, '/customers', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({
        code: `W${Date.now().toString(36).toUpperCase()}`, name: f.name, email: f.email || null, region: f.region,
        // `profile` (jsonb) non si invia: DAB su PostgreSQL scrive i jsonb come text e il database rifiuta (42804). Resta il default '{}'.
      }) })
      onCreated()
    } catch (err) { setError(err) }
  }
  return (
    <Modal title="Nuovo cliente" onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <label>Ragione sociale<input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} required /></label>
        <label>Email<input type="email" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} /></label>
        <label>Regione<select value={f.region} onChange={(e) => setF({ ...f, region: e.target.value })}>{Object.entries(REGIONS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></label>
        <p className="hint">Prova a scegliere una regione diversa dalla tua: la policy <code>WITH CHECK</code> rifiuterà la nuova riga.</p>
        <ErrorBox error={error} />
        <div className="form-actions"><button type="button" className="btn" onClick={onClose}>Annulla</button><button className="btn btn-primary">Crea</button></div>
      </form>
    </Modal>
  )
}
