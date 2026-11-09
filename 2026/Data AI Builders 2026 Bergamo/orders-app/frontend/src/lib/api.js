// Tre identità, tre istanze Data API Builder (stessa configurazione, ruolo di database diverso).
export const USERS = {
  bergamo: { label: 'Venditore Bergamo', role: 'rep_bergamo', port: 5001 },
  milano: { label: 'Venditore Milano', role: 'rep_milano', port: 5002 },
  manager: { label: 'Manager (tutte le regioni)', role: 'shop_manager', port: 5003 },
}

export class ApiError extends Error {
  constructor(message, { code, detail, source } = {}) {
    super(message)
    this.code = code
    this.detail = detail
    this.source = source
  }
}

// "42501: new row violates ..." (messaggio PostgreSQL passato da DAB)
const PG_FRIENDLY = {
  '42501': 'Operazione non consentita dal database (privilegi o policy RLS).',
  '23514': 'Un vincolo o un trigger del database ha rifiutato l\'operazione.',
  '23505': 'Valore duplicato: esiste già una riga con la stessa chiave.',
  '23503': 'Riferimento non valido (chiave esterna).',
  '22P02': 'Valore non valido per il tipo richiesto.',
}

// Errore di DAB (REST o GraphQL): "42501: messaggio PostgreSQL" oppure un codice proprio di DAB
function fromDab(message, dabCode, source) {
  const m = /^(\w{5}):\s*(.*)$/s.exec(message)
  const code = m?.[1] ?? dabCode
  const raw = m?.[2] ?? message
  const friendly = dabCode === 'ItemNotFound' ? 'Riga non trovata o non visibile con questo ruolo.'
    : dabCode === 'AuthorizationCheckFailed' ? 'Operazione non consentita: l\'entità non espone questa azione in Data API Builder (permessi).'
      : PG_FRIENDLY[m?.[1]] ?? 'Il backend ha restituito un errore.'
  return new ApiError(friendly, { code, detail: raw, source })
}

const fromGraphQL = (errors) => fromDab(errors[0].message, errors[0].extensions?.code, 'Data API Builder (GraphQL)')

async function parse(res, source) {
  const text = await res.text()
  let json = null
  try { json = text ? JSON.parse(text) : null } catch { /* non JSON */ }
  if (!res.ok && source.startsWith('Data API Builder') && json?.error) return Promise.reject(fromDab(json.error.message ?? '', json.error.code, source))
  if (!res.ok) {
    const err = json?.error
    const pg = err?.pg
    const code = pg?.code ?? err?.code
    throw new ApiError(
      err?.message ?? `Errore HTTP ${res.status}`,
      { code, detail: pg?.message ?? (typeof err?.message === 'string' ? err.message : text.slice(0, 300)), source },
    )
  }
  return json
}

/** REST di Data API Builder. Restituisce { value, nextLink } per le liste. */
export async function dabRest(user, path, init) {
  const res = await fetch(`/dab/${user}/api${path}`, init).catch(() => {
    throw new ApiError('Data API Builder non raggiungibile. I container sono avviati?', { source: 'rete' })
  })
  return parse(res, 'Data API Builder (REST)')
}

/** GraphQL di Data API Builder. */
export async function dabGql(user, query, variables) {
  const res = await fetch(`/dab/${user}/graphql`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
  }).catch(() => {
    throw new ApiError('Data API Builder non raggiungibile. I container sono avviati?', { source: 'rete' })
  })
  const json = await parse(res, 'Data API Builder (GraphQL)')
  if (json.errors?.length) throw fromGraphQL(json.errors)
  return json.data
}

/** Sidecar: funzioni PostgreSQL che DAB non espone su PostgreSQL (ricerche, create_order, NOTIFY). */
export async function sidecar(user, path, { method = 'GET', body } = {}) {
  const res = await fetch(`/sidecar/api${path}`, {
    method,
    headers: { 'x-shop-user': user, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  }).catch(() => {
    throw new ApiError('Il sidecar non è raggiungibile.', { source: 'rete' })
  })
  return parse(res, 'Sidecar')
}

export const qs = (obj) => {
  const p = new URLSearchParams()
  for (const [k, v] of Object.entries(obj)) if (v !== undefined && v !== null && v !== '') p.set(k, v)
  const s = p.toString()
  return s ? `?${s}` : ''
}
