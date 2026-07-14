# Security

## IAM roles and least privilege

| Role | Attached to | Permissions | Rationale |
|---|---|---|---|
| `app-host` role (per region) | EC2 app host, via instance profile | `AmazonEC2ContainerRegistryReadOnly` (managed policy); an inline policy scoped to exactly the 2 SQS queue ARNs for `SendMessage`/`ReceiveMessage`/`DeleteMessage`/`GetQueueAttributes`/`GetQueueUrl`; an inline policy scoped to exactly the 2-3 SSM parameter ARNs for this project/environment for `GetParameter`/`GetParameters`/`GetParametersByPath` | No wildcard resources anywhere in these policies — every `Resource` is a concrete ARN list built from Terraform outputs, not `"*"`. |
| `dr-promote-lambda` role | The DR-controller Lambda | `rds:PromoteReadReplica` + `rds:DescribeDBInstances` scoped to the single standby replica ARN; `ssm:PutParameter` scoped to the single status parameter ARN; CloudWatch Logs write | The Lambda can promote *one specific* replica and flip *one specific* flag — it cannot touch any other RDS instance or parameter in the account. |
| GitHub Actions OIDC role | CI/CD workflows | Whatever the repo's `AWS_ROLE_TO_ASSUME` grants (defined outside this repo, at bootstrap time — see `docs/setup.md`) | OIDC federation means no long-lived AWS access keys are stored as GitHub secrets; the trust policy is scoped to this specific repository/branch. |

## Secrets handling

- The database master username/password are **only ever** supplied to
  Terraform once, as `TF_VAR_db_username` / `TF_VAR_db_password` from
  GitHub Secrets, purely to create the initial SSM `SecureString`
  parameters (`/shop/<env>/db/username`, `/shop/<env>/db/password`) in
  each region.
- From that point on, **nothing else reads the GitHub secret**: the
  Ansible `app-deploy` role fetches the credentials directly on the EC2
  instance, at deploy time, via `aws ssm get-parameter --with-decryption`
  using the instance's own IAM role — not via a file rendered by the CI
  runner or committed anywhere.
- `no_log: true` is set on every Ansible task that touches the decrypted
  credentials or the rendered `docker-compose.yml`, so they never appear
  in playbook/job logs.
- The standby's replica inherits the primary's credentials automatically
  (that's how RDS read replicas work); the `dr` environment stores an
  identical copy in its own region's SSM so the standby app host can read
  them the same way the primary does.
- No secret is ever hardcoded in Terraform, Ansible, or application
  config — every credential reference in this repo is either a Terraform
  variable (sourced from GitHub Secrets or remote state) or an SSM
  parameter name.

## Network segmentation

Five security groups, each allowing only what a specific caller needs
(see `docs/architecture.md` §3 and the `terraform/modules/security`
module): the gateway is the only thing open to the internet (port 8080);
`user-service` and `product-service` each accept traffic only from the
gateway and from `order-service`, on their own port; `order-service`
accepts traffic only from the gateway; RDS accepts port 5432 only from
the three service security groups. Every group's egress is unrestricted
(`0.0.0.0/0` outbound), which is a deliberate simplification — see
`docs/limitations.md`.

## Known tradeoff: SSH ingress

`ssh_ingress_cidr` defaults to `0.0.0.0/0` on the app-host SSH security
group, because GitHub-hosted Actions runners have no fixed IP range to
narrow it to. This is documented here rather than silently accepted:
the safer alternative is to run the Ansible deploy step through **AWS
Systems Manager Session Manager** instead of direct SSH (no inbound port
22 at all), which is called out as a roadmap item in
`docs/limitations.md`.

## DR-specific security notes

- The failover Lambda's blast radius is deliberately minimal (see table
  above) — it cannot be used to promote or modify any resource other
  than the one standby replica it's scoped to.
- The standby's SSM parameters and IAM policy live in a completely
  separate region from the primary's; a compromise of one region's app
  host does not expose the other region's credentials.
- `terraform.tfvars` files in this repo hold no secrets — only
  non-sensitive defaults (region, project name, tags).
