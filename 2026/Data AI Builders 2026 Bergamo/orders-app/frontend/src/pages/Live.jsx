import { useEffect, useState } from 'react'
import { useUser, useEvents } from '../lib/context.jsx'
import { sidecar } from '../lib/api.js'
import { dateTime, STATUS } from '../lib/format.js'
import { Card, Empty, ErrorBox, PageHeader, SqlBlock } from '../components/ui.jsx'

const DEMOS = [
  ['immediate', 'NOTIFY immediato', 'Consegnata al commit.'],
  ['committed', 'Dentro una transazione confermata', 'Arriva dopo il COMMIT (0,8 s).'],
  ['rolledback', 'Dentro una transazione annullata', 'Nessun evento: la notifica è scartata.'],
  ['duplicates', '3 notifiche identiche nella stessa transazione', 'Ne arriva una sola.'],
  ['large', 'Payload ~7,9 KB', 'Sotto il limite di 8000 byte.'],
  ['toolarge', 'Payload > 8000 byte', 'PostgreSQL rifiuta la NOTIFY.'],
]

export default function Live() {
  const { user } = useUser()
  const { events, status } = useEvents()
  const [message, setMessage] = useState(null)
  const [error, setError] = useState(null)
  const [queue, setQueue] = useState(null)

  useEffect(() => {
    const load = () => sidecar(user, '/notify/queue').then(setQueue).catch(() => setQueue(null))
    load(); const t = setInterval(load, 4000); return () => clearInterval(t)
  }, [user])

  const demo = async (k) => {
    setError(null); setMessage(null)
    try { setMessage((await sidecar(user, `/notify/demo/${k}`, { method: 'POST' })).message) } catch (e) { setError(e) }
  }

  return (
    <>
      <PageHeader title="Eventi live" subtitle="LISTEN/NOTIFY come bus di eventi: nessun Redis, Kafka o RabbitMQ. Un trigger sulla tabella ordini emette l'evento, il sidecar lo inoltra al browser via Server-Sent Events." />
      <div className="split">
        <div className="split-main">
          <Card title={`Feed (${status === 'open' ? 'connesso' : status})`}>
            {events.length === 0 ? <Empty>Nessun evento ancora. Cambia lo stato di un ordine (pagina Ordini) o usa i pulsanti a destra.</Empty> : (
              <table className="table small">
                <thead><tr><th>Ricevuto</th><th>Canale</th><th>PID</th><th>Payload</th></tr></thead>
                <tbody>{events.map((e) => (
                  <tr key={e.id}><td>{dateTime(e.received_at)}</td><td><code>{e.channel}</code></td><td>{e.pid}</td>
                    <td>{e.channel === 'order_events'
                      ? <><strong>{e.payload.order_number}</strong> {e.payload.event === 'created' ? 'creato' : `${STATUS[e.payload.old_status]?.label} → ${STATUS[e.payload.status]?.label}`} · {e.payload.region} · <code>{e.payload.by}</code></>
                      : <code>{JSON.stringify(e.payload).slice(0, 80)}{JSON.stringify(e.payload).length > 80 ? ` … (${JSON.stringify(e.payload).length} byte)` : ''}</code>}</td></tr>
                ))}</tbody>
              </table>
            )}
          </Card>
        </div>
        <aside className="pg-panel">
          <h3>🐘 Cosa fa PostgreSQL</h3>
          <p className="pg-slide">Le notifiche sono consegnate dopo il commit; con rollback sono scartate. Stesso canale e payload nella stessa transazione: una sola notifica.</p>
          <h4>Prova le garanzie</h4>
          {DEMOS.map(([k, label, hint]) => <div className="demo-btn" key={k}><button className="btn btn-small" onClick={() => demo(k)}>{label}</button><small>{hint}</small></div>)}
          {message && <p className="demo-msg">{message}</p>}
          <ErrorBox error={error} />
          <h4>Coda delle notifiche</h4>
          <p>Uso: <strong>{queue ? `${(queue.usage * 100).toFixed(4)} %` : '—'}</strong> <small className="hint">pg_notification_queue_usage() · coda di 8 GB</small></p>
          <h4>Trigger che emette l'evento</h4>
          <SqlBlock code={`PERFORM pg_notify('order_events', json_build_object(
  'order_id', NEW.id,
  'order_number', NEW.order_number,
  'event', v_type,
  'old_status', OLD.status,
  'status', NEW.status,
  'region', NEW.region
)::text);`} />
          <p className="hint">Il payload porta chiave e stato, non i dati: per contenuti grandi si invia la chiave del record. Il fatto resta persistito in <code>order_events</code>.</p>
          <p className="hint">Il filtro per regione dell'SSE è una comodità dell'interfaccia, non un confine di sicurezza: i dati si rileggono con il ruolo dell'utente. Dopo una riconnessione si rilegge lo stato corrente (pattern raccomandato: LISTEN, poi lettura, poi notifiche).</p>
        </aside>
      </div>
    </>
  )
}
