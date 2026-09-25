# Live demonstration checklist

- [x] Local Flask tests, Docker image build, readiness and sample PostgreSQL row passed on 25 September 2026.
- [ ] Confirm remaining Free Plan credit, alerts, region and credentials as the IAM deployer, not root.
- [ ] From WSL run Terraform fmt/init/validate/plan and review costs; apply when the balance supports it.
- [ ] Show VPC private application subnets and isolated database subnets, EKS managed nodes and RDS private endpoint.
- [ ] Show RDS managed master secret and app secret metadata only; never show a password.
- [ ] Run Ansible from WSL; show successful bootstrap Job and Flask rollout, ClusterIP Service and Ingress.
- [ ] Show ALB hostname and healthy targets; access form and submit only fictional contact information.
- [ ] Run `./scripts/verify.sh` to show the row via the separate SELECT-only verifier role.
- [ ] Run `./scripts/security-audit.sh`; log real results, remediations and HTTP/availability exceptions in `docs/security-controls.md`.
- [ ] Re-run Ansible and Terraform plan to demonstrate repeatability and drift status.
- [ ] Keep demo available through the recruiter-requested time if credits permit; scaling workers to zero disables service but other AWS costs continue.
- [ ] After the final demo remove the Ingress while nodes run, confirm ALB deletion, run Terraform destroy and verify billable resources are gone.
