import { useEffect, useState } from 'react'
import { getHealth } from '../api'

export default function HealthBadge() {
  const [state, setState] = useState({ status: 'checking' })

  const check = () => {
    setState({ status: 'checking' })
    getHealth()
      .then((body) => setState({ status: 'up', body }))
      .catch((err) => setState({ status: 'down', error: err.message }))
  }

  useEffect(check, [])

  return (
    <button className={`health-badge health-badge--${state.status}`} onClick={check} title="Recheck /health">
      <span className="health-dot" />
      {state.status === 'checking' && 'Checking…'}
      {state.status === 'up' && `API online${state.body?.version ? ` · v${state.body.version}` : ''}`}
      {state.status === 'down' && `API offline (${state.error})`}
    </button>
  )
}
