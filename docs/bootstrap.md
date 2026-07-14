# Bootstrap — a única parte da infraestrutura que não é código

Tudo neste projeto é gerido por Terraform, **exceto** a identidade que o próprio Terraform usa para correr: a role `gha-deployer`. É um problema clássico do ovo-e-galinha — uma role não se pode auto-criar antes de existir — por isso este passo é manual, feito uma única vez, e documentado aqui em vez de num ficheiro `.tf`.

## O que é a `gha-deployer`

Uma IAM Role na conta AWS `202373502174` que o GitHub Actions assume via **OIDC** (não usa access keys fixas — o workflow troca um token assinado pelo GitHub por credenciais temporárias). É referenciada em `ci.yml`, `deploy.yml` e `aws-test.yml`:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: us-east-1
```

## Como foi criada (passos de bootstrap, uma vez só)

### 1. Registar o GitHub como fornecedor de identidade OIDC na AWS

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Criar a role, confiando só neste repositório

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::202373502174:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*" }
    }
  }]
}
```

```bash
aws iam create-role --role-name gha-deployer --assume-role-policy-document file://trust-policy.json
```

> A condição `token.actions.githubusercontent.com:sub` é o que impede **qualquer outro repositório** de assumir esta role — sem ela, qualquer conta GitHub com um workflow OIDC podia pedir as mesmas credenciais.

## Permissões — o quê e porquê

> **Nota:** este projeto usava originalmente MSK (Kafka gerido) para mensagens entre `order-service` e `product-service`. A MSK foi substituída por SQS porque contas AWS Free Tier costumam bloquear a criação de clusters MSK (`SubscriptionRequiredException`) — SQS é serverless, não tem esse problema, e cobre o mesmo caso de uso de produtor único/consumidor único.

> **Nota (compute):** pela mesma razão, o `app_host` corre em `t3.micro` (elegível Free Tier) em vez de `t3.medium`. Isso dá só 1 GB de RAM para os 4 serviços Spring Boot — `modules/compute` limita cada JVM a `-Xmx180m`/`-Xmx150m` via `JAVA_TOOL_OPTIONS` no `docker-compose.yml.j2`, e a instância arranca com 2 GB de swap (`user_data` em `modules/compute/main.tf`) como rede de segurança contra OOM kills. Se a aplicação ficar lenta ou os containers reiniciarem sozinhos, é o primeiro sítio a olhar — `docker stats` na instância mostra se algum serviço está a bater no limite.

| Serviço | Porquê é preciso | Usado por |
|---|---|---|
| S3 + DynamoDB, leitura (`GetObject`, `ListBucket`, `dynamodb:*Item`) | Backend remoto do state e locking | `terraform init/plan` |
| S3, **escrita** (`s3:PutObject`) | Gravar o `.tfstate` depois de criar/alterar recursos — só é exercitado num `apply` real, por isso passou despercebido até agora | `terraform apply` |
| EC2 (`AmazonEC2FullAccess`) | Criar VPC, subnets, security groups, a instância `app_host`, ler AMIs (`DescribeImages`) e AZs (`DescribeAvailabilityZones`) | `modules/vpc`, `modules/security`, `modules/compute` |
| RDS (`AmazonRDSFullAccess`) | Criar a instância PostgreSQL e o subnet group | `modules/db` |
| SQS (`sqs:CreateQueue`, `sqs:DeleteQueue`, `sqs:TagQueue`, `sqs:SetQueueAttributes`, `sqs:GetQueueAttributes`) | Criar as filas `order-created` e `order-status-changed` | `modules/messaging` |
| IAM, com escopo | Criar a role/instance profile que a EC2 usa para autenticar no ECR (`iam:CreateRole`, `PassRole`, etc., restrito a `shop-*-app-host-role`) | `modules/compute` |
| ECR (`push`/`pull`) | Publicar as imagens dos 4 serviços | `deploy.yml`, indiretamente a EC2 |
| ECR, ao nível do registo (`ecr:PutReplicationConfiguration`) | Ativar a replicação cross-region das imagens para a região de DR. É uma ação de *registry*, não de repositório — o `Resource` tem de ser `*` | `modules/ecr` (`aws_ecr_replication_configuration`) |
| IAM (`iam:CreateServiceLinkedRole`, restrito a `AWSServiceRoleForECRReplication` via `iam:AWSServiceName`) | A primeira vez que `aws_ecr_replication_configuration` é criado, a AWS precisa de criar por trás o service-linked role da própria ECR; sem isto falha com `ValidationException` mesmo já tendo `ecr:PutReplicationConfiguration` | `modules/ecr` (`aws_ecr_replication_configuration`) |
| SSM Parameter Store (`ssm:PutParameter`, `GetParameter(s)`, `AddTagsToResource`, `DeleteParameter`, scoped) + `ssm:DescribeParameters` (não suporta scoping — `Resource` tem de ser `*`) + KMS (`kms:Decrypt`, `GenerateDataKey`) via `kms:ViaService=ssm.*.amazonaws.com` | Criar/ler os parâmetros `SecureString` com as credenciais da BD em `/shop/<env>/db/*`, em cada região | `modules/secrets` |

