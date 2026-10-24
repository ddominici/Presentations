// Thin fetch wrapper for the Data API Builder demo 01-onprem instance.
// Requests go through the Vite dev proxy (see vite.config.js) so they hit
// http://localhost:5000 as same-origin calls, avoiding the empty CORS origin list
// configured in dab-config.json.

async function request(path, options = {}) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  })

  const text = await res.text()
  let body = null
  if (text) {
    try {
      body = JSON.parse(text)
    } catch {
      body = text
    }
  }

  if (!res.ok) {
    const message =
      (body && (body.error?.message || body.message)) || `HTTP ${res.status} ${res.statusText}`
    const error = new Error(message)
    error.status = res.status
    error.body = body
    throw error
  }

  return body
}

export function getHealth() {
  return request('/health')
}

export function getPolicySummary({ status } = {}) {
  const params = new URLSearchParams()
  if (status) params.set('$filter', `status eq '${status}'`)
  params.set('$orderby', 'days_to_expiry asc')
  const qs = params.toString()
  return request(`/api/PolicySummary${qs ? `?${qs}` : ''}`)
}

export function renewPolicy({ policy_number, months }) {
  return request('/api/RenewPolicy', {
    method: 'POST',
    body: JSON.stringify({ policy_number, months: Number(months) }),
  })
}
