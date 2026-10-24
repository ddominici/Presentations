import { useState } from 'react'
import { renewPolicy } from '../api'

export default function RenewPolicyForm({ policyOptions, onRenewed }) {
  const [policyNumber, setPolicyNumber] = useState('POL-2026-0001')
  const [months, setMonths] = useState(12)
  const [state, setState] = useState({ status: 'idle' })

  const submit = async (e) => {
    e.preventDefault()
    setState({ status: 'loading' })
    try {
      const result = await renewPolicy({ policy_number: policyNumber, months })
      const row = Array.isArray(result?.value) ? result.value[0] : result
      setState({ status: 'success', row })
      onRenewed?.()
    } catch (err) {
      setState({ status: 'error', error: err.message })
    }
  }

  return (
    <section className="card">
      <div className="card-header">
        <h2>Stored procedure: dbo.usp_RenewPolicy</h2>
      </div>
      <p className="muted">POST /api/renew-policy — extends the policy's expiry by N months and sets it back to "active".</p>

      <form className="renew-form" onSubmit={submit}>
        <label>
          Policy number
          <input
            list="policy-numbers"
            value={policyNumber}
            onChange={(e) => setPolicyNumber(e.target.value)}
            placeholder="POL-2026-0001"
            required
          />
          <datalist id="policy-numbers">
            {policyOptions.map((p) => (
              <option key={p} value={p} />
            ))}
          </datalist>
        </label>

        <label>
          Months
          <input
            type="number"
            min={1}
            max={120}
            value={months}
            onChange={(e) => setMonths(e.target.value)}
            required
          />
        </label>

        <button type="submit" disabled={state.status === 'loading'}>
          {state.status === 'loading' ? 'Running…' : 'Run renewal'}
        </button>
      </form>

      {state.status === 'error' && <p className="error">Error: {state.error}</p>}

      {state.status === 'success' && (
        <div className="result">
          <p className="ok">Renewal completed.</p>
          <pre>{JSON.stringify(state.row, null, 2)}</pre>
        </div>
      )}
    </section>
  )
}
