# Live demo notes

Commands are run from `~/projects/contact-form-aws` in Ubuntu WSL. The AWS profile is `contact-demo` in `us-east-1`. The [main README](../README.md#running-the-current-demo) covers login and the first checks.

The stack was created on 25 September 2026 and checked again on 26 September. The latest check had one Ready worker, two available Flask Pods, Terraform `No changes`, and ALB `/health/ready` HTTP 200. Ansible had also been rerun with `changed=0` before the README changes.

The live stack already exists. A no-change Terraform run will not create a second EKS cluster or RDS database. A new build would need to be planned separately, without deleting the working demo unexpectedly.

## Ten things to show

1. **Terraform on WSL.** Open `terraform/` and run `terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars`. It should say `No changes`. Terraform was applied from WSL to create the stack.
2. **EKS.** Run `aws eks describe-cluster --name contact-demo --query 'cluster.status' --output text` and `kubectl get nodes -o wide`. The cluster is active and the worker has no public IP.
3. **RDS.** Run `aws rds describe-db-instances --db-instance-identifier contact-demo-postgres --query 'DBInstances[0].{status:DBInstanceStatus,public:PubliclyAccessible,encrypted:StorageEncrypted}' --output table`. RDS should be available, private and encrypted.
4. **Secrets Manager.** Run `aws secretsmanager describe-secret --secret-id contact-demo/app-db --query '{name:Name,arn:ARN}' --output json`. For the RDS master secret, use `aws secretsmanager describe-secret --secret-id "$(terraform -chdir=terraform output -raw db_master_secret_arn)" --query '{name:Name,arn:ARN}' --output json`. These show names and ARNs, **not password values**.
5. **Ansible.** Run `ansible-playbook ansible/deploy.yml`. The first run after changing `app/README.md` may rebuild images. A second unchanged run should end with `changed=0` and `failed=0`.
6. **ALB.** Run `kubectl -n contact-form get deployment,service,ingress` and `aws elbv2 describe-load-balancers --query 'LoadBalancers[].[DNSName,State.Code,Scheme]' --output table`. The Ingress points to the public ALB. The AWS controller made it from the Ingress.
7. **Contact form.** Open the Ingress's `http://` address in a browser. Submit a fictional name, email and message. The site does not yet use HTTPS.
8. **Saved row.** Run `./scripts/verify.sh`. It uses a separate read-only database user to show the new test entry in RDS.
9. **Security.** Show the [security notes](security-controls.md) and the [26 September redacted audit](../evidence/security-audit-2026-09-26-redacted.txt). The database is private and encrypted, workers are private, EKS logs are enabled and Flask is non-root. Security Hub was unavailable on the Free Plan; HTTP and other limits are documented rather than hidden.
10. **Cleanup plan.** Check the current Free Plan credit. After the agreed demo window, remove the Ingress/ALB, then use Terraform destroy as shown in the main README.

## Progress

- [x] Initial build, app test, database row check and Ansible repeat on 25 September.
- [x] Scale-down from two workers to one, followed by ALB health HTTP 200.
- [x] Fresh Terraform plan and redacted one-worker security check on 26 September. Credit was reported as USD 133.83 that day; it needs a fresh check before the demo.
- [ ] Interviewer's live demo and submission email.
- [ ] AWS cleanup after the agreed window.
