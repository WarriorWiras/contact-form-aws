# Live demonstration checklist

- [x] Local Flask tests, Docker image build, readiness and sample PostgreSQL row passed on 25 September 2026.
- [x] Confirmed `FREE`/`ACTIVE` account with USD 120 credit remaining on 25 September via `get-account-plan-state`; region and non-root IAM deployer checked. Recheck credit daily and confirm alerts in AWS.
- [x] From WSL run Terraform fmt/init/validate/plan; apply completed after replacing the failed Free Plan-ineligible worker type. Confirm remaining credits before the live demo.
- [x] Show private application nodes and RDS without public access; isolated database subnet route table has only VPC local route, and DB SG admits 5432 only from worker SG.
- [x] Show RDS managed master secret and app secret metadata only; never show a password.
- [x] Run Ansible from WSL; show successful bootstrap Job and Flask rollout, ClusterIP Service and Ingress.
- [x] Show ALB hostname and healthy readiness; submit only fictional contact information.
- [x] Run `./scripts/verify.sh` to show the row via the separate SELECT-only verifier role.
- [x] Re-run corrected `./scripts/security-audit.sh`; manually verified EKS logs/retention, ECR scanning/encryption, Pod security bounds/probes and database isolation. Security Hub read-only API returned `SubscriptionRequiredException`; documented in `docs/security-controls.md`.
- [x] Re-ran Ansible (`changed=0`, `failed=0`) and Terraform plan (`No changes`).
- [ ] Keep demo available through the recruiter-requested time if credits permit; scaling workers to zero disables service but other AWS costs continue.
- [ ] After the final demo remove the Ingress while nodes run, confirm ALB deletion, run Terraform destroy and verify billable resources are gone.
