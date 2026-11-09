import { useEffect, useState } from 'react'
import { useUser, useEvents } from '../lib/context.jsx'
import { useAsync, useDebounced } from '../lib/hooks.js'
import { dabGql, dabRest, sidecar, ApiError } from '../lib/api.js'
import { money, dateTime, STATUS, STATUS_ORDER, NEXT_STATUS } from '../lib/format.js'
import { Card, Empty, ErrorBox, Loading, Modal, PageHeader, StatusBadge, Toasts, useToasts, SqlBlock } from '../components/ui.jsx'

const gqlStr = (s) => JSON.stringify(String(s))   // letterale stringa GraphQL sicuro

function buildFilter({ status, text }) {
  const parts = []
  if (status) parts.push(`{status: {eq: ${gqlStr(status)}}}`)
  if (text) parts.push(`{or: [{order_number: {contains: ${gqlStr(text)}}}, {customer_name: {contains: ${gqlStr(text)}}}]}`)
  return parts.length ? `filter: {and: [${parts.join(', ')}]}, ` : ''
}

const LIST_FIELDS = 'id order_number status region placed_at total customer_name items_count ship_city carrier'

export default function Orders() {
  const { user } = useUser()
  const { tick, onOrderEvent } = useEvents()
  const [status, setStatus] = useState('')
  const [text, setText] = useState('')
  const q = useDebounced(text, 300)
  const [pages, setPages] = useState(1)
  const [selected, setSelected] = useState(null)
  const [creating, setCreating] = useState(false)
  const [toasts, toast] = useToasts()
  const [fresh, setFresh] = useState(new Set())     // righe appena cambiate via NOTIFY

  const list = useAsync(() => dabGql(user, `{ orderOverviews(first: ${pages * 25}, ${buildFilter({ status, text: q })}orderBy: {placed_at: DESC}) { items { ${LIST_FIELDS} } hasNextPage } }`),
    [user, status, q, pages, tick])

  useEffect(() => onOrderEvent((m) => {
    const id = m.payload.order_id
    setFresh((s) => new Set(s).add(id))
    setTimeout(() => setFresh((s) => { const n = new Set(s); n.delete(id); return n }), 3000)
    toast(`${m.payload.order_number}: ${m.payload.event === 'created' ? 'nuovo ordine' : `${STATUS[m.payload.old_status]?.label ?? '?'} → ${STATUS[m.payload.status]?.label}`} (${m.payload.by})`, 'info')
  }), [onOrderEvent]) // eslint-disable-line react-hooks/exhaustive-deps

  const items = list.data?.orderOverviews.items ?? []

  return (
    <>
      <PageHeader title="Ordini" subtitle="Elenco e filtri tramite GraphQL di Data API Builder. Le modifiche dello stato generano eventi NOTIFY: la lista si aggiorna da sola.">
        <button className="btn btn-primary" onClick={() => setCreating(true)}>+ Nuovo ordine</button>
      </PageHeader>

      <div className="filters">
        <div className="chips" role="group" aria-label="Filtro stato">
          <button className={`chip ${status === '' ? 'on' : ''}`} onClick={() => { setStatus(''); setPages(1) }}>Tutti</button>
          {STATUS_ORDER.map((s) => <button key={s} className={`chip ${status === s ? 'on' : ''}`} onClick={() => { setStatus(s); setPages(1) }}>{STATUS[s].label}</button>)}
        </div>
        <input type="search" placeholder="Numero ordine o cliente (distingue maiuscole)" value={text} onChange={(e) => { setText(e.target.value); setPages(1) }} aria-label="Cerca ordini" />
      </div>

      <ErrorBox error={list.error} onRetry={list.reload} />
      {list.loading && !list.data ? <Loading /> : items.length === 0 && !list.error ? <Empty>Nessun ordine con questi filtri.</Empty> : (
        <Card>
          <table className="table table-click">
            <thead><tr><th>Numero</th><th>Cliente</th><th>Regione</th><th>Data</th><th>Righe</th><th>Spedizione</th><th>Stato</th><th className="num">Totale</th></tr></thead>
            <tbody>
              {items.map((o) => (
                <tr key={o.id} className={fresh.has(o.id) ? 'flash' : ''} onClick={() => setSelected(o.id)} tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && setSelected(o.id)}>
                  <td><strong>{o.order_number}</strong></td><td>{o.customer_name}</td><td>{o.region}</td><td>{dateTime(o.placed_at)}</td>
                  <td>{o.items_count}</td><td>{o.ship_city ?? '—'}{o.carrier ? ` · ${o.carrier}` : ''}</td>
                  <td><StatusBadge status={o.status} /></td><td className="num">{money(o.total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {list.data?.orderOverviews.hasNextPage && <div className="more"><button className="btn" onClick={() => setPages((p) => p + 1)}>Carica altri</button></div>}
        </Card>
      )}

      {selected && <OrderDetail id={selected} onClose={() => setSelected(null)} onChanged={list.reload} toast={toast} />}
      {creating && <NewOrder onClose={() => setCreating(false)} onCreated={(o) => { setCreating(false); toast(`Creato ${o.order_number}`, 'ok'); list.reload() }} />}
      <Toasts toasts={toasts} />
    </>
  )
}

function OrderDetail({ id, onClose, onChanged, toast }) {
  const { user } = useUser()
  const { tick } = useEvents()
  const [actionError, setActionError] = useState(null)
  const [busy, setBusy] = useState(false)
  const [notes, setNotes] = useState(null)

  // La riga ordine passa dal REST (le colonne jsonb come `shipping` il GraphQL di DAB non le serializza);
  // righe e storico dal GraphQL.
  const detail = useAsync(async () => {
    const [row, rest] = await Promise.all([
      dabRest(user, `/orders/id/${Number(id)}`),
      dabGql(user, `{
        orderLines(filter: {order_id: {eq: ${Number(id)}}}, first: 50) { items { id sku product_name quantity unit_price line_total } }
        orderEvents(filter: {order_id: {eq: ${Number(id)}}}, orderBy: {created_at: DESC}, first: 20) { items { id event_type old_status new_status changed_by created_at } }
      }`),
    ])
    return { order: row.value?.[0] ?? null, ...rest }
  }, [user, id, tick])

  const o = detail.data?.order

  const mutate = async (query, okText) => {
    setBusy(true); setActionError(null)
    try { const r = await dabGql(user, query); toast(okText, 'ok'); onChanged(); await detail.reload(); return r }
    catch (e) { setActionError(e) }
    finally { setBusy(false) }
  }
  const setStatus = (s) => mutate(`mutation { updateorder(id: ${Number(id)}, item: {status: ${gqlStr(s)}}) { id status } }`, `Stato aggiornato: ${STATUS[s].label}`)
  const saveNotes = () => mutate(`mutation { updateorder(id: ${Number(id)}, item: {notes: ${gqlStr(notes)}}) { id } }`, 'Note salvate').then(() => setNotes(null))
  const remove = async () => {
    setBusy(true); setActionError(null)
    try {
      const r = await dabGql(user, `mutation { deleteorder(id: ${Number(id)}) { id } }`)
      if (!r.deleteorder) throw new ApiError('Eliminazione rifiutata: la policy RESTRICTIVE ammette solo ordini in stato «Nuovo» (il manager può tutto).', { source: 'Row Level Security', detail: 'DELETE: 0 righe interessate' })
      toast('Ordine eliminato', 'ok'); onChanged(); onClose()
    } catch (e) { setActionError(e) } finally { setBusy(false) }
  }
  // Scorciatoie per mostrare l'effetto delle regole del database
  const forbidden = (label, query) => (
    <button className="btn btn-small btn-ghost" disabled={busy} onClick={() => mutate(query, label)} title="Provoca un errore voluto del database">{label}</button>
  )

  return (
    <Modal title={o ? `Ordine ${o.order_number}` : 'Ordine'} onClose={onClose} wide>
      <ErrorBox error={detail.error} onRetry={detail.reload} />
      {detail.loading && !o ? <Loading /> : !o ? <Empty>Ordine non trovato o non visibile con questo ruolo.</Empty> : (
        <>
          <div className="detail-head">
            <StatusBadge status={o.status} />
            <span>Regione <strong>{o.region}</strong></span><span>Creato {dateTime(o.placed_at)}</span><span>Aggiornato {dateTime(o.updated_at)}</span>
            <span className="grow" /><strong className="big">{money(o.total)}</strong>
          </div>

          <div className="actions">
            <span>Avanza stato:</span>
            {NEXT_STATUS[o.status].map((s) => <button key={s} className={`btn ${s === 'cancelled' ? 'btn-danger' : 'btn-primary'}`} disabled={busy} onClick={() => setStatus(s)}>{STATUS[s].label}</button>)}
            {NEXT_STATUS[o.status].length === 0 && <em className="hint">stato finale</em>}
            <span className="grow" />
            <button className="btn btn-danger btn-ghost" disabled={busy} onClick={remove}>Elimina</button>
          </div>
          <div className="actions try">
            <span>Prova le regole:</span>
            {forbidden('Salta a «Consegnato»', `mutation { updateorder(id: ${Number(id)}, item: {status: "delivered"}) { id } }`)}
            {forbidden(`Sposta in altra regione`, `mutation { updateorder(id: ${Number(id)}, item: {region: ${gqlStr(o.region === 'milano' ? 'bergamo' : 'milano')}}) { id } }`)}
          </div>
          <ErrorBox error={actionError} />

          <div className="grid-2">
            <Card title="Righe">
              <table className="table"><thead><tr><th>Prodotto</th><th className="num">Q.tà</th><th className="num">Prezzo</th><th className="num">Totale</th></tr></thead>
                <tbody>{(detail.data.orderLines.items).map((l) => <tr key={l.id}><td>{l.product_name}<small className="sku">{l.sku}</small></td><td className="num">{l.quantity}</td><td className="num">{money(l.unit_price)}</td><td className="num">{money(l.line_total)}</td></tr>)}</tbody>
              </table>
            </Card>
            <Card title="Spedizione (JSONB)">
              <SqlBlock code={JSON.stringify(o.shipping, null, 2)} />
              {notes === null ? (
                <p>Note: {o.notes ?? <em className="hint">nessuna</em>} <button className="btn btn-small" onClick={() => setNotes(o.notes ?? '')}>Modifica</button></p>
              ) : (
                <div className="inline-form"><input value={notes} onChange={(e) => setNotes(e.target.value)} aria-label="Note" /><button className="btn btn-primary btn-small" disabled={busy} onClick={saveNotes}>Salva</button><button className="btn btn-small" onClick={() => setNotes(null)}>Annulla</button></div>
              )}
            </Card>
          </div>

          <Card title="Storico (tabella order_events, alimentata dal trigger)">
            <table className="table"><thead><tr><th>Quando</th><th>Evento</th><th>Transizione</th><th>Utente DB</th></tr></thead>
              <tbody>{detail.data.orderEvents.items.map((e) => (
                <tr key={e.id}><td>{dateTime(e.created_at)}</td><td>{e.event_type}</td><td>{e.old_status ? `${STATUS[e.old_status]?.label} → ` : ''}{STATUS[e.new_status]?.label}</td><td><code>{e.changed_by}</code></td></tr>
              ))}</tbody>
            </table>
          </Card>
        </>
      )}
    </Modal>
  )
}

function NewOrder({ onClose, onCreated }) {
  const { user } = useUser()
  const customers = useAsync(() => dabRest(user, '/customers?$orderby=name&$first=200&$select=id,name,region'), [user])
  const products = useAsync(() => dabRest(user, '/products?$orderby=name&$first=100&$select=id,name,price,stock'), [])
  const [customerId, setCustomerId] = useState('')
  const [lines, setLines] = useState([{ product_id: '', quantity: 1 }])
  const [ship, setShip] = useState({ indirizzo: '', citta: '', corriere: 'BRT', fascia: 'mattina' })
  const [notes, setNotes] = useState('')
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)

  const priceOf = (id) => products.data?.value.find((p) => p.id === Number(id))?.price ?? 0
  const total = lines.reduce((a, l) => a + priceOf(l.product_id) * (Number(l.quantity) || 0), 0)
  const valid = customerId && lines.every((l) => l.product_id && Number(l.quantity) >= 1)

  const submit = async (e) => {
    e.preventDefault(); setBusy(true); setError(null)
    try {
      const r = await sidecar(user, '/create-order', { method: 'POST', body: {
        customer_id: Number(customerId),
        items: lines.map((l) => ({ product_id: Number(l.product_id), quantity: Number(l.quantity) })),
        shipping: { indirizzo: ship.indirizzo, citta: ship.citta, corriere: ship.corriere, consegna: { fascia: ship.fascia } },
        notes: notes || null,
      } })
      onCreated(r.data)
    } catch (err) { setError(err) } finally { setBusy(false) }
  }

  return (
    <Modal title="Nuovo ordine" onClose={onClose} wide>
      <form onSubmit={submit} className="form">
        <ErrorBox error={customers.error ?? products.error} />
        <label>Cliente
          <select value={customerId} onChange={(e) => { setCustomerId(e.target.value); const c = customers.data?.value.find((x) => x.id === Number(e.target.value)); if (c && !ship.citta) setShip({ ...ship, citta: c.region[0].toUpperCase() + c.region.slice(1) }) }} required>
            <option value="">— scegli —</option>
            {(customers.data?.value ?? []).map((c) => <option key={c.id} value={c.id}>{c.name} ({c.region})</option>)}
          </select>
        </label>
        <fieldset><legend>Righe</legend>
          {lines.map((l, i) => (
            <div className="line-row" key={i}>
              <select value={l.product_id} onChange={(e) => setLines(lines.map((x, j) => (j === i ? { ...x, product_id: e.target.value } : x)))} required aria-label={`Prodotto riga ${i + 1}`}>
                <option value="">— prodotto —</option>
                {(products.data?.value ?? []).map((p) => <option key={p.id} value={p.id}>{p.name} · {money(p.price)}</option>)}
              </select>
              <input type="number" min="1" max="1000" value={l.quantity} onChange={(e) => setLines(lines.map((x, j) => (j === i ? { ...x, quantity: e.target.value } : x)))} aria-label={`Quantità riga ${i + 1}`} />
              <span className="num">{money(priceOf(l.product_id) * (Number(l.quantity) || 0))}</span>
              <button type="button" className="btn-icon" disabled={lines.length === 1} onClick={() => setLines(lines.filter((_, j) => j !== i))} aria-label="Rimuovi riga">✕</button>
            </div>
          ))}
          <button type="button" className="btn btn-small" onClick={() => setLines([...lines, { product_id: '', quantity: 1 }])}>+ Riga</button>
          <strong className="big right">{money(total)}</strong>
        </fieldset>
        <fieldset><legend>Spedizione (salvata come JSONB)</legend>
          <div className="form-grid">
            <label>Indirizzo<input value={ship.indirizzo} onChange={(e) => setShip({ ...ship, indirizzo: e.target.value })} /></label>
            <label>Città<input value={ship.citta} onChange={(e) => setShip({ ...ship, citta: e.target.value })} /></label>
            <label>Corriere<select value={ship.corriere} onChange={(e) => setShip({ ...ship, corriere: e.target.value })}>{['BRT', 'GLS', 'SDA', 'DHL'].map((c) => <option key={c}>{c}</option>)}</select></label>
            <label>Fascia<select value={ship.fascia} onChange={(e) => setShip({ ...ship, fascia: e.target.value })}><option>mattina</option><option>pomeriggio</option></select></label>
          </div>
        </fieldset>
        <label>Note<input value={notes} onChange={(e) => setNotes(e.target.value)} /></label>
        <p className="hint">L'ordine e le righe sono creati in un'unica transazione dalla funzione <code>shop.create_order</code>, con il tuo ruolo: la RLS decide se il cliente è accessibile. Il totale è calcolato da un trigger.</p>
        <ErrorBox error={error} />
        <div className="form-actions"><button type="button" className="btn" onClick={onClose}>Annulla</button><button className="btn btn-primary" disabled={!valid || busy}>{busy ? 'Creazione…' : 'Crea ordine'}</button></div>
      </form>
    </Modal>
  )
}
