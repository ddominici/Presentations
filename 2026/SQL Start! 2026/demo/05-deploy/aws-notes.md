# Running the same image on AWS

The image is `mcr.microsoft.com/azure-databases/data-api-builder`. Nothing about it is
Azure-specific: it is a stateless .NET process listening on port 5000.

## ECS on Fargate

```bash
# 1 — mirror the image into ECR (or pull directly from MCR if egress allows)
aws ecr create-repository --repository-name dab
docker pull mcr.microsoft.com/azure-databases/data-api-builder:latest
docker build -t dab:2 .                      # same Dockerfile as the Azure demo
docker tag  dab:2 <account>.dkr.ecr.eu-west-1.amazonaws.com/dab:2
docker push       <account>.dkr.ecr.eu-west-1.amazonaws.com/dab:2

# 2 — store the connection string
aws secretsmanager create-secret --name dab/sql-conn \
  --secret-string "Server=tcp:...;Database=InsuranceDemo;User ID=...;Password=...;Encrypt=true;"

# 3 — register the task definition and run it behind an ALB
aws ecs register-task-definition --cli-input-json file://ecs-taskdef.json
aws ecs create-service --cluster dab-cluster --service-name dab-api \
  --task-definition dab-api --desired-count 2 --launch-type FARGATE \
  --load-balancers targetGroupArn=<tg-arn>,containerName=dab,containerPort=5000 \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet>],securityGroups=[<sg>],assignPublicIp=DISABLED}"
```

Target group health check path: `/health`. Scale on CPU or request count — the process
is stateless, so replicas need no coordination beyond a shared L2 cache if you use one.

## App Runner

Simpler when you do not need a VPC ingress: point App Runner at the ECR image, set the
port to 5000, and supply `DATABASE_CONNECTION_STRING` from Secrets Manager. HTTPS and
scaling come for free.

## What actually changes across clouds

| Concern | Azure | AWS |
|---|---|---|
| Identity to the database | managed identity, no secret | SQL login or service principal with a client secret from Secrets Manager |
| Secret storage | Key Vault via `@akv()` | Secrets Manager injected as an env var |
| Private connectivity | VNet integration / Private Link | firewall rules, Private Link or a VPN back to Azure SQL |
| Observability | Application Insights or OTLP | OTLP to an ADOT sidecar, CloudWatch logs |
| Config, entities, permissions | identical | identical |

The honest framing for the session: **DAB is genuinely portable; the identity story is
not.** Cross-cloud means secrets instead of managed identities, plus a real conversation
about latency and egress before anybody promises single-digit milliseconds.