## Comandos para recriar as permissões do zero

```bash
aws iam attach-role-policy --role-name gha-deployer --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name gha-deployer --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

# SQS (substituiu a MSK — não precisa de FullAccess, são só 2 filas)
aws iam put-role-policy \
  --role-name gha-deployer \
  --policy-name sqs-messaging \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "sqs:CreateQueue", "sqs:DeleteQueue", "sqs:TagQueue",
        "sqs:SetQueueAttributes", "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-east-1:202373502174:*"
    }]
  }'

# escrita no state (faltava — só aparece num apply real, não em init/plan)
aws iam put-role-policy \
  --role-name gha-deployer \
  --policy-name terraform-state-write \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::service-tf-state-us-east-1-202373502174-us-east-1-an",
        "arn:aws:s3:::service-tf-state-us-east-1-202373502174-us-east-1-an/*"
      ]
    }]
  }'

aws iam put-role-policy \
  --role-name gha-deployer \
  --policy-name app-host-iam-scoped \
  --policy-document file://app-host-iam-policy.json   # ver secção anterior da conversa/PR para o JSON exato

# ECR replication config (faltava — apareceu como AccessDeniedException em
# aws_ecr_replication_configuration assim que modules/ecr passou a configurar
# replicação cross-region). É uma ação de registo, não de repositório, por
# isso o Resource tem mesmo de ser "*". O segundo statement (CreateServiceLinkedRole)
# só é exercitado na primeira vez que a replicação é ativada na conta — a AWS
# cria o SLR da ECR por trás; sem ele o apply falha com ValidationException
# mesmo já tendo ecr:PutReplicationConfiguration.
aws iam put-role-policy \
  --role-name gha-deployer \
  --policy-name ecr-replication-config \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["ecr:PutReplicationConfiguration", "ecr:DescribeRegistry"],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "iam:CreateServiceLinkedRole",
        "Resource": "arn:aws:iam::202373502174:role/aws-service-role/replication.ecr.amazonaws.com/AWSServiceRoleForECRReplication",
        "Condition": {
          "StringEquals": { "iam:AWSServiceName": "replication.ecr.amazonaws.com" }
        }
      }
    ]
  }'

# SSM Parameter Store para as credenciais da BD (faltava — apareceu como
# AccessDeniedException em aws_ssm_parameter.db_username/db_password assim
# que modules/secrets foi adicionado). SecureString usa a chave gerida
# aws/ssm por omissão, por isso as ações de KMS também são precisas,
# restritas via kms:ViaService em vez de a um ARN de chave fixo.
# ssm:DescribeParameters é uma exceção: a AWS não suporta scoping por ARN
# de parâmetro para esta ação (é usada para listar/filtrar), por isso o
# Resource tem de ser "*" mesmo com o resto da policy restrito a /shop/*/db/*.
aws iam put-role-policy \
  --role-name gha-deployer \
  --policy-name ssm-db-secrets \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssm:PutParameter", "ssm:GetParameter", "ssm:GetParameters",
          "ssm:AddTagsToResource", "ssm:DeleteParameter"
        ],
        "Resource": [
          "arn:aws:ssm:us-east-1:202373502174:parameter/shop/*/db/*",
          "arn:aws:ssm:eu-west-1:202373502174:parameter/shop/*/db/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": "ssm:DescribeParameters",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
        "Resource": "*",
        "Condition": {
          "StringLike": { "kms:ViaService": "ssm.*.amazonaws.com" }
        }
      }
    ]
  }'
```

## Porque não `AdministratorAccess`

Esta role corre **sem supervisão humana**, disparada por qualquer push para `main` — é uma superfície de ataque diferente de uma credencial de developer local. Vale a pena o esforço extra de a manter com o mínimo de permissões que o projeto realmente usa, em vez de dar acesso total à conta.

## Se precisares de expandir mais tarde (DR)

O trabalho de disaster recovery (`infrastructure/`) vai precisar de permissões adicionais na mesma role: `route53:*HealthCheck*`, `route53:ChangeResourceRecordSets`, `secretsmanager:*`, `lambda:*`, `sns:*`, `rds:PromoteReadReplica`, `ec2:StartInstances`/`StopInstances`. Atualiza esta tabela quando os adicionares.
