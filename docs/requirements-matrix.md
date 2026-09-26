# Assignment checklist: what I built and how I proved it

**Checked on 26 September 2026.** The app was deployed and tested on 25 September. On 26 September, I checked again: one worker was Ready, both Flask Pods were available, the ALB returned HTTP 200 and Terraform showed `No changes`. The interviewer's live demo and the final email are still pending.

“Verified” means I have command output or a working test. “Demo limit” means it works as a student demo but does not meet every strict or production interpretation. See [the architecture](architecture.md), [demo steps](demo-checklist.md) and [security notes](security-controls.md).

| Assignment item | What is in the project | Result |
| --- | --- | --- |
| Flask form saves name, email and message | `app/contact_form.py` and `app/templates/contact.html` save into PostgreSQL; local tests passed. A fictional message submitted through the ALB was read back from RDS with `./scripts/verify.sh`. | **Verified** |
| VPC and public/private subnets | `terraform/network.tf` creates public ALB subnets, private EKS app subnets and isolated RDS subnets. | **Verified** |
| EKS cluster and managed worker group | `terraform/platform.tf` created the cluster and workers. One worker is currently Ready, with two healthy Flask Pods. | **Verified** |
| RDS PostgreSQL | `terraform/platform.tf` created a private, encrypted RDS database. The submitted form row was found there. | **Verified** |
| IAM, security groups, ECR and Secrets Manager | Terraform creates separate app/setup/verifier AWS roles, limits network paths, stores images in ECR and creates secret containers. RDS makes its own master secret. | **Verified with exceptions**: deployer still has temporary admin access. |
| AWS ALB | Terraform gives the AWS Load Balancer Controller network and IAM access. Ansible installs it and submits an Ingress; the controller then creates the working ALB. There is **no direct `aws_lb` Terraform resource**. | **Working and automated**; explain this difference if “ALB provisioned by Terraform” is read strictly. |
| Ansible and Kubernetes deployment | `ansible/deploy.yml` builds/pushes the images, installs controllers, sets up the DB and deploys Pods, an internal Service and an ALB Ingress. The Deployment has probes and CPU/memory limits. A repeat run reported `changed=0`. | **Verified** |
| Database passwords | `app/bootstrap/bootstrap.py` generates passwords inside EKS; RDS generates the master password. Secrets Manager keeps them and Flask reads only its own secret through a mounted file. No password is fixed in source, Terraform, Ansible or manifests. | **Verified**; automatic password rotation is still missing. |
| Workload and network security | RDS/workers are private; app runs non-root, has restricted permissions, resource limits and health checks. EKS logs and RDS storage encryption are on. | **Verified with exceptions**: EKS API is public for the operator's `/32`, and the website is HTTP. |
| Foundational Security/CIS controls and findings | `scripts/security-audit.sh`, [security notes](security-controls.md) and two [redacted audits](../evidence/) record manual checks, the audit-query fix and remaining issues. | **Manual checks documented**. Security Hub returned `SubscriptionRequiredException`; no AWS-generated FSBP standard/score. |
| Workstation deployment and live demo | Terraform and Ansible were run from Ubuntu WSL. Terraform later reported `No changes`; end-to-end app/database testing passed. | **Build verified**; the interviewer's live demo and submission email are still to do. |

## Where to find the nine deliverables

| Requested deliverable | Open this in GitHub |
| --- | --- |
| 1. Terraform code | `terraform/` and its provider lock file |
| 2. Ansible | `ansible/deploy.yml` and `ansible/requirements.yml` (one playbook; no separate role folder) |
| 3. Flask source | `app/contact_form.py`, `app/templates/`, `app/tests/` and `app/Dockerfile` |
| 4. Kubernetes/Helm | `k8s/` for manifests; Helm install steps are in `ansible/deploy.yml` |
| 5. Architecture picture | `docs/architecture.md` |
| 6. Complete setup instructions | Main `README.md` plus the short guides in each folder |
| 7. Security hardening | `docs/security-controls.md` |
| 8. Controls and findings | `scripts/security-audit.sh` and redacted files in `evidence/` |
| 9. Git history | https://github.com/WarriorWiras/contact-form-aws; `git log --oneline` shows the commits |

## What I must explain honestly

- **Terraform and ALB:** the AWS Load Balancer Controller creates the ALB from the Ingress, while Terraform provides the network and permissions. This is automated but is not a direct `aws_lb` Terraform resource.
- **Free Plan security limit:** I could not enable Security Hub FSBP. The controls and findings here were checked manually and are **not** an AWS compliance report.
- **Short demo tradeoffs:** public HTTP, EKS API allowed from one operator `/32`, temporary broad deployer permissions, no automatic app-secret rotation, one worker, single NAT and single-AZ RDS. These are recorded in [security notes](security-controls.md).
- **Live meeting:** a no-change Terraform run on the existing stack cannot show brand-new EKS/RDS creation. If the interviewer wants a fresh build, discuss it in advance; do not delete the running demo unexpectedly.

The repository and redacted evidence are ready to share. The reviewer still needs the mandatory live demonstration.
