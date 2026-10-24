import { useEffect, useMemo, useState } from 'react'
import { getClaims, getHealth, getPolicies, getSalesByRegion } from './api'
import './App.css'

const money = (value) => Number(value ?? 0).toLocaleString('en-US', { style: 'currency', currency: 'USD' })

function ThemeToggle() {
  const [dark, setDark] = useState(() => localStorage.getItem('hybrid-theme') === 'dark')

  useEffect(() => {
    document.documentElement.dataset.theme = dark ? 'dark' : 'light'
    localStorage.setItem('hybrid-theme', dark ? 'dark' : 'light')
  }, [dark])

  return <button className="theme-toggle" onClick={() => setDark((value) => !value)}>{dark ? '☀ Light' : '☾ Dark'}</button>
}

function SourcePill({ tone, children }) {
  return <span className={`source-pill source-pill--${tone}`}><span className="source-dot" />{children}</span>
}

function HealthPanel({ state, onRefresh }) {
  const entries = useMemo(() => {
    const body = state.body
    if (Array.isArray(body)) return body
    return body?.dataSources || body?.data_sources || body?.sources || []
  }, [state.body])

  return (
    <div className="health-panel">
      <div className="health-summary">
        <span className={`health-indicator health-indicator--${state.status}`} />
        <div>
          <strong>{state.status === 'up' ? 'All systems checked' : state.status === 'checking' ? 'Checking API health…' : 'API unavailable'}</strong>
          <span className="muted">GET /health · named data sources</span>
        </div>
        <button className="quiet-button" onClick={onRefresh}>Refresh</button>
      </div>
      {state.status === 'down' && <p className="error">{state.error}</p>}
      {entries.length > 0 && <div className="health-list">
        {entries.map((entry, index) => {
          const name = entry.name || entry.dataSource || entry.database || `source-${index + 1}`
          const status = String(entry.status || entry.health || 'healthy').toLowerCase()
          return <div className="health-row" key={`${name}-${index}`}><span className={`health-mini health-mini--${status.includes('healthy') || status.includes('up') ? 'up' : 'down'}`} /><span>{name}</span><span className="muted">{entry.duration ?? entry.elapsed ?? '—'}</span></div>
        })}
      </div>}
    </div>
  )
}

function Card({ tone, source, title, endpoint, loading, error, children }) {
  return <section className={`data-card data-card--${tone}`}>
    <div className="card-heading">
      <div><SourcePill tone={tone}>{source}</SourcePill><h2>{title}</h2><p className="endpoint">{endpoint}</p></div>
      {loading && <span className="loading-label">Loading…</span>}
    </div>
    {error ? <p className="error">{error}</p> : children}
  </section>
}

