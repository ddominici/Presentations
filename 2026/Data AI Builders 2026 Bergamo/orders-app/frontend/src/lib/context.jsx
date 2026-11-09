import { createContext, useContext, useEffect, useMemo, useRef, useState, useCallback } from 'react'
import { useLocalStorage } from './hooks.js'
import { USERS } from './api.js'

const UserContext = createContext(null)
export const useUser = () => useContext(UserContext)

const EventsContext = createContext(null)
export const useEvents = () => useContext(EventsContext)

export function AppProviders({ children }) {
  const [stored, setUser] = useLocalStorage('shop-user', 'bergamo')
  const user = USERS[stored] ? stored : 'bergamo'
  const userValue = useMemo(() => ({ user, setUser, info: USERS[user] }), [user, setUser])

  // Una sola EventSource per utente: riceve gli eventi LISTEN/NOTIFY inoltrati dal sidecar.
  const [events, setEvents] = useState([])
  const [status, setStatus] = useState('connecting')
  const [tick, setTick] = useState(0)            // incrementa a ogni evento d'ordine o resync: le pagine rileggono
  const listeners = useRef(new Set())

  useEffect(() => {
    setEvents([]); setStatus('connecting')
    const es = new EventSource(`/sidecar/api/events?user=${user}`)
    es.addEventListener('ready', () => setStatus('open'))
    es.addEventListener('notify', (e) => {
      const msg = JSON.parse(e.data)
      setEvents((prev) => [{ ...msg, id: crypto.randomUUID() }, ...prev].slice(0, 100))
      if (msg.channel === 'order_events') { setTick((t) => t + 1); listeners.current.forEach((l) => l(msg)) }
    })
    es.addEventListener('resync', () => setTick((t) => t + 1))   // dopo una riconnessione: rileggere lo stato
    es.onerror = () => setStatus(es.readyState === EventSource.CLOSED ? 'closed' : 'connecting')
    return () => es.close()
  }, [user])

  const onOrderEvent = useCallback((fn) => { listeners.current.add(fn); return () => listeners.current.delete(fn) }, [])
  const eventsValue = useMemo(() => ({ events, status, tick, onOrderEvent }), [events, status, tick, onOrderEvent])

  return (
    <UserContext.Provider value={userValue}>
      <EventsContext.Provider value={eventsValue}>{children}</EventsContext.Provider>
    </UserContext.Provider>
  )
}
