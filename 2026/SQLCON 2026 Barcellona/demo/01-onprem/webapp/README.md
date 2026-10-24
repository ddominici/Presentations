# Demo 1 web client

This React/Vite single-page app exercises the local DAB API from `demo/01-onprem`.

- `PolicySummary` reads the `dbo.vw_PolicySummary` view and displays policy data.
- `RenewPolicy` posts to the stored procedure endpoint and displays its response.
- The connection indicator checks `/health`.

## Start

Start DAB first, from `demo/01-onprem`:

```bash
./run.sh
```

Then from this directory:

```bash
npm install
npm run dev
```

Open <http://localhost:5173>. Vite proxies `/api` and `/health` to `http://localhost:5000`, so browser requests do not require CORS configuration.

If port 5000 is already occupied, stop the conflicting process or start DAB on another port and update the proxy in `vite.config.js`. `npm run build` creates a static build in `dist/`.
