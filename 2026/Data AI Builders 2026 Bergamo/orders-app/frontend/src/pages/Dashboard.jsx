import { useUser, useEvents } from '../lib/context.jsx'
import { useAsync } from '../lib/hooks.js'
import { dabRest } from '../lib/api.js'
import { money, dateShort, dateTime, STATUS, STATUS_ORDER } from '../lib/format.js'
import { Card, ErrorBox, Loading, PageHeader, StatusBadge } from '../components/ui.jsx'

export default function Dashboard() {
  const { user, info } = useUser()
  const { tick } = useEvents()
  const stats = useAsync(() => dabRest(user, '/order-stats'), [user, tick])
  const daily = useAsync(() => dabRest(user, '/orders-daily?$orderby=day desc&$first=30'), [user, tick])
  const recent = useAsync(() => dabRest(user, '/orders-overview?$orderby=placed_at desc&$first=8'), [user, tick])

  const byStatus = Object.fromEntries((stats.data?.value ?? []).map((s) => [s.status, s]))
  const totalOrders = Object.values(byStatus).reduce((a, s) => a + s.orders_count, 0)
  const revenue = Object.entries(byStatus).filter(([k]) => k !== 'cancelled').reduce((a, [, s]) => a + s.revenue, 0)
  const open = ['new', 'confirmed', 'paid', 'shipped'].reduce((a, k) => a + (byStatus[k]?.orders_count ?? 0), 0)

  return (
    <>
      <PageHeader title="Dashboard" subtitle={`Dati visibili con il ruolo ${info.role}: la Row Level Security filtra le righe nel database, non nell'interfaccia.`} />
      <ErrorBox error={stats.error} onRetry={stats.reload} />
      {stats.loading && !stats.data ? <Loading /> : (
        <div className="kpis">
          <div className="kpi"><span>Ordini visibili</span><strong>{totalOrders}</strong></div>
          <div className="kpi"><span>Ordini aperti</span><strong>{open}</strong></div>
          <div className="kpi"><span>Fatturato (esclusi annullati)</span><strong>{money(revenue)}</strong></div>
          <div className="kpi"><span>Da consegnare / spedire</span><strong>{(byStatus.paid?.orders_count ?? 0) + (byStatus.shipped?.orders_count ?? 0)}</strong></div>
        </div>
      )}

      <div className="grid-2">
        <Card title="Ordini per stato">
          {STATUS_ORDER.map((s) => {
            const n = byStatus[s]?.orders_count ?? 0
            return (
              <div className="bar-row" key={s}>
                <span className="bar-label">{STATUS[s].label}</span>
                <div className="bar-track"><div className={`bar-fill tone-${STATUS[s].tone}`} style={{ width: `${totalOrders ? (n / totalOrders) * 100 : 0}%` }} /></div>
                <span className="bar-value">{n}</span>
              </div>
            )
          })}
        </Card>

        <Card title="Ordini negli ultimi 30 giorni con ordini">
          <ErrorBox error={daily.error} onRetry={daily.reload} />
          {daily.loading && !daily.data ? <Loading /> : <DailyChart rows={(daily.data?.value ?? []).slice().reverse()} />}
        </Card>
      </div>

      <Card title="Ultimi ordini">
        <ErrorBox error={recent.error} onRetry={recent.reload} />
        {recent.loading && !recent.data ? <Loading /> : (
          <table className="table">
            <thead><tr><th>Numero</th><th>Cliente</th><th>Regione</th><th>Data</th><th>Stato</th><th className="num">Totale</th></tr></thead>
            <tbody>
              {(recent.data?.value ?? []).map((o) => (
                <tr key={o.id}><td><a href="#orders">{o.order_number}</a></td><td>{o.customer_name}</td><td>{o.region}</td><td>{dateTime(o.placed_at)}</td><td><StatusBadge status={o.status} /></td><td className="num">{money(o.total)}</td></tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </>
  )
}

function DailyChart({ rows }) {
  if (rows.length === 0) return <p className="hint">Nessun ordine.</p>
  const max = Math.max(...rows.map((r) => r.orders_count), 1)
  const w = 560; const h = 170; const pad = 22; const bw = (w - pad) / rows.length
  return (
    <svg viewBox={`0 0 ${w} ${h + 22}`} className="chart" role="img" aria-label="Ordini per giorno">
      {[0, 0.5, 1].map((f) => (
        <g key={f}>
          <line x1={pad} x2={w} y1={h - f * (h - 10)} y2={h - f * (h - 10)} className="grid-line" />
          <text x={0} y={h - f * (h - 10) + 4} className="axis">{Math.round(max * f)}</text>
        </g>
      ))}
      {rows.map((r, i) => {
        const bh = (r.orders_count / max) * (h - 10)
        return (
          <g key={r.day}>
            <rect x={pad + i * bw + 1} y={h - bh} width={Math.max(bw - 2, 1)} height={bh} className="bar-svg"><title>{`${dateShort(r.day)}: ${r.orders_count} ordini, ${money(r.revenue)}`}</title></rect>
            {(i % 6 === 0 || i === rows.length - 1) && <text x={pad + i * bw} y={h + 16} className="axis">{dateShort(r.day)}</text>}
          </g>
        )
      })}
    </svg>
  )
}
