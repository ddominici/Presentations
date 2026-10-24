# Running a DAB container on AWS

The published image is `mcr.microsoft.com/azure-databases/data-api-builder`. DAB is a .NET process that listens on port 5000; the AWS examples here show the deployment shape. They have not been validated as a one-command deployment and contain placeholders that must be replaced.

## ECS on Fargate outline

Run AWS CLI commands from `demo/05-deploy`, where the Dockerfile and task definition are located. First create an ECR repository and push a pinned DAB image. For example:

```bash
aws ecr create-repository --repository-name dab
docker pull mcr.microsoft.com/azure-databases/data-api-builder:<version>
docker tag mcr.microsoft.com/azure-databases/data-api-builder:<version> <account>.dkr.ecr.<region>.amazonaws.com/dab:<version>
docker push <account>.dkr.ecr.<region>.amazonaws.com/dab:<version>
```

Update the image, region, account, IAM roles, log group and Secrets Manager ARN in `ecs-taskdef.json`. Store the database connection string in Secrets Manager, and grant the task execution role permission to read it. The task definition currently expects a secret named `DATABASE_CONNECTION_STRING` and uses `/health` for its container check.

Register the task definition and create a service behind an Application Load Balancer. Configure a target group health check on `/health` and allow inbound traffic to port 5000 from the load balancer. The example task definition uses an ADOT-compatible OTLP endpoint at `localhost:4317`, but it does not include an ADOT sidecar; add one or change/remove that setting to match your telemetry setup.

The sample `ecs-taskdef.json` references environment-specific resources and is not directly deployable. The commands below are an outline only:

```bash
aws ecs register-task-definition --cli-input-json file://ecs-taskdef.json
aws ecs create-service --cluster <cluster> --service-name dab-api \
  --task-definition dab-api --desired-count 2 --launch-type FARGATE \
  --load-balancers targetGroupArn=<target-group-arn>,containerName=dab,containerPort=5000 \
  --network-configuration 'awsvpcConfiguration={subnets=[<subnet>],securityGroups=[<security-group>],assignPublicIp=DISABLED}'
```

## App Runner

An alternative is to point App Runner at an ECR image, configure the container port as 5000, and inject `DATABASE_CONNECTION_STRING` from Secrets Manager. Check whether your database requires private connectivity and configure a VPC connector accordingly.

## Cross-cloud considerations

| Concern | Azure example | AWS example |
|---|---|---|
| Database identity | Managed identity or configured SQL credentials | SQL credentials or a supported service principal flow |
| Secret storage | Key Vault / runtime environment | Secrets Manager injected into the task |
| Private connectivity | VNet integration / Private Link | VPC networking, VPN or PrivateLink where supported |
| Observability | Application Insights or OTLP | CloudWatch logs and an OTLP collector such as ADOT |
| DAB entity/config model | DAB config | Same DAB config model, with environment-specific values |

Database authentication support depends on the database provider and hosting environment. Verify the selected DAB version's provider requirements. Cross-cloud deployments also need a review of database reachability, latency, egress charges and secret rotation.
