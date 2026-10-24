# Local SQL Server API

This demo exposes an existing SQL Server database through Data API builder (DAB). Tables, a view, a stored procedure and a relationship become REST, GraphQL and MCP endpoints without changing the database schema.

## Prerequisites

- Docker Desktop
- Data API builder CLI 2.0.x (dab)
- curl (optional; the examples also work with the VS Code REST Client)

## Setup

From the SQLCON folder:

~~~bash
cp .env.example .env
~~~

Set MSSQL_SA_PASSWORD and SQL_CONN in .env. SQL_CONN must target the InsuranceDemo database on localhost,1433 and use the same password as the SQL Server container. Keep .env private.

## Run

From this directory:

~~~bash
./run.sh
~~~

The script starts SQL Server 2022, waits for it, creates the schema and sample data from sql/, rebuilds dab-config.json, validates it and starts DAB on port 5000.

To run the steps separately:

~~~bash
docker compose up -d
./build-config.sh
dab start
~~~

## API endpoints

| URL | Purpose |
|---|---|
| http://localhost:5000/health | Service health |
| http://localhost:5000/api/openapi | OpenAPI document and Swagger UI |
| http://localhost:5000/api/policies | Policies table |
| http://localhost:5000/api/brokers | Brokers table |
| http://localhost:5000/api/policy-summary | vw_PolicySummary view |
| http://localhost:5000/api/renew-policy | usp_RenewPolicy stored procedure |
| http://localhost:5000/graphql | GraphQL endpoint |
| http://localhost:5000/mcp | MCP endpoint |

requests.http contains examples for filtering, projection, inserts, updates, GraphQL and stored-procedure execution. The optional React client is documented in webapp/README.md.

The view declares policy_id as its key because DAB cannot infer a key from a view. RenewPolicy is available as a POST endpoint and as a custom MCP tool.

## Rebuild and reset

build-config.sh removes and recreates dab-config.json using DAB CLI commands. To discard the SQL Server volume and recreate the database:

~~~bash
docker compose down -v
./run.sh
~~~

## Security note

This is a local development configuration with unauthenticated access and write permissions on the demo policy entity. Do not expose it to an untrusted network or reuse it as a production configuration.

