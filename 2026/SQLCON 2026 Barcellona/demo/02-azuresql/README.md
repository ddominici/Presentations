# Azure SQL: authentication, authorization and cache

This demo connects DAB to Azure SQL and contains examples for Microsoft Entra authentication, field-level permissions, row-level policies and response caching.

## Prerequisites

- An Azure SQL Database named InsuranceDemo
- Data API builder CLI 2.0.x (dab)
- An authentication method supported by the environment where DAB runs
- Azure CLI or another SQL client

## Prepare Azure SQL

1. Create the database and run sql/01-schema-azuresql.sql.
2. Set AZURE_SQL_CONN in the repository root .env. The sample environment file includes a SQL authentication example; Microsoft Entra authentication is preferred where supported.
3. For Entra authentication, configure the provider, JWT audience and issuer in the generated configuration or in build-config.sh. Create the application roles and token setup required by your tenant.
4. Review sql/02-entra-mapping.sql and sql/03-optional-rls.sql. Run them only after adapting them to your identity and database setup.

This checkout does not include a tenant-specific Entra setup guide or tokens. The builder keeps the identity and authorization commands commented out so the default configuration remains runnable.

## Run

From this directory:

~~~bash
./build-config.sh
dab validate
dab configure --show-effective-permissions
dab start
~~~

run.sh performs the same sequence automatically.

## Default behavior

A fresh build uses Unauthenticated access and anonymous permissions. It is suitable for local exploration only. The commented commands in build-config.sh show how to add:

- reader and broker application roles from the token roles claim;
- field exclusions for commission_amount, broker_oid and entra_oid;
- a row policy comparing @item.broker_oid with @claims.oid;
- an admin role with broader permissions;
- 30-second global and Policy-level L1 cache settings.

With --set-session-context true, DAB can pass claims into SQL Server SESSION_CONTEXT so database row-level security can apply the same identity. Enable the authentication and authorization commands only after adapting them to your tenant.

## API endpoints

| URL | Purpose |
|---|---|
| http://localhost:5000/health | Service health |
| http://localhost:5000/api/openapi | OpenAPI document and Swagger UI |
| http://localhost:5000/api/policies | Policies |
| http://localhost:5000/api/brokers | Brokers |
| http://localhost:5000/api/claims | Claims |
| http://localhost:5000/graphql | GraphQL endpoint |
| http://localhost:5000/mcp | MCP endpoint |

Use curl or a local REST client to exercise the endpoints. Add bearer tokens only to untracked local files. sql/04-cache-proof.sql contains the SQL used to inspect cache-related counters; writes made outside DAB do not invalidate DAB's cache.

## Security note

Use managed identity or another secret-management solution for DAB's database connection. Configure authentication and least-privilege permissions before exposing the endpoint.

