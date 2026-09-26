# Assignment checklist

The stack was built from Ubuntu WSL on 25 September 2026. A form entry went through the ALB and was read back from RDS. On 26 September, Terraform showed `No changes`, one EKS worker was Ready, two Flask Pods were available and the ALB health check returned HTTP 200.

| Requirement | Where it is / what happened |
| --- | --- |
| Flask form and PostgreSQL storage | `app/contact_form.py`, `app/templates/contact.html` and `app/schema.sql`. A fictional entry was saved and read back with `./scripts/verify.sh`. |
| VPC, public/private subnets and security groups | `terraform/network.tf`. ALB is public; EKS workers are private; RDS has no internet route. RDS accepts database traffic from the worker group only. |
| EKS cluster and managed workers | `terraform/platform.tf`. The node group was first run with two workers, then reduced to one. |
| RDS PostgreSQL | `terraform/platform.tf`. RDS is private and encrypted; the app saved a test row there. |
| IAM, ECR, Secrets Manager and other AWS resources | `terraform/platform.tf` and `terraform/permissions.tf`. The app, database setup and verifier have separate AWS roles. |
| ALB | Ansible installs the AWS Load Balancer Controller and applies `k8s/application.yaml.j2`. The controller creates the ALB from the Ingress. Terraform supplies its network and IAM access, but does **not** directly declare an `aws_lb` resource. |
| Ansible and Kubernetes deployment | `ansible/deploy.yml` deploys two Flask Pods, an internal Service and Ingress. The Pods have health checks and resource limits. A repeat playbook run had `changed=0`. |
| Database passwords | RDS generates the master password. `app/bootstrap/bootstrap.py` generates the app and verifier passwords and stores them in Secrets Manager. Flask mounts only its own secret. No password is fixed in Terraform, Ansible, manifests or Flask source. |
| Security hardening | Workers and RDS are private; Flask is non-root, has limits and cannot list Kubernetes Secrets. EKS logging and RDS encryption are on. [Security notes](security-controls.md) record the checks and limits. |
| Foundational Security / CIS | [The audit script](../scripts/security-audit.sh) and [redacted evidence](../evidence/) show manual checks and findings. Security Hub returned `SubscriptionRequiredException` on the Free Plan, so there is no AWS-generated FSBP report. |
| Workstation deployment and live demo | Terraform and Ansible ran from Ubuntu WSL. The build and end-to-end test passed. The interviewer's live demo is still pending. |

## Files to submit

1. Terraform: `terraform/`
2. Ansible: `ansible/deploy.yml` and `ansible/requirements.yml`
3. Flask: `app/`
4. Kubernetes manifests and Helm steps: `k8s/` and `ansible/deploy.yml`
5. Architecture diagram: `docs/architecture.md`
6. Setup instructions: this repository's `README.md` and the folder READMEs
7. Security hardening: `docs/security-controls.md`
8. Control checks and findings: `scripts/security-audit.sh` and the redacted `evidence/` files
9. Git history: https://github.com/WarriorWiras/contact-form-aws

## Points to be clear about

The ALB is automated but created by the Kubernetes controller, not directly by Terraform. Security Hub was unavailable, so the checks are manual. The public form is HTTP, the EKS API allows one operator IP, the deployment IAM user still has broad setup access, and the app passwords do not rotate automatically. One worker, single NAT and single-AZ RDS keep this a small demo rather than a highly available production setup.

[Live demo notes](demo-checklist.md) cover the ten items the assignment asks to see. The submission email and interviewer's live demo remain to be completed.
