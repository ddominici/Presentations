# Deploy DAB to Azure Container Instances

This demo builds a DAB image in Azure Container Registry, runs it in Azure Container Instances and exposes REST, GraphQL and MCP endpoints. It also contains an AWS ECS task-definition example; the AWS files are a reference, not an automated deployment.

## Prerequisites

- Azure CLI logged in to a subscription where you can create resource groups, ACR and ACI resources
- The Microsoft.ContainerRegistry and Microsoft.ContainerInstance resource providers enabled
- An Azure SQL InsuranceDemo database containing the objects used by the configuration
- curl

## Configure

Copy the deployment environment file:

~~~bash
cp env.sh.example env.sh
~~~

Set RG, LOCATION, ACR, ACI_NAME, DNS_LABEL, IMAGE_TAG and CONN. ACR names and DNS labels must be globally unique. env.sh is ignored by Git.

Before deploying, fix the checked-in connection-variable mismatch in your working copy: dab-config.json currently references AZURE_SQL_CONN, while deploy-aci.sh passes CONN as DATABASE_CONNECTION_STRING. Change the configuration reference to @env('DATABASE_CONNECTION_STRING') or change the script and environment variable names so that they match.

## Deploy

From this directory:

~~~bash
./deploy-aci.sh
~~~

The script creates a resource group and registry, builds the image remotely with az acr build, creates a public ACI instance on port 5000 and waits for /health. It prints the generated FQDN.

Use the resulting host with:

~~~bash
curl http://<fqdn>:5000/health
curl http://<fqdn>:5000/api/policies
~~~

The other endpoints are /api/openapi, /graphql and /mcp. Replace the placeholder host in requests.http and mcp-client.json before using them.

## Production-mode example

promote-to-production.sh changes the local config to production mode, disables GraphQL introspection, validates, builds a new image, deletes the current container and recreates it. Use it only in a disposable resource group; it is a destructive redeployment with public ingress.

## Security limitations

The sample uses shortcuts for demonstration purposes:

| Sample shortcut | Production direction |
|---|---|
| ACR admin credentials | Managed identity with AcrPull |
| Connection string as an environment variable | Managed identity or a managed secret such as Key Vault |
| Public ACI endpoint | Private networking and a gateway |
| Unauthenticated development mode | Authentication and least privilege |
| Mutable image tag | A reviewed, pinned image tag |

The image contains the DAB configuration but not the connection-string value. The public unauthenticated configuration must not be used with real data.

## AWS reference

ecs-taskdef.json and aws-notes.md show how the same container can be described for ECS. Replace placeholders and prepare AWS networking, registry and secret-management resources before using them.

## Cleanup

Check env.sh carefully, then run:

~~~bash
./cleanup.sh
~~~

This deletes the entire resource group named by RG and every resource inside it.

