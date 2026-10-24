export type QueryPlan = { tool: string; arguments: Record<string, unknown>; explanation: string }

const quote = (value: string) => `'${value.replaceAll("'", "''")}'`

const cityAliases: Array<[string[], string]> = [
  [['rome', 'roma'], 'Roma'],
  [['milan', 'milano'], 'Milano'],
  [['turin', 'torino'], 'Torino'],
  [['naples', 'napoli'], 'Napoli'],
  [['barcelona'], 'Barcelona'],
  [['madrid'], 'Madrid'],
]

export function planQuestion(question: string): QueryPlan {
  const text = question.trim().toLowerCase()
  const status = ['active', 'lapsed', 'cancelled', 'pending'].find((item) => text.includes(item))
  const city = cityAliases.find(([aliases]) => aliases.some((alias) => new RegExp(`\\b${alias}\\b`, 'i').test(text)))?.[1]
  const nearExpiry = /expir|renew soon|next 30|next semester|coming month/.test(text)
  const count = /how many|count|number of/.test(text)

  const filters = [
    status ? `status eq ${quote(status)}` : '',
    city ? `broker_city eq ${quote(city)}` : '',
    nearExpiry ? 'days_to_expiry lt 30' : '',
  ].filter(Boolean)

  if (count) {
    return {
      tool: 'aggregate_records',
      arguments: { entity: 'PolicySummary', function: 'count', field: '*', ...(filters.length ? { filter: filters.join(' and ') } : {}) },
      explanation: 'Count matching rows in the PolicySummary view.',
    }
  }

  return {
    tool: 'read_records',
    arguments: {
      entity: 'PolicySummary',
      select: 'policy_number,product,status,premium,broker_name,broker_city,days_to_expiry',
      first: 20,
      ...(filters.length ? { filter: filters.join(' and ') } : {}),
      orderby: nearExpiry ? ['days_to_expiry asc'] : ['premium desc'],
    },
    explanation: 'Read the PolicySummary view with a typed MCP query.',
  }
}
