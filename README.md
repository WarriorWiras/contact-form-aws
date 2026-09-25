# AWS EKS Contact Form — starter repository

This is the **architecture and repository scaffold** for the SIT DevSecOps Engineer Intern assignment. It does not provision AWS resources yet. Add working code in the directories below in the next phases; do not present the scaffold as a deployed system.

## What will run

- Terraform creates the VPC, two public subnets, two private application subnets, two isolated database subnets, EKS and managed nodes, RDS PostgreSQL, ECR, IAM and the required networking. Security Hub CSPM is conditional on the account plan; the assignment also allows relevant CIS-aligned controls.
- Ansible builds and pushes the Flask image, configures the cluster add-ons, and applies the application manifests. AWS Load Balancer Controller creates the internet-facing ALB from the Ingress. Terraform owns the network and IAM that the ALB needs; do not create a second ALB directly in Terraform.
- RDS creates its own master password in Secrets Manager. A repeatable, restricted bootstrap task creates a separate low-privilege PostgreSQL application role and its secret. The Flask Pod uses EKS Pod Identity and the Secrets Store CSI Driver / AWS provider to read **only** the application secret as a mounted file.
- The only planned public application entry is the ALB. Nodes and RDS have no public IPs. EKS API access is restricted to the operator's current public IP during setup.

See [docs/architecture.md](docs/architecture.md) for the diagram, ownership boundaries, and decisions.

## Repository layout

```text
contact-form-aws/
├── README.md
├── .gitignore
├── app/                 # Flask source, templates, dependencies, Dockerfile, tests
├── terraform/           # versions, providers, VPC, EKS, RDS, IAM, ECR, security
│   └── envs/demo/       # non-secret demo values; do not commit real tfvars
├── ansible/             # workstation playbook, inventory, roles, templates
├── k8s/                 # namespace, service accounts, secret provider, deployment,
│                      # service, ingress, restricted database bootstrap Job
├── scripts/             # repeatable validation and teardown helpers
├── docs/
│   ├── architecture.md
│   ├── security-controls.md
│   └── demo-checklist.md
└── evidence/            # redacted findings and screenshots (no credentials)
```

Each implementation directory contains a short placeholder README. The next phase replaces those placeholders with working, validated code.

## Planned end-to-end order

1. If the new AWS signup offers a **Free account plan**, use it to avoid personal charges. Confirm the account plan and available credits. Enable MFA, set billing alerts, then configure a named IAM role/profile on the local workstation. Never use root access keys. If the Free account plan or essential services are unavailable in the signup flow, stop and clarify before selecting a Paid Plan.
2. Install Terraform, AWS CLI, Docker, kubectl, Helm, Python and Ansible. Verify `aws sts get-caller-identity` and region before creating anything.
3. Build and locally test the Flask form and PostgreSQL insert with containers. The app source and unit tests are now included; the database container integration test is still pending.
4. Run `terraform init`, `terraform plan`, `terraform apply`; configure local kubeconfig using `aws eks update-kubeconfig`.
5. Run the Ansible playbook to publish the image and deploy cluster add-ons, bootstrap the app database role, and apply Kubernetes workloads and Ingress.
6. Verify ALB health, submit a sample form, and query the row using a restricted database verification job in the cluster. Document CIS-aligned controls and actual findings; if the account permits Security Hub, also record its findings and remediation evidence.
7. Re-run `terraform plan` and Ansible to show repeatability. For live-demo provisioning, destroy the practice environment beforehand and confirm budget and service quotas. After final demo, remove Kubernetes Ingress and its ALB before `terraform destroy`, then verify resources are gone.

## Costs and limitations

The complete assignment **consumes AWS credits or billable capacity**: EKS cluster hours, EC2 worker instances and storage, NAT gateway, ALB, RDS, logs, data transfer and Secrets Manager. AWS lists EKS in the new signup Free account plan, but Security Hub in the Paid Plan. The brief permits relevant CIS-aligned controls as an alternative. If the recruiter requires Security Hub despite that wording, obtain written clarification before upgrading. A Free account plan is intended not to bill for usage, but the account closes when credits run out or its Free Plan period ends, so the demo may fail if credits are depleted. A Paid Plan can bill beyond credits; budget alerts are not a hard cap. Check actual plan, service availability and balance before deploying, deploy close to the demo, and delete afterward.

Scaling managed worker nodes to zero between tests saves worker compute, but **does not pause** the EKS control plane, RDS, NAT gateway, ALB, or their applicable charges. With no nodes, the contact form has no running Flask Pods/ALB controller and the ALB will not serve a healthy application. Ask whether the recruiter expects the form to remain available continuously through Tuesday 29 September 2026 at 2 pm (Singapore time), or only to be available at that time. Never promise zero out-of-pocket cost on a Paid Plan solely because promotional credits exist.

HTTPS requires a domain you control and an ACM certificate (or an approved alternative). An ALB's autogenerated AWS DNS name alone is not a substitute for a certificate for your custom domain. If no domain is available, document temporary HTTP as an explicit demo exception and avoid real personal contact information.

## Status

Architecture approved: **pending**. Flask app implemented with four passing local application tests; connection to a live PostgreSQL database still pending. Terraform, Ansible, live deployment, control findings and demo evidence: **pending**. Do not fill findings with guessed results.
