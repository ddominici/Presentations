import { useState } from 'react'
import HealthBadge from './components/HealthBadge'
import PolicySummaryTable from './components/PolicySummaryTable'
import RenewPolicyForm from './components/RenewPolicyForm'
import ThemeToggle from './components/ThemeToggle'
import './App.css'

export default function App() {
  const [refreshToken, setRefreshToken] = useState(0)
  const [policyOptions, setPolicyOptions] = useState([])

  return (
    <div className="app">
      <header className="app-header">
        <div>
          <h1>Demo 1 · DAB on-prem</h1>
          <p className="muted">View dbo.vw_PolicySummary and stored procedure dbo.usp_RenewPolicy, via Data API Builder.</p>
        </div>
        <div className="header-actions">
          <ThemeToggle />
          <HealthBadge />
        </div>
      </header>

      <main>
        <PolicySummaryTable
          refreshToken={refreshToken}
          onRowsLoaded={(rows) => setPolicyOptions(rows.map((r) => r.policy_number))}
        />
        <RenewPolicyForm
          policyOptions={policyOptions}
          onRenewed={() => setRefreshToken((t) => t + 1)}
        />
      </main>

      <footer className="muted">
        Proxy to http://localhost:5000 configured in vite.config.js — run `dab start` in the demo/01-onprem folder first.
      </footer>
    </div>
  )
}
