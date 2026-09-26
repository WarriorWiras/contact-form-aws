# Contact form on AWS

This is my SIT DevSecOps internship assignment. A visitor fills in a Flask form with a name, email and message. The message goes through an AWS Application Load Balancer (ALB) to Flask on Amazon EKS, then into PostgreSQL on Amazon RDS.

I run the setup from **Ubuntu WSL on my Windows laptop**. Terraform creates the AWS foundation. Ansible builds and deploys the app. The AWS Load Balancer Controller then creates the ALB from the Kubernetes Ingress. [See the architecture picture](docs/architecture.md).

## Where the project stands

- **25 September 2026:** I created the AWS resources with Terraform, deployed with Ansible, sent a fictional form entry and read it back from RDS. I scaled the worker nodes from two to one to use fewer credits.
- **26 September 2026:** The AWS Free Plan was active. One worker was Ready, both Flask Pods were available, Terraform said `No changes`, and the ALB health check returned HTTP 200. The [latest redacted security audit](evidence/security-audit-2026-09-26-redacted.txt) shows one worker.
- The live interview demo and eventual AWS cleanup are still to be done. AWS resources continue using credits even when my laptop is off.

For a detailed assignment checklist, see [requirements](docs/requirements-matrix.md). For findings and limitations, see [security controls](docs/security-controls.md).

## Words I use in the demo

| Word | Simple meaning here |
| --- | --- |
| Terraform | Code that creates the AWS network, EKS cluster, database, roles and other basic resources. |
| Ansible | The playbook that builds the container images and puts the app into EKS. |
| EKS / worker | AWS-managed Kubernetes / the private computer where my app containers run. |
| Pod / Deployment | A running app container / instructions that keep the desired app Pods running. |
| RDS | The private PostgreSQL database where submitted messages are stored. |
| Secrets Manager | AWS storage for the database passwords; I do not put passwords in Git. |
| ECR | AWS storage for the container images built on my laptop. |
| Ingress / ALB | Kubernetes traffic instructions / the public entry point created from them. |
| `terraform.tfstate` | Terraform's private record of what it created. I need it for updates and cleanup. |

## Start a WSL session for the existing deployment

In Windows PowerShell, open Ubuntu with `wsl -d Ubuntu`. Then run these commands **from the project folder**:

```bash
cd ~/projects/contact-form-aws
export PATH="$HOME/.local/bin:$PATH"
export AWS_PROFILE=contact-demo AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity --query Arn --output text
```

The last command should show `user/contact-demo-deployer`, **not** `root`. If it says the login session has expired, run `aws login --profile contact-demo --region us-east-1`, finish the browser/MFA steps and try again. This login normally needs renewing after a session expires; it does not mean EKS has stopped.

Check credits and the running app:

```bash
aws freetier get-account-plan-state \
  --query '{plan:accountPlanType,status:accountPlanStatus,remaining:accountPlanRemainingCredits}' \
  --output json
kubectl get nodes
kubectl -n contact-form get deployment,ingress
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars
```

Expected today: Free Plan active, **one** Ready worker, Flask Deployment **2/2** available and Terraform `No changes`. Credit figures can change; use the current AWS result, not the older number written in the evidence. `terraform plan` checks for changes; it does not create anything.

Find the ALB and check that the app can reach the database:

```bash
ALB_HOST="$(kubectl -n contact-form get ingress contact-form \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "http://$ALB_HOST"
curl --max-time 15 -i "http://$ALB_HOST/health/ready"
```

`HTTP 200` with `ready` means Flask answered **and** its database check worked. Open the printed address in a browser for the form. Use made-up names and email addresses only.

## First-time setup on a new workstation or account

These are the original build steps. **If the AWS stack is already running, do not copy the example variables over your real `demo.tfvars` or try to create a second stack for practice.** Terraform, AWS CLI, Docker, kubectl, Helm, Python and Ansible Core must be installed in Ubuntu WSL. Docker Desktop needs Ubuntu WSL integration. Terraform needs version 1.9 or newer.

Install Ansible's Kubernetes support if missing:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
pipx inject ansible-core kubernetes PyYAML jsonpatch
```

1. Check remaining Free Plan credit, AWS billing alerts and the EC2/RDS types allowed for this account. This stack uses credit for EKS, workers, RDS, NAT, ALB, logs and secrets.
2. On a **first build only**, copy `terraform/envs/demo/demo.tfvars.example` to `terraform/envs/demo/demo.tfvars`. Replace `operator_cidr` with your current public IPv4 address followed by `/32`. This limits who can reach the EKS API. The example address is not usable. The example starts with two workers; the running demo uses `node_count = 1` in the private file.
3. Keep the real `demo.tfvars` and `terraform.tfstate` off Git. If your home IP changes, update `operator_cidr` and apply Terraform again.

```bash
cp terraform/envs/demo/demo.tfvars.example terraform/envs/demo/demo.tfvars  # first build only
# Edit demo.tfvars and set operator_cidr to YOUR public IPv4/32.
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars -out=demo.tfplan
```

`fmt` checks layout, `init` gets the Terraform providers, `validate` checks the configuration, and `plan` shows what AWS resources would be created. Read the plan and confirm there is enough credit. Only then run:

```bash
terraform -chdir=terraform apply demo.tfplan
aws eks update-kubeconfig --name contact-demo --region us-east-1 --alias contact-demo
kubectl get nodes -o wide
aws rds describe-db-instances --db-instance-identifier contact-demo-postgres \
  --query 'DBInstances[0].{status:DBInstanceStatus,public:PubliclyAccessible,encrypted:StorageEncrypted}' \
  --output table
