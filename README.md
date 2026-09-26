# Contact form on AWS EKS

Terraform provisions the foundational AWS infrastructure. Ansible builds the images on a local workstation, pushes them to ECR, installs the EKS controllers, bootstraps PostgreSQL, and deploys the Flask application. The AWS Load Balancer Controller creates the ALB from Ansible's Ingress. [Architecture](docs/architecture.md) · [Requirement-by-requirement review](docs/requirements-matrix.md) · [Security checks](docs/security-controls.md) · [Demo checklist](docs/demo-checklist.md).

**Demo status (25 September 2026):** Local tests passed, Terraform provisioned the AWS environment, and Ansible deployed two ready Flask Pods. An ALB readiness request returned HTTP 200 and a fictional submission was retrieved from RDS using the read-only verifier Job. The node group was then scaled from two workers to one: after the old worker left, the sole node was Ready, both Flask Pods were available and ALB readiness still returned HTTP 200. This sacrifices node redundancy to reduce compute use. Security observations and outstanding exceptions are recorded in [the security controls document](docs/security-controls.md). Confirm the remaining AWS credit before leaving the stack running; this deployment is still consuming credits.

**Follow-up (26 September 2026):** The Free Plan was `ACTIVE`; a fresh Terraform plan showed `No changes`, one worker and both Flask Pods were Ready, and the ALB readiness endpoint returned HTTP 200. A [new redacted security audit](evidence/security-audit-2026-09-26-redacted.txt) records desired size one. The credit balance is a point-in-time report, so recheck it during the demo window.

## Prerequisites

Use Ubuntu WSL2 with AWS CLI, Terraform >=1.9, Docker with WSL integration, kubectl, Helm, Python 3 and Ansible Core. The `contact-demo` AWS CLI profile must resolve to an IAM user with permissions to create the listed AWS services, never the account root. This demo uses `us-east-1`. The example initially requests two Free Plan eligible `m7i-flex.large` nodes (4 vCPUs total) and one `db.t4g.micro`; the live node group was later scaled to one node by setting `node_count = 1` in the ignored `demo.tfvars`. Check regional quotas and your account's allowed types with `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query 'InstanceTypes[].InstanceType' --output text` before applying.

For Ansible's Kubernetes modules, install the collection and Python dependencies in the Ansible pipx environment:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
pipx inject ansible-core kubernetes PyYAML jsonpatch
```

Run these from the repository root inside WSL. Confirm credentials, credits, billing alerts and quotas before proceeding. Only enter sample contact data. Terraform state is local, ignored by Git, and contains infrastructure metadata; keep it private and back it up securely until teardown.

## Local application check

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r app/requirements.txt
python -m unittest discover -s app/tests -v
```

The repository's `app/README.md` explains local PostgreSQL testing. Production defaults to `DB_SSLMODE=require`; `DB_SSLMODE=disable` is for a disposable local PostgreSQL container without TLS only. Do not set it in EKS.

## Provision from WSL

1. Check the balance in Billing and set cost alerts. This stack consumes credits while it exists: EKS control plane, EC2 nodes, RDS, NAT gateway, ALB, logs and Secrets Manager. Scaling nodes to zero does **not** stop the other charges. Do the practice run close to the demo; delete the stack afterwards.
2. Set the EKS API allowlist to your *current* public IPv4, with `/32`. The example address is a placeholder. A changed home IP requires updating the tfvars and reapplying Terraform.

```bash
export AWS_PROFILE=contact-demo AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity --query Arn --output text
cp terraform/envs/demo/demo.tfvars.example terraform/envs/demo/demo.tfvars
# Edit terraform/envs/demo/demo.tfvars: replace operator_cidr with YOUR public IPv4/32.
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars -out=demo.tfplan
```

Review the planned resource count and costs against the **actual remaining** Free Plan credits before running the next command:

```bash
terraform -chdir=terraform apply demo.tfplan
aws eks update-kubeconfig --name contact-demo --region us-east-1 --alias contact-demo
kubectl get nodes -o wide
aws rds describe-db-instances --db-instance-identifier contact-demo-postgres \
  --query 'DBInstances[0].{endpoint:Endpoint.Address,public:PubliclyAccessible}'
aws secretsmanager describe-secret --secret-id contact-demo/app-db \
  --query '{name:Name,arn:ARN}'
```

