# bjj-infra

Terraform infrastructure for the BJJ API, deployed to AWS EKS. Provisions VPC, EKS, RDS, IAM roles, and Secrets Manager. CI/CD via GitHub Actions — plan on `develop`/PRs, apply on merge to `main`.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  VPC  10.42.0.0/16  (us-east-1a, us-east-1b)        │
│                                                     │
│  Public subnets                                     │
│  ├── NAT Gateway (single, cost optimised)           │
│  └── ALB (internet-facing, managed by LB controller)│
│                                                     │
│  Private subnets                                    │
│  ├── EKS managed node group  (t3.medium, 1–2 nodes) │
│  └── RDS PostgreSQL 14        (not publicly exposed) │
└─────────────────────────────────────────────────────┘
```

### IAM / security model

| Role | Purpose |
|------|---------|
| `bjj-eks-cluster-role` | EKS control plane |
| `bjj-eks-node-role` | EC2 worker nodes (ECR read, CNI, worker policies) |
| `bjj-lb-controller-role` | AWS Load Balancer Controller via IRSA |
| `bjj-irsa-role` | App pod IRSA — `GetSecretValue` on `bjj-db-secret-v2` |

DB credentials are stored in AWS Secrets Manager (`bjj-db-secret-v2`). The app pod reads them at runtime through IRSA — no secrets are baked into container images or K8s secrets.

## Repository layout

```
bjj-infra/
├── .github/workflows/
│   ├── terraform.yml          # plan on develop/PR, apply on main
│   └── terraform-destroy.yml  # manual teardown only
├── argo/
│   └── application.yaml       # ArgoCD app definition
└── terraform/
    ├── envs/
    │   └── dev/               # root module (init here)
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── variables.tf
    │       └── versions.tf
    └── modules/
        ├── eks/               # EKS cluster + managed node group
        ├── iam/               # all IAM roles, policies, Secrets Manager secret
        ├── rds/               # RDS PostgreSQL subnet group + instance
        └── vpc/               # VPC, subnets, IGW, NAT, route tables
```

## CI/CD workflow

| Git event | Terraform action |
|-----------|-----------------|
| Push to `develop` | `init` → `validate` → `plan` |
| PR targeting `main` | `init` → `validate` → `plan` (review gate) |
| Push/merge to `main` | `init` → `validate` → `plan` → **`apply`** |
| Manual `workflow_dispatch` | `init` → **`destroy`** (terraform-destroy.yml only) |

## Required GitHub secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM credentials with sufficient permissions |
| `AWS_SECRET_ACCESS_KEY` | |
| `DB_USER` | RDS master username |
| `DB_PASSWORD` | RDS master password |

## Running locally

```bash
cd terraform/envs/dev

terraform init
terraform plan \
  -var="db_user=<user>" \
  -var="db_password=<password>"

terraform apply \
  -var="db_user=<user>" \
  -var="db_password=<password>"
```

Terraform 1.6+ and AWS provider ~5.x are required (see `versions.tf`).

## Module outputs

| Output | Description |
|--------|-------------|
| `eks_cluster_role_arn` | ARN of the EKS cluster IAM role |
| `eks_node_role_arn` | ARN of the EKS node IAM role |
| `lb_controller_role_arn` | ARN of the LB controller IRSA role |
| `secrets_policy_arn` | ARN of the Secrets Manager read policy |
| `db_secret_arn` | ARN of `bjj-db-secret-v2` in Secrets Manager |

## Design decisions

- **Single NAT Gateway** — reduces cost for a dev environment at the expense of cross-AZ resilience.
- **IAM provisioned before EKS** — cluster and node roles must exist before the EKS control plane is created; IRSA roles are wired up after EKS so the OIDC provider URL is available.
- **Secrets Manager over K8s Secrets** — credentials never touch etcd; pod fetches them at runtime via IRSA.
- **Destroy is manual-only** — `terraform-destroy.yml` has no automatic trigger; prevents accidental teardown from a bad push.
