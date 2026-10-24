import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // Forward API/health calls to the local DAB engine (demo 01-onprem, dab start).
      // Proxying avoids CORS entirely: dab-config.json has host.cors.origins: [].
      '/api': 'http://localhost:5000',
      '/health': 'http://localhost:5000',
    },
  },
})
