async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  })

  const text = await response.text()
  let body = null
  if (text) {
    try {
      body = JSON.parse(text)
    } catch {
      body = text
    }
  }

  if (!response.ok) {
    const message = body?.error?.message || body?.message || `HTTP ${response.status} ${response.statusText}`
    const error = new Error(message)
    error.status = response.status
    throw error
  }

  return body
}

const collection = (body) => body?.value ?? []

export function getHealth() {
  return request('/health')
}

export async function getPolicies() {
  const body = await request('/api/policies?$orderby=policy_number asc')
  return collection(body)
}

export async function getClaims() {
  const body = await request('/api/claims?$orderby=opened_on desc')
  return collection(body)
}

export async function getSalesByRegion() {
  const body = await request('/api/sales-by-region?$orderby=period desc, written_premium desc')
  return collection(body)
}
