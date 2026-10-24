# webapp — client di test per la demo 01-onprem

SPA React (Vite) per testare a mano l'API generata da Data API Builder in
`demo/01-onprem`:

- **Vista** `dbo.vw_PolicySummary` (entità `PolicySummary`) — tabella con filtro per stato,
  ordinata per giorni alla scadenza.
- **Stored procedure** `dbo.usp_RenewPolicy` (entità `RenewPolicy`) — form che esegue
  `POST /api/renew-policy` e mostra la riga restituita.

Un indicatore in alto a destra chiama `/health` e segnala se il motore DAB è raggiungibile.

## Avvio

1. Avvia la demo (dalla cartella `demo/01-onprem`):
   ```bash
   ./run.sh        # oppure: docker compose up -d && ./build-config.sh && dab start
   ```
   DAB deve essere in ascolto su `http://localhost:5000`.

2. Avvia la SPA (da questa cartella, `demo/01-onprem/webapp`):
   ```bash
   npm install
   npm run dev
   ```
   Apri `http://localhost:5173`.

Le chiamate a `/api/*` e `/health` passano attraverso il proxy di Vite
(`vite.config.js`) verso `http://localhost:5000`, così restano same-origin ed
evitano il blocco CORS: `dab-config.json` ha `host.cors.origins: []`.

## Note

- Porta 5000 occupata da AirPlay Receiver su macOS? Disattivalo in
  Impostazioni di Sistema → Generali → AirDrop e Handoff, oppure cambia porta
  a DAB con `dab start --port <n>` e aggiorna il proxy in `vite.config.js`.
- `npm run build` produce la build statica in `dist/`.
