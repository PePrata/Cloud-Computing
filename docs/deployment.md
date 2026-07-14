# Deployment

Everything below is what `.github/workflows/deploy.yml` runs automatically
on every merge to `main`. It's written here as a manual, step-by-step
sequence so it's also usable directly from a workstation (e.g. for the
initial bootstrap apply, before OIDC/environments exist to gate it).

## 1. Primary region (`us-east-1`)

```bash
cd terraform/environments/dev
terraform init
terraform apply \
  -var="db_username=$DB_USERNAME" \
  -var="db_password=$DB_PASSWORD" \
  -var="key_name=$EC2_KEY_NAME"
```

This provisions, in order (Terraform resolves the order from resource
references): VPC → security groups → SSM parameters (credentials) → RDS
(Multi-AZ, `backup_retention_period` days of automated backups) →
SQS queues → ECR repositories (with replication configured to
`eu-west-1`) → the EC2 app host (Elastic IP, IAM role scoped to ECR/SQS/
SSM). It also renders `ansible/inventory/primary/hosts.ini` and
`group_vars/all.yml`.

## 2. Standby region (`eu-west-1`)

```bash
cd terraform/environments/dr
terraform init
terraform apply -var="key_name=$EC2_KEY_NAME_DR"
```

Reads the primary's remote state for the source DB ARN and credentials,
then provisions the same module set with `is_replica = true` for the
database (cross-region read replica) and `manage_instance_state = true`
for compute (EC2 host starts **stopped** — pilot-light — unless
`standby_instance_state` is overridden to `"running"`).

## 3. DR controller (`us-east-1`, spans both regions)

```bash
cd terraform/environments/dr-controller
terraform init
terraform apply \
  -var="hosted_zone_id=$ROUTE53_ZONE_ID" \
  -var="dns_name=$APP_DNS_NAME"
```

Reads both `dev` and `dr` remote state and creates: two Route 53 health
checks, a `PRIMARY`/`SECONDARY` failover record pair for `dns_name`, a
CloudWatch alarm on the primary health check, an SNS topic, and the
Lambda that promotes the standby replica when the alarm fires.

## 4. Build and push images

```bash
for service in api-gateway user-service product-service order-service; do
  docker build -t $ECR_REGISTRY/shop-$service:latest ./services/$service
  docker push $ECR_REGISTRY/shop-$service:latest
done
```

Pushed once, to the primary region's registry only — the ECR
replication configured in step 1 mirrors every push to the standby
region automatically, so the standby app host can `docker pull` locally
during a failover.

## 5. Deploy with Ansible

```bash
cd ansible
ansible-playbook -i inventory/primary/hosts.ini playbook.yml
ansible-playbook -i inventory/dr/hosts.ini playbook.yml   # only reachable while the standby host is running
```

Each run: installs Docker + the Compose plugin, looks up the account ID
and its own region to build the ECR hostname, fetches DB credentials
(and, on the standby, the active/standby status flag) from SSM
Parameter Store using the host's own IAM role, renders
`docker-compose.yml`, and brings the stack up with
`docker compose up -d --wait`.

## CI/CD pipeline summary (`.github/workflows/`)

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | Pull request to `main` | `mvn test`, then `terraform plan` for **both** `dev` and `dr` workspaces |
| `deploy.yml` | Push to `main` | `terraform apply`: primary (approval-gated) → standby (approval-gated) → dr-controller; then build/push images; then Ansible against both inventories |
| `dr-drill.yml` | Manual (`workflow_dispatch`) | Stops the primary host, waits for automatic failover, measures RTO, restarts the primary — see `docs/dr.md` |

All AWS authentication in every workflow is via OIDC
(`aws-actions/configure-aws-credentials` + `role-to-assume`); no
long-lived AWS access keys are stored in GitHub.
