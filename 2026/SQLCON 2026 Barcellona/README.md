# Data API Builder 2.0 — SQLCON Barcelona demos

This repository contains runnable examples for building REST, GraphQL and MCP APIs over SQL Server, Azure SQL and Microsoft Fabric with Data API Builder (DAB).

The examples are independent, but the later ones reuse the local database created by the first demo:

1. local SQL Server API;
2. Azure SQL security and caching;
3. one API over multiple data sources;
4. a read-only MCP client;
5. container deployment to Azure and an AWS ECS reference.

## Demo map

| Folder | Purpose |
|---|---|
| [demo/01-onprem](demo/01-onprem/) | Local SQL Server in Docker, REST, GraphQL, a view, a stored procedure and MCP |
| [demo/02-azuresql](demo/02-azuresql/) | Azure SQL connection, Entra and authorization examples, and cache |
| [demo/03-fabric-multisource](demo/03-fabric-multisource/) | One DAB runtime over local SQL Server, Azure SQL and Fabric SQL |
| [demo/04-mcp](demo/04-mcp/) | Read-only MCP tools and a React client |
| [demo/05-deploy](demo/05-deploy/) | Azure Container Instances deployment and an AWS ECS task-definition reference |

Each demo folder contains its own prerequisites and commands. Start with [demo/01-onprem/README.md](demo/01-onprem/README.md).

## Requirements

- Data API builder CLI 2.0.x
- Docker Desktop for the local SQL Server demo
- Node.js and npm for the web clients
- Azure CLI for the Azure SQL and deployment examples
- An Azure SQL database and a Fabric SQL database for demos 2 and 3
- curl; the VS Code REST Client is useful for the .http files

## Shared configuration

Copy the environment template and edit only the values needed by the demos you use:

~~~bash
cp .env.example .env
~~~

The root .env is ignored by Git. It contains local SQL Server, Azure SQL and Fabric connection-string examples. DAB resolves the connection strings through environment references; they are not stored as literal values in the checked-in configurations.

The deployment demo has a separate environment file:

~~~bash
cd demo/05-deploy
cp env.sh.example env.sh
~~~

Use managed identity or a managed secret store instead of passwords in environment files for real deployments.

## Running order

Demo 1 creates the InsuranceDemo schema and seed data in Docker. Demos 3 and 4 expect that database to remain available. Run only one DAB instance at a time because the examples use port 5000.

The optional web clients use Vite:

- demo 1: http://localhost:5173
- demo 3: http://localhost:5174
- demo 4: http://localhost:5175

Read the README inside each webapp directory for its startup command.

## Important limitations

The local, Azure SQL and MCP configurations use unauthenticated development access unless you enable the identity commands yourself. Do not expose them publicly.

The deployment example uses public ingress, ACR admin credentials and an environment-variable connection string for simplicity. It is a learning example, not a production template. Review demo/05-deploy/README.md before creating cloud resources.

