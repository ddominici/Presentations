import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// Il browser parla solo con Vite; Vite inoltra alle tre istanze DAB (una per ruolo di database) e al sidecar.
const strip = (prefix) => (path) => path.replace(new RegExp(`^${prefix}`), '')
const dab = (user, port) => [`/dab/${user}`, { target: `http://localhost:${port}`, changeOrigin: true, rewrite: strip(`/dab/${user}`) }]

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: Object.fromEntries([
      dab('bergamo', 5001),
      dab('milano', 5002),
      dab('manager', 5003),
      ['/sidecar', { target: 'http://localhost:5004', changeOrigin: true, rewrite: strip('/sidecar') }],
    ]),
  },
})
