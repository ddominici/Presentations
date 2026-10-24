# webapp — demo on-prem + Azure SQL + Fabric

SPA React/Vite per mostrare in una sola pagina le tre sorgenti della demo 3:

- `GET /api/policies` → SQL Server on-premises;
- `GET /api/claims` → Azure SQL;
- `GET /api/sales-by-region` → SQL database in Microsoft Fabric;
- `GET /health` → stato delle sorgenti nominate.

## Avvio

Dalla cartella `demo/03-fabric-multisource` avvia prima DAB:

```bash
./run.sh
```

Poi, in questa cartella:

```bash
npm install
npm run dev
```

Apri `http://localhost:5174`. Il proxy Vite inoltra `/api/*` e `/health` a
`http://localhost:5000`.
