# Read-only MCP client

This demo pairs DAB's streamable HTTP MCP endpoint with a React and TypeScript client. The browser discovers tools through tools/list, maps a few sample questions to typed read_records or aggregate_records calls, and renders the response.

No language model is invoked by this web app. The planner in webapp/src/planner.ts is rule based and does not translate arbitrary natural language into SQL.

## Prerequisites

- The local SQL Server database from ../01-onprem/
- Data API builder CLI 2.0.x (dab)
- Node.js and npm

## Run

Start DAB in one terminal:

~~~bash
./run.sh
~~~

In a second terminal:

~~~bash
cd webapp
npm install
npm run dev
~~~

Open http://localhost:5175. Vite proxies /mcp and /health to DAB at 127.0.0.1:5000, so the browser does not need database credentials or a separate CORS configuration.

## Tools and entities

dab-config.json enables the read-only MCP tools describe_entities, read_records and aggregate_records. Create, update, delete and entity-execution tools are disabled.

The configuration exposes PolicySummary, Policy and Broker. Their field descriptions and primary-key metadata are included so an MCP consumer can work with business-friendly names instead of only raw database identifiers.

## Security note

The DAB configuration uses unauthenticated local development access. Do not expose it publicly without authentication, origin restrictions and a review of the tools available through MCP.

