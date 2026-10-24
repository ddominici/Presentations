# Demo 3 web client

React/Vite client for the multi-source API in `demo/03-fabric-multisource`:

- `/api/policies` reads from local SQL Server.
- `/api/claims` reads from Azure SQL.
- `/api/sales-by-region` reads from the Fabric SQL database.
- `/health` reports DAB and its configured data sources.

Start DAB from `demo/03-fabric-multisource` after preparing all three databases:

```bash
./run.sh
```

Then, from this webapp directory:

```bash
npm install
npm run dev
```

Open <http://localhost:5174>. Vite proxies `/api` and `/health` to DAB at `http://localhost:5000`. The client combines the responses for display; the DAB instance does not join across data sources.
