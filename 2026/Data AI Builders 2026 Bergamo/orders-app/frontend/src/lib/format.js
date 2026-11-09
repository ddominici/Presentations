export const money = (n) => new Intl.NumberFormat('it-IT', { style: 'currency', currency: 'EUR' }).format(n ?? 0)
export const dateTime = (s) => (s ? new Intl.DateTimeFormat('it-IT', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(s)) : '')
export const dateShort = (s) => (s ? new Intl.DateTimeFormat('it-IT', { day: '2-digit', month: 'short' }).format(new Date(s)) : '')

export const STATUS = {
  new: { label: 'Nuovo', tone: 'blue' },
  confirmed: { label: 'Confermato', tone: 'violet' },
  paid: { label: 'Pagato', tone: 'amber' },
  shipped: { label: 'Spedito', tone: 'teal' },
  delivered: { label: 'Consegnato', tone: 'green' },
  cancelled: { label: 'Annullato', tone: 'red' },
}
export const STATUS_ORDER = Object.keys(STATUS)

// Stesse transizioni del trigger check_status_transition (il database resta l'autorità)
export const NEXT_STATUS = {
  new: ['confirmed', 'cancelled'],
  confirmed: ['paid', 'cancelled'],
  paid: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: [],
  cancelled: [],
}

export const REGIONS = { bergamo: 'Bergamo', milano: 'Milano', roma: 'Roma' }