aws secretsmanager describe-secret --secret-id contact-demo/app-db \
  --query '{name:Name,arn:ARN}' --output json
```

`apply` creates the resources; `update-kubeconfig` lets kubectl talk to EKS. Look for Ready workers, private/encrypted RDS, and a Secrets Manager **name and ARN**. Terraform creates the app secret container; Ansible's database Job adds its first password later. Never display `SecretString`.

### Deploy the application

Run Ansible after Terraform and at least one worker are ready:

```bash
ansible-playbook ansible/deploy.yml
kubectl -n contact-form get deployment,service,ingress,pods
kubectl -n contact-form rollout status deployment/contact-form
```

Ansible builds the Flask and database-helper images on this laptop, sends them to ECR, installs the ALB and secret-mounting helpers in EKS, creates the database table and limited-access database users, and starts Flask. It prints the ALB address. The first run changes resources; a repeat run should finish with `changed=0` when nothing changed. Two healthy Flask Pods show as **2/2** even though the current demo uses **one worker**.

**After this README rewrite:** the playbook's image tag includes tracked files under `app/`, including `app/README.md`. Its first run after the new commit may rebuild both images and start a new database setup Job, even though the Flask code stayed the same. Let that run finish and check the app; run Ansible again to show `changed=0`. Do this before the scheduled demo if you want a short, predictable repeat run during the meeting.

### Prove the form saves a message

Open the ALB address, enter a **fictional** name, email and message, and submit the form. Then run:

```bash
./scripts/verify.sh
```

This creates a short-lived verification Job inside EKS. It can **read** recent database rows but cannot change them. A line showing the fictional message proves that the form reached RDS.

The local Flask unit tests do not need AWS. From the project folder:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r app/requirements.txt
cd app
python -m unittest discover -s tests -v
cd ..
```

The tests check input handling, database inserts and the ready endpoint. For local Docker/PostgreSQL testing, see [the app guide](app/README.md).

## What to show and say in the live demo

Use the [short demo checklist](docs/demo-checklist.md) to keep your place. The full stack **already exists**: a no-change Terraform plan or apply shows that it is managed, but will not recreate EKS and RDS. If the reviewer expects a brand-new build during the meeting, agree on that in advance; do not destroy the working app just to show creation.

| Show | What it proves |
| --- | --- |
| `terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars` | My laptop can read the Terraform setup and AWS resources match it. |
| `kubectl get nodes` | My EKS worker is running in a private subnet. |
| `aws rds describe-db-instances ...` | RDS is private and its storage is encrypted. |
| `aws secretsmanager describe-secret ...` | The secret exists. Show its name, **not its password**. |
| `ansible-playbook ansible/deploy.yml` | My laptop can repeat the app deployment. |
| `kubectl -n contact-form get deployment,service,ingress` | Flask, the internal Service and the ALB route exist. |
| ALB browser page, fictional submission, `./scripts/verify.sh` | A message travels from the form to PostgreSQL. |
| [security notes](docs/security-controls.md) and redacted audit | What I checked, what I fixed, and which demo limits remain. |

The ALB is made by the **AWS Load Balancer Controller** after Ansible creates the Ingress; Terraform provides its networking and permissions. The public form currently uses **HTTP**. EKS also has a public API limited to the operator's `/32`. Security Hub was not available in this Free Plan, so the security findings are **manual checks**, not AWS-generated scores. Do not use real contact details for this HTTP demo.

## Credits, pause and cleanup

Turning off the laptop does **not** stop AWS charges/credit use. Changing `node_count` in the private tfvars from `1` to `0` pauses workers and makes the app unavailable, but EKS, RDS, NAT, ALB and secrets still use credits. Change it to at least `1` and run Terraform plan/apply before a demo. Two workers offer more worker redundancy but use more compute.

**After the agreed demo window**, clean up the AWS stack. Save redacted proof first. With at least one working node, delete the Ingress so the controller can remove the ALB; check that this project's ALB is gone before destroying the VPC:

```bash
kubectl -n contact-form delete ingress contact-form --wait=true
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{name:LoadBalancerName,dns:DNSName}' --output table
terraform -chdir=terraform destroy -var-file=envs/demo/demo.tfvars
terraform -chdir=terraform state list
```

`destroy` removes the database and demo secrets **without a final RDS snapshot**. Keep the local Terraform state until cleanup succeeds, and check the AWS Console/CLI afterwards for any remaining EKS, RDS, NAT, ALB, ECR or Secrets Manager resources.

## If a first-time EKS node group fails

On 25 September, AWS rejected the first `t3.medium` worker for this Free Plan even though the other resources had been created. The Terraform default was changed to `m7i-flex.large`, an eligible type in this account. Do not reuse an old saved plan after changing worker type or IP. Keep the state and your private variables, make a **fresh plan**, read it, then apply it. If it still fails, inspect `aws eks describe-nodegroup` and the Terraform state before trying again. The [Terraform guide](terraform/README.md) has the basic commands.

## Files to open during the demo

- [Terraform](terraform/README.md): AWS network, EKS, RDS and permissions.
- [Ansible](ansible/README.md): image builds and app deployment.
- [Flask](app/README.md): what the form saves and how its password is loaded.
- [Kubernetes](k8s/README.md): app Pods, Service, Ingress and secret mount.
- [Evidence](evidence/README.md): safe redacted checks.
- [Architecture](docs/architecture.md) and [security controls](docs/security-controls.md): the design and its known limits.