The app secret's first version is created by the Ansible database bootstrap Job. Never print its `SecretString` during the demo.

## Deploy and verify

```bash
ansible-playbook ansible/deploy.yml
kubectl -n contact-form get deployments,services,ingresses,jobs
kubectl -n contact-form rollout status deployment/contact-form
```

Ansible prints the ALB HTTP address when the Ingress receives a hostname. Wait a few minutes for healthy ALB targets, then browse to that address and submit a **fictional** name, email and message. Confirm the row with the short-lived, SELECT-only verifier:

```bash
./scripts/verify.sh
mkdir -p evidence/private
./scripts/security-audit.sh > evidence/private/security-audit.txt
chmod 600 evidence/private/security-audit.txt
ansible-playbook ansible/deploy.yml  # rerun to check idempotence
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars
```

The security audit is mixed text/JSON; redact ARNs, addresses and user information before sharing it. The initial 25 September audit used the wrong EKS API response field and returned `null` for endpoint settings; the script is corrected and an independent `describe-cluster` query confirmed private access and a public operator `/32`. See `docs/security-controls.md` for confirmed checks and exceptions. The read-only Security Hub API returned `SubscriptionRequiredException` on this Free Plan account; the repository reports manual AWS control comparisons, not AWS-generated findings. Do not activate advanced account features or upgrade just for this demo. The public listener uses HTTP without a personal domain/ACM certificate: this is an explicit temporary demo exception. Do not submit real contact information.

## Pause and teardown

If pausing briefly, change `node_count = 0` in `terraform/envs/demo/demo.tfvars`, then run `terraform plan/apply` again. EKS, RDS, NAT, ALB and secret charges continue, and the form becomes unavailable. Raise it to **at least 1** and reapply before the demo; the verified one-worker setup runs both Flask Pods on the same node, so choose 2 if worker redundancy is needed and credits permit. Do **not** lose the local Terraform state.

After the final demonstration, remove the Ingress first so its controller can delete the ALB, then destroy the stack. Keep at least one working node until ALB deletion is confirmed:

```bash
kubectl -n contact-form delete ingress contact-form --wait=true
# Confirm in the AWS EC2 console or CLI that its ALB has disappeared.
aws elbv2 describe-load-balancers --query 'LoadBalancers[].{name:LoadBalancerName,dns:DNSName}' --output table
terraform -chdir=terraform destroy -var-file=envs/demo/demo.tfvars
terraform -chdir=terraform state list
```

After destroy, check the EKS cluster, RDS instance, NAT gateway, ALBs, ECR repo and Secrets Manager secrets in AWS. If the ALB remains, let its controller finish deleting before Terraform destroys VPC/network resources. RDS final snapshots are disabled for this disposable demo and both app secret recovery windows are zero: destroying the stack deletes the database and secrets. Save any redacted demo evidence before teardown.

## Failed node group recovery

The first demo apply on 25 September 2026 created the network, EKS cluster and RDS, but EKS rejected `t3.medium` because the Free Plan only permits Free Tier eligible EC2 types. The Terraform default now selects `m7i-flex.large`, which AWS identified as eligible in this account, with 8 GiB of RAM and 2 vCPUs per node. When recovering an existing failed node group, keep the local Terraform state and the same `operator_cidr` in the ignored tfvars file; run a fresh `terraform plan -var-file=envs/demo/demo.tfvars -out=repair.tfplan` and review the replacement actions. A failed EKS node group can remain in `CREATE_FAILED`; Terraform should replace the existing group if it is still present in state. Never reuse the original saved `demo.tfplan`, which still contains the disallowed instance type. If the replacement fails, inspect EKS health and Terraform state before any further apply.

## Layout

- `app/`: Flask, container build, local tests, database bootstrap and read-only verifier.
- `terraform/`: VPC, EKS, node group, RDS, ECR, IAM, Pod Identity, networking and Secrets Manager.
- `ansible/`: local image publishing, controller setup, bootstrap and application deployment.
- `k8s/`: namespace, service accounts, Job, CSI secret mount, deployment, service and ALB Ingress.
- `scripts/`: read-only checks and temporary verifier Job.
- `docs/`: architecture, requirement-by-requirement review, observed security checks/findings and live-demo checklist.
- `evidence/`: redacted screenshots/check results; `evidence/private/` is ignored.
