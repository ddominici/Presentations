import { useEffect, useState } from 'react'
import { getPolicySummary } from '../api'

const STATUSES = ['', 'active', 'lapsed', 'cancelled', 'pending']

export default function PolicySummaryTable({ refreshToken, onRowsLoaded }) {
  const [status, setStatus] = useState('')
  const [rows, setRows] = useState([])
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = () => {
    setLoading(true)
    setError(null)
    getPolicySummary({ status: status || undefined })
      .then((body) => {
        const items = body?.value ?? []
        setRows(items)
        onRowsLoaded?.(items)
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false))
  }

  useEffect(load, [status, refreshToken])

  return (
    <section className="card">
      <div className="card-header">
        <h2>View: dbo.vw_PolicySummary</h2>
        <div className="toolbar">
          <label>
            Status
            <select value={status} onChange={(e) => setStatus(e.target.value)}>
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s || 'all'}
                </option>
              ))}
            </select>
          </label>
          <button onClick={load} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </div>

      {error && <p className="error">GET /api/policy-summary → {error}</p>}

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Policy</th>
              <th>Product</th>
              <th>Status</th>
              <th>Premium</th>
              <th>Broker</th>
              <th>City</th>
              <th>Expiry (days)</th>
            </tr>
          </thead>
          <tbody>
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={7} className="empty">
                  No rows.
                </td>
              </tr>
            )}
            {rows.map((r) => (
              <tr key={r.policy_id}>
                <td>{r.policy_number}</td>
                <td>{r.product}</td>
                <td>
                  <span className={`status status--${r.status}`}>{r.status}</span>
                </td>
                <td className="num">{Number(r.premium).toFixed(2)}</td>
                <td>{r.broker_name} <span className="muted">({r.broker_code})</span></td>
                <td>{r.broker_city}</td>
                <td className={`num ${r.days_to_expiry < 30 ? 'warn' : ''}`}>{r.days_to_expiry}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  )
}
