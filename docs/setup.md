# Setup

## Local prerequisites

- Java 21 (Temurin) and Maven, to build/test each service:
  `cd services/<name> && mvn clean test`.
- Docker + Docker Compose plugin, to run the full stack locally.
- Each service has a local (H2, in-memory) profile so it can run without
  any AWS dependency — see `application.yml` / `application-local.yml`
  inside each service.

## AWS prerequisites (one-time, before the pipeline can run)

1. **Two AWS regions available on the account**: `us-east-1` (primary)
   and `eu-west-1` (standby). No special enablement needed for either —
   both are enabled by default on new accounts.
2. **Terraform remote state backend** — one S3 bucket + one DynamoDB
   lock table, in `us-east-1`, shared by all three environments (`dev`,
   `dr`, `dr-controller` each use their own state *key* inside it):
   - S3 bucket: `service-tf-state-us-east-1-<account-id>-us-east-1-an`
     (versioning + encryption enabled).
   - DynamoDB table: `service-tf-locks` (partition key `LockID`, string).
3. **OIDC federation for GitHub Actions** — an IAM OIDC identity provider
   for `token.actions.githubusercontent.com`, and an IAM role
   (`AWS_ROLE_TO_ASSUME` secret) with a trust policy scoped to this
   repository, so the workflows never use long-lived access keys.
4. **An EC2 key pair in *each* region** (`us-east-1` and `eu-west-1`) —
   Terraform references them by name (`key_name` variable) but does not
   create them, since key pairs aren't imported/exported across regions.
5. **A Route 53 public hosted zone** you control (or can delegate a
   subdomain to), used by the `dr-controller` environment for the
   failover DNS record.
6. **GitHub repository secrets**:

   | Secret | Used by |
   |---|---|
   | `AWS_ROLE_TO_ASSUME` | All workflows, OIDC auth |
   | `DB_USERNAME` / `DB_PASSWORD` | `dev` environment (stored into SSM Parameter Store; the `dr` environment reads the same values back via remote state, it does not need its own copies of these secrets) |
   | `EC2_KEY_NAME` | `dev` (primary) environment |
   | `EC2_KEY_NAME_DR` | `dr` (standby) environment |
   | `ANSIBLE_SSH_KEY` / `ANSIBLE_SSH_KEY_DR` | Ansible SSH access to the primary / standby app host |
   | `ROUTE53_ZONE_ID` / `APP_DNS_NAME` | `dr-controller` environment |

7. **GitHub Environments** named `production-primary` and
   `production-standby`, each with at least one required reviewer — this
   is what gates `terraform apply` in `deploy.yml` behind manual
   approval.

Once all of the above exist, `terraform init` in each
`terraform/environments/<name>` directory will succeed and the CI/CD
workflows described in `docs/deployment.md` take over.