function App() {
  const [data, setData] = useState({ policies: [], claims: [], sales: [] })
  const [state, setState] = useState({ status: 'checking' })
  const [loading, setLoading] = useState(true)
  const [errors, setErrors] = useState({})
  const [lastUpdated, setLastUpdated] = useState(null)

  const load = async () => {
    setLoading(true)
    setErrors({})
    const [policies, claims, sales] = await Promise.allSettled([getPolicies(), getClaims(), getSalesByRegion()])
    const nextData = {}
    const nextErrors = {}
    ;[['policies', policies], ['claims', claims], ['sales', sales]].forEach(([key, result]) => {
      if (result.status === 'fulfilled') nextData[key] = result.value
      else { nextData[key] = []; nextErrors[key] = result.reason.message }
    })
    setData(nextData)
    setErrors(nextErrors)
    setLastUpdated(new Date())
    setLoading(false)
  }

  const checkHealth = () => {
    setState({ status: 'checking' })
    getHealth().then((body) => setState({ status: 'up', body })).catch((error) => setState({ status: 'down', error: error.message }))
  }

  useEffect(() => { load(); checkHealth() }, [])

  const totals = useMemo(() => ({
    premium: data.sales.reduce((sum, row) => sum + Number(row.written_premium || 0), 0),
    policies: data.policies.length,
    claims: data.claims.length,
  }), [data])

  return <div className="app">
    <header className="hero">
      <div>
        <div className="eyebrow"><span className="eyebrow-mark">DAB</span> ONE API · THREE DATA SOURCES</div>
        <h1>Hybrid insurance<br /><em>intelligence</em></h1>
        <p className="hero-copy">A single Data API Builder surface for policies on-premises, claims in Azure SQL, and sales facts in Microsoft Fabric.</p>
      </div>
      <div className="hero-actions"><ThemeToggle /><span className="api-label"><span className="live-dot" />localhost:5000</span></div>
    </header>

    <HealthPanel state={state} onRefresh={checkHealth} />

    <div className="section-intro"><div><span className="section-kicker">LIVE DATA SURFACES</span><h2>One endpoint, clearly sourced</h2></div><div className="last-updated">{lastUpdated ? `Updated ${lastUpdated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : 'Waiting for data'}<button className="refresh-button" onClick={load} disabled={loading}>{loading ? 'Loading…' : '↻ Refresh all'}</button></div></div>

    <main className="data-grid">
      <Card tone="onprem" source="ON-PREMISES SQL SERVER" title="Policies" endpoint="GET /api/policies" loading={loading && !data.policies.length} error={errors.policies}>
        <div className="metric-strip"><strong>{totals.policies}</strong><span>policies in system of record</span></div>
        <div className="table-wrap"><table><thead><tr><th>Policy</th><th>Product</th><th>Status</th><th className="num">Premium</th></tr></thead><tbody>{data.policies.map((row) => <tr key={row.id || row.policy_number}><td className="strong">{row.policy_number}</td><td>{row.product}</td><td><span className={`status status--${row.status}`}>{row.status}</span></td><td className="num">{money(row.premium)}</td></tr>)}{!loading && !data.policies.length && <tr><td colSpan="4" className="empty">No policies returned.</td></tr>}</tbody></table></div>
      </Card>

      <Card tone="azure" source="AZURE SQL DATABASE" title="Claims" endpoint="GET /api/claims" loading={loading && !data.claims.length} error={errors.claims}>
        <div className="metric-strip"><strong>{totals.claims}</strong><span>claims from cloud database</span></div>
        <div className="table-wrap"><table><thead><tr><th>Claim</th><th>Policy</th><th>Status</th><th className="num">Reserve</th></tr></thead><tbody>{data.claims.map((row) => <tr key={row.id || row.claim_number}><td className="strong">{row.claim_number}</td><td>{row.policy_number}</td><td><span className={`status status--${row.status}`}>{row.status}</span></td><td className="num">{money(row.reserve)}</td></tr>)}{!loading && !data.claims.length && <tr><td colSpan="4" className="empty">No claims returned.</td></tr>}</tbody></table></div>
      </Card>

      <Card tone="fabric" source="MICROSOFT FABRIC" title="Sales by region" endpoint="GET /api/sales-by-region" loading={loading && !data.sales.length} error={errors.sales}>
        <div className="metric-strip"><strong>{money(totals.premium)}</strong><span>total written premium</span></div>
        <div className="table-wrap"><table><thead><tr><th>Period</th><th>Region</th><th className="num">Policies</th><th className="num">Premium</th></tr></thead><tbody>{data.sales.map((row) => <tr key={`${row.region}-${row.period}`}><td className="strong">{row.period}</td><td>{row.region}</td><td className="num">{Number(row.policies_sold || 0).toLocaleString()}</td><td className="num">{money(row.written_premium)}</td></tr>)}{!loading && !data.sales.length && <tr><td colSpan="4" className="empty">No sales returned.</td></tr>}</tbody></table></div>
      </Card>
    </main>

    <footer><span>Data API Builder 2.0</span><span>REST · GraphQL · MCP</span><span>Composition happens in the client — not a distributed join.</span></footer>
  </div>
}

export default App
