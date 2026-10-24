import { useEffect, useState } from 'react'
import { callTool, health, listTools, type McpTool } from './api'
import { planQuestion, type QueryPlan } from './planner'
import './App.css'

const examples = ['Show active policies expiring soon', 'How many policies are active?', 'Show policies sold in Torino']

function App() {
  const [question, setQuestion] = useState(examples[0])
  const [tools, setTools] = useState<McpTool[]>([])
  const [plan, setPlan] = useState<QueryPlan | null>(null)
  const [result, setResult] = useState<unknown>(null)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [apiOnline, setApiOnline] = useState<boolean | null>(null)
  const [mcpOnline, setMcpOnline] = useState<boolean | null>(null)
  const [resultView, setResultView] = useState<'table' | 'grid'>('grid')

  useEffect(() => {
    listTools().then((available) => {
      setTools(available)
      setMcpOnline(true)
      if (available.some((tool) => tool.name === 'read_records')) ask(examples[0])
    }).catch(() => setMcpOnline(false))
    health().then(() => setApiOnline(true)).catch(() => setApiOnline(false))
  }, [])

  async function ask(value = question) {
    const nextPlan = planQuestion(value)
    setQuestion(value); setPlan(nextPlan); setResult(null); setError(''); setBusy(true)
    try {
      const availableTools = tools.length ? tools : await listTools()
      setTools(availableTools)
      if (!availableTools.some((tool) => tool.name === nextPlan.tool)) throw new Error(`DAB did not advertise ${nextPlan.tool}. Check runtime.mcp.dml-tools.`)
      setResult(await callTool(nextPlan.tool, nextPlan.arguments))
    } catch (caught) { setError(caught instanceof Error ? caught.message : String(caught)) } finally { setBusy(false) }
  }

  return <div className="shell">
    <header className="hero">
      <div className="eyebrow"><span className="mark">✦</span> DATA API BUILDER · DEMO 5</div>
      <div className="hero-row">
        <div><h1>Ask the database.</h1><p>Natural language in. Typed MCP tools out.</p></div>
        <div className={`connection ${mcpOnline === true ? 'up' : mcpOnline === false ? 'down' : ''}`}><span />{mcpOnline === true ? `MCP connected · ${tools.length} tools` : mcpOnline === false ? (apiOnline ? 'DAB online · MCP unavailable' : 'DAB offline') : 'Connecting…'}</div>
      </div>
    </header>

    <main>
      <section className="ask-card">
        <label htmlFor="question">What would you like to know?</label>
        <div className="ask-row"><input id="question" value={question} onChange={(event) => setQuestion(event.target.value)} onKeyDown={(event) => event.key === 'Enter' && ask()} /><button onClick={() => ask()} disabled={busy || !question.trim()}>{busy ? 'Asking…' : 'Ask MCP'} <span>↗</span></button></div>
        <div className="examples">{examples.map((example) => <button key={example} onClick={() => ask(example)}>{example}</button>)}</div>
      </section>

      {plan && <section className="trace"><div className="section-label">REQUEST TRACE</div><div className="trace-grid"><div><span>Natural language</span><strong>“{question}”</strong></div><div className="arrow">→</div><div><span>MCP tool</span><strong className="code">{plan.tool}</strong></div><div className="arrow">→</div><div><span>Data source</span><strong>dbo.vw_PolicySummary</strong></div></div><p>{plan.explanation}</p></section>}

      {error && <section className="error"><strong>Request failed</strong><span>{error}</span></section>}
      {result !== null && <section className="results"><div className="results-heading"><div className="section-label">RESULT</div><div className="view-toggle"><button className={resultView === 'grid' ? 'selected' : ''} onClick={() => setResultView('grid')}>Grid</button><button className={resultView === 'table' ? 'selected' : ''} onClick={() => setResultView('table')}>Table</button></div></div><ResultView result={result} view={resultView} /></section>}

      <section className="tools"><div><div className="section-label">DISCOVERED FROM DAB · /MCP</div><h2>Tools available to the agent</h2></div><div className="tool-list">{tools.length ? tools.map((tool) => <span key={tool.name}>{tool.name}</span>) : <span className="muted">Start DAB on port 5000 to discover tools.</span>}</div></section>
    </main>
    <footer>Run <code>dab start</code> in <code>demo/5-mcp</code>, then <code>npm run dev</code>.</footer>
  </div>
}

function ResultView({ result, view }: { result: unknown; view: 'table' | 'grid' }) {
  const rows = (result as { value?: Record<string, unknown>[] } | null)?.value
  if (Array.isArray(rows) && view === 'grid') return rows.length ? <div className="policy-grid">{rows.map((row, index) => <article className="policy-card" key={String(row.policy_number || index)}><div className="policy-card-top"><span className="policy-number">{String(row.policy_number ?? 'Policy')}</span><span className={`status ${String(row.status)}`}>{String(row.status ?? '—')}</span></div><h3>{String(row.product ?? 'Insurance policy')}</h3><div className="policy-details"><div><span>Premium</span><strong>{row.premium == null ? '—' : Number(row.premium).toFixed(2)}</strong></div><div><span>Broker</span><strong>{String(row.broker_name ?? '—')}</strong></div><div><span>Location</span><strong>{String(row.broker_city ?? '—')}</strong></div><div><span>Expires in</span><strong className={Number(row.days_to_expiry) < 30 ? 'warning' : ''}>{String(row.days_to_expiry ?? '—')} days</strong></div></div></article>)}</div> : <p className="empty-result">No policies matched this question.</p>
  if (Array.isArray(rows)) return <div className="table-wrap"><table><thead><tr>{['Policy', 'Product', 'Status', 'Premium', 'Broker', 'City', 'Days to expiry'].map((header) => <th key={header}>{header}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={String(row.policy_number || index)}><td>{String(row.policy_number ?? '—')}</td><td>{String(row.product ?? '—')}</td><td><span className={`status ${String(row.status)}`}>{String(row.status ?? '—')}</span></td><td>{row.premium == null ? '—' : Number(row.premium).toFixed(2)}</td><td>{String(row.broker_name ?? '—')}</td><td>{String(row.broker_city ?? '—')}</td><td className={Number(row.days_to_expiry) < 30 ? 'warning' : ''}>{String(row.days_to_expiry ?? '—')}</td></tr>)}</tbody></table></div>
  return <pre>{JSON.stringify(result, null, 2)}</pre>
}

export default App
