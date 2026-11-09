import { useCallback, useEffect, useRef, useState } from 'react'

/** Esegue una funzione asincrona quando cambiano le dipendenze; gestisce caricamento, errore e risposte fuori ordine. */
export function useAsync(fn, deps, { enabled = true } = {}) {
  const [state, setState] = useState({ data: null, error: null, loading: enabled })
  const seq = useRef(0)
  const run = useCallback(async () => {
    const id = ++seq.current
    setState((s) => ({ ...s, loading: true, error: null }))
    try {
      const data = await fn()
      if (id === seq.current) setState({ data, error: null, loading: false })
    } catch (error) {
      if (id === seq.current) setState({ data: null, error, loading: false })
    }
  }, deps) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (enabled) run() }, [run, enabled])
  return { ...state, reload: run }
}

export function useDebounced(value, ms = 300) {
  const [v, setV] = useState(value)
  useEffect(() => { const t = setTimeout(() => setV(value), ms); return () => clearTimeout(t) }, [value, ms])
  return v
}

export function useLocalStorage(key, initial) {
  const [value, setValue] = useState(() => localStorage.getItem(key) ?? initial)
  useEffect(() => { localStorage.setItem(key, value) }, [key, value])
  return [value, setValue]
}
