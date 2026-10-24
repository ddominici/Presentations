# Multi-source API with SQL Server, Azure SQL and Fabric

This demo runs one DAB process over local SQL Server, Azure SQL and a SQL database in Microsoft Fabric. Clients use one base URL and one combined OpenAPI document. DAB does not join data across sources; composition belongs in the client or application layer.

## Prerequisites

- Data API builder CLI 2.0.x (dab)
- The local SQL Server database from ../01-onprem/
- The Azure SQL database and Claim table from ../02-azuresql/
- A Fabric SQL database named SalesDemo
- Microsoft Entra credentials for Fabric

Run sql/01-fabric-salesfact.sql in the Fabric query editor. Fabric SQL accepts Microsoft Entra authentication only, not SQL logins. Set SQL_CONN, AZURE_SQL_CONN and FABRIC_CONN in ../../.env.

## Run

From this directory:

~~~bash
./run.sh
~~~

The script validates the combined configuration and starts DAB on port 5000. It does not create the remote databases or run their schema scripts.

## API endpoints

| URL | Data source |
|---|---|
| /api/policies | Local SQL Server |
| /api/brokers | Local SQL Server |
| /api/claims | Azure SQL |
| /api/sales-fact | SQL database in Fabric |
| /api/sales-by-region | Fabric view |
| /api/openapi | Combined OpenAPI document |
| /health | Runtime and named data-source health |
| /graphql | Combined GraphQL endpoint |
| /mcp | MCP endpoint |

The optional React client is documented in webapp/README.md.

## Configuration files

| File | Contents |
|---|---|
| dab-config.json | Top-level runtime and local SQL Server source |
| dab-config.azuresql.json | Azure SQL source and Claim entity |
| dab-config.fabric.json | Fabric source, SalesFact and SalesByRegion |
| run.sh | Environment checks, validation and startup |

Child configurations must contain their own data-source and entities sections. Runtime settings come from the top-level file. Keep entity names and REST paths unique across all files.

## Fabric variants

The checked-in child targets a Fabric SQL database with database-type: mssql. A Fabric Warehouse or Lakehouse SQL analytics endpoint needs different connection details and may use database-type: dwsql; check the supported DAB feature set before adapting the child configuration.

## Security note

The sample uses unauthenticated development access. Add authentication and least-privilege permissions before exposing any source. If Fabric is unavailable, remove its child configuration and entities, and update run.sh to stop requiring FABRIC_CONN before running the remaining sources.

