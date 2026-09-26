# Assignment requirements and evidence

**Review date:** 26 September 2026. This review uses the committed source and the 25 September workstation/AWS command results recorded in the repository and demo notes. It is not a new live inspection of the AWS account; repeat the checks before the demo. See [the demo checklist](demo-checklist.md) and [security observations](security-controls.md).

| Requested item | Implementation and evidence | Status |
| --- | --- | --- |
| Flask contact form: name, email, message stored in PostgreSQL | `app/contact_form.py`, `app/templates/contact.html`, `app/schema.sql`; unit tests passed; ALB POST returned HTTP 303 and `./scripts/verify.sh` read the sample row from RDS. | Verified 25 Sep |
| VPC, public/private subnets, private workloads and database | `terraform/network.tf` provisions two public ALB subnets, two private app subnets and two isolated DB subnets. RDS has no public endpoint and no internet route; DB SG allows TCP 5432 from the worker SG. EKS workers had no public IPs. | Verified 25 Sep |
| EKS cluster, managed node group, RDS PostgreSQL, IAM, security groups, Secrets Manager and support resources through Terraform | `terraform/platform.tf`, `network.tf`, `permissions.tf`; `terraform apply` completed, then a no-change plan was observed before the documented worker scale-down. Current plan should be rerun with the same private `demo.tfvars`. | Verified 25 Sep; refresh plan for demo |
| ALB provisioned by automation | Terraform creates the ALB security group, subnet tags and Pod Identity/IAM for the controller. `ansible/deploy.yml` installs the controller and applies `k8s/application.yaml.j2` Ingress. The controller creates the ALB, listeners and targets. ALB was active and `/health/ready` returned HTTP 200. There is **no `aws_lb` Terraform resource**; explain this cloud-native ownership during the demo. | Automated and verified; **Terraform-alone ALB wording is a strict-reading gap** |
| Ansible deploys Deployment, Service, Ingress and configuration | `ansible/deploy.yml` builds/pushes ECR images, installs controller/CSI Helm charts, applies namespace/service accounts, runs DB bootstrap and creates Deployment, ClusterIP Service and Ingress. `k8s/application.yaml.j2` sets DB host/name, probes and CPU/memory bounds. The repeat playbook run reported `changed=0, failed=0`. | Verified 25 Sep |
| No fixed DB passwords in code, Terraform, Ansible or manifests; retrieval via Secrets Manager | RDS generates its master password into Secrets Manager. `app/bootstrap/bootstrap.py` generates per-role passwords inside EKS and writes Secrets Manager secret versions; `terraform/platform.tf` holds only secret metadata. `terraform/permissions.tf` scopes Pod Identity. CSI mounts the app secret file in the Flask Pod (`k8s/application.yaml.j2`, `app/contact_form.py`). Credentials were not printed in evidence. | Verified architecture and deployment 25 Sep; rotation outstanding |
| IAM least privilege and Kubernetes RBAC | Dedicated app Pod Identity role can read only its own secret ARN; bootstrap and verifier have separate policies. The app service account has no Kubernetes Role/RoleBinding and `kubectl auth can-i list secrets` returned `no`. | Workload permissions verified; **temporary deployer AdministratorAccess remains an exception** |
| Pod hardening, logging and encryption | Namespace enforces `restricted`; Flask runs as UID/GID 10001, drops capabilities, forbids privilege escalation, uses read-only root and RuntimeDefault seccomp; two replicas have probes and requests/limits. EKS enables all five control-plane log types, retention seven days. RDS encrypts storage, ECR encrypts images and scans on push. See `docs/security-controls.md` and dated `evidence/security-audit-redacted.txt`. | Verified 25 Sep |
| Only ALB reachable publicly; HTTPS/TLS where practical | ALB uses public port 80; RDS is private, Service is ClusterIP and worker nodes have no public IPs. EKS API also has a **public endpoint restricted to the operator /32** for workstation access; RDS client defaults to `sslmode=require`. | Public-facing app only via ALB, but **HTTP and public allowlisted EKS API are documented exceptions** |
| AWS Foundational Security / CIS controls and findings | `scripts/security-audit.sh`, `docs/security-controls.md` and redacted audit evidence document actual configured safeguards, manual observations, an audit-query fix and outstanding exceptions. Read-only `securityhub describe-hub` returned `SubscriptionRequiredException` for this Free Plan account. | Manual control comparison verified; **AWS Security Hub FSBP standard and automated findings were not enabled** |
| One-week deadline, Git deliverables and live demonstration | Published GitHub repository contains Terraform, Ansible, Flask, K8s/Helm config, Mermaid architecture, complete README, security document and clean commits. `docs/demo-checklist.md` covers the 10 live steps. | Repository published; live demo and deadline submission still pending |

## What the reviewer should see in the demo

1. On the local Ubuntu WSL workstation, run `terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars` and show the Terraform code and original provisioning evidence. The infrastructure already exists: a no-change plan/apply **does not recreate** EKS or RDS. Do not destroy a working demo just to show a new creation event.
2. Show EKS one Ready private worker, RDS `PubliclyAccessible=false`/encryption, and **metadata only** for the RDS master secret and app secret. Keep the secret string and local Terraform state off screen.
3. Run Ansible again and show its repeatable result, app Pods/Service/Ingress and ALB hostname/health. The ALB is reconciled from the Ingress by the controller.
4. Submit a **fictional** contact form record and run the read-only verifier to show the new database row. Show the security audit and documented exceptions, including Security Hub access status, without claiming a Security Hub score.
5. Confirm remaining credits before leaving resources running. After the agreed demo window, delete the Ingress and confirm ALB removal **before** Terraform destroy, as in the README.

## Deliverable paths

| Deliverable | Where |
| --- | --- |
| Terraform code | `terraform/`, including `terraform/.terraform.lock.hcl` |
| Ansible playbook | `ansible/deploy.yml` and `ansible/requirements.yml` (one playbook; no separate roles are needed) |
| Flask app and tests | `app/contact_form.py`, `app/templates/`, `app/tests/`, `app/Dockerfile` |
| Kubernetes and Helm setup | `k8s/` and Helm installation tasks in `ansible/deploy.yml` |
| Architecture diagram | `docs/architecture.md` (Mermaid) |
| Deployment/teardown instructions | `README.md`, `terraform/README.md`, `ansible/README.md` |
| Hardening, controls, findings and redacted evidence | `docs/security-controls.md`, `scripts/security-audit.sh`, `evidence/security-audit-redacted.txt` (snapshot before worker scale-down) |
| Git repository | https://github.com/WarriorWiras/contact-form-aws |

The status labels report only the checks actually completed. A one-worker EKS node group, single NAT gateway, single-AZ RDS, short log/backup retention, no automated secret rotation, HTTP listener and broad temporary deployer IAM privileges are recorded demo tradeoffs; they are not claims of production readiness.
