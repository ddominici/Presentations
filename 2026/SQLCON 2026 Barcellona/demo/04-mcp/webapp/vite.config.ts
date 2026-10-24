import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5175,
    proxy: {
      // Use IPv4 explicitly. On macOS, `localhost` can resolve to ::1 while
      // DAB is listening on the IPv4 loopback interface.
      '/mcp': { target: 'http://127.0.0.1:5000', changeOrigin: true },
      '/health': { target: 'http://127.0.0.1:5000', changeOrigin: true },
    },
  },
})
