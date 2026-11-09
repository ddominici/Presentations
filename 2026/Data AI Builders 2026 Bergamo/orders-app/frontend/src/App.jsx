import { useEffect, useState } from 'react'
import { useUser, useEvents } from './lib/context.jsx'
import { USERS } from './lib/api.js'
import Dashboard from './pages/Dashboard.jsx'
import Orders from './pages/Orders.jsx'
import Customers from './pages/Customers.jsx'
import Catalog from './pages/Catalog.jsx'
import Security from './pages/Security.jsx'
import Live from './pages/Live.jsx'
import Architecture from './pages/Architecture.jsx'

const PAGES = [
  { id: 'dashboard', label: 'Dashboard', icon: '📊', el: Dashboard },
  { id: 'orders', label: 'Ordini', icon: '🧾', el: Orders },
  { id: 'customers', label: 'Clienti', icon: '🏢', el: Customers },
  { id: 'catalog', label: 'Catalogo', icon: '🔎', el: Catalog },
  { id: 'security', label: 'Sicurezza (RLS)', icon: '🔐', el: Security },
  { id: 'live', label: 'Eventi live', icon: '⚡', el: Live },
  { id: 'architecture', label: 'Architettura', icon: '🧩', el: Architecture },
]

const getHash = () => (PAGES.find((p) => p.id === location.hash.slice(1)) ?? PAGES[0]).id

export default function App() {
  const [page, setPage] = useState(getHash)
  const { user, setUser } = useUser()
  const { status } = useEvents()
  useEffect(() => {
    const on = () => setPage(getHash())
    window.addEventListener('hashchange', on)
    return () => window.removeEventListener('hashchange', on)
  }, [])
  const Page = PAGES.find((p) => p.id === page).el

  return (
    <div className="layout">
      <nav className="sidebar" aria-label="Navigazione">
        <div className="brand"><span>🐘</span><div><strong>Ordini clienti</strong><small>PostgreSQL · DAB · React</small></div></div>
        {PAGES.map((p) => (
          <a key={p.id} href={`#${p.id}`} className={p.id === page ? 'active' : ''} aria-current={p.id === page ? 'page' : undefined}>
            <span aria-hidden>{p.icon}</span>{p.label}
          </a>
        ))}
      </nav>
      <div className="main">
        <header className="topbar">
          <label className="user-switch">
            Utente
            <select value={user} onChange={(e) => setUser(e.target.value)} aria-label="Utente corrente">
              {Object.entries(USERS).map(([k, u]) => <option key={k} value={k}>{u.label}</option>)}
            </select>
          </label>
          <span className="role-chip" title="Ruolo di database usato dall'istanza Data API Builder">ruolo DB: <code>{USERS[user].role}</code></span>
          <span className={`live-dot live-${status}`} title="Connessione LISTEN/NOTIFY → SSE">
            {status === 'open' ? 'Eventi live attivi' : status === 'connecting' ? 'Connessione eventi…' : 'Eventi non disponibili'}
          </span>
        </header>
        <main className="content" key={`${page}-${user}`}><Page /></main>
      </div>
    </div>
  )
}
