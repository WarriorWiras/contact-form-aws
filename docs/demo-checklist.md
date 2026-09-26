# Live demo: what to run and what to say

All commands below are run in **Ubuntu WSL from `~/projects/contact-form-aws`**, with `AWS_PROFILE=contact-demo` and `AWS_DEFAULT_REGION=us-east-1`. Open the [main guide](../README.md#start-a-wsl-session-for-the-existing-deployment) if your AWS login has expired. The website currently uses HTTP: submit **fictional** details only.

## Already tested before the meeting

- [x] On 25 September 2026, Flask tests passed. Terraform created the AWS network, EKS and RDS; Ansible deployed the app. A form entry reached the database and `./scripts/verify.sh` showed it.
- [x] Ansible was rerun with `changed=0` and `failed=0`. The Terraform plan showed `No changes`.
- [x] I reduced EKS workers from two to **one** using Terraform. The old worker left, two Flask Pods remained ready and the ALB still returned HTTP 200.
- [x] On 26 September, Free Plan was `ACTIVE`; the reported remaining credit was USD 133.83. A fresh Terraform plan showed `No changes`, one worker was Ready, the Deployment was 2/2, and ALB `/health/ready` returned HTTP 200. This is a dated snapshot, not a future credit estimate.
- [x] The first [redacted audit](../evidence/security-audit-redacted.txt) shows two requested workers; the [new redacted audit](../evidence/security-audit-2026-09-26-redacted.txt) shows one. The new file passed basic checks for exposed account IDs, ARNs, ALB addresses and the operator IP.

## During the live demo

Use this order. Pause after each step to explain the result. **The stack already exists:** a no-change Terraform plan or apply will not recreate EKS and RDS. Arrange a fresh rebuild with the interviewer ahead of time if they require one; do not destroy the working demo to improvise.

Before the meeting, rerun Ansible once after committing the rewritten `app/README.md`. The current image tag includes that file, so this first run may rebuild images and run another database setup Job. Check readiness and rerun Ansible a second time to show `changed=0`.

1. **Terraform from the laptop:** show `terraform/` and run `terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars`. Say: “Terraform made the AWS base, and `No changes` means it still matches my code.” The original `terraform apply` created it on 25 September.
2. **EKS cluster and workers:** run `aws eks describe-cluster --name contact-demo --query 'cluster.status' --output text` and `kubectl get nodes -o wide`. Say: “The cluster is active. The worker has no public IP.”
3. **RDS PostgreSQL:** run `aws rds describe-db-instances --db-instance-identifier contact-demo-postgres --query 'DBInstances[0].{status:DBInstanceStatus,public:PubliclyAccessible,encrypted:StorageEncrypted}' --output table`. Show `available`, `False` for public and `True` for encrypted.
4. **Database secrets:** run `aws secretsmanager describe-secret --secret-id contact-demo/app-db --query '{name:Name,arn:ARN}' --output json`. For the master secret, run `aws secretsmanager describe-secret --secret-id "$(terraform -chdir=terraform output -raw db_master_secret_arn)" --query '{name:Name,arn:ARN}' --output json`. Say: “RDS made the master password; the app uses another restricted password.” **Never run `get-secret-value` on screen.**
5. **Ansible deployment:** run `ansible-playbook ansible/deploy.yml` and `kubectl -n contact-form get deployment,service,ingress,pods`. Say: “This publishes the app and can be repeated. The Service is internal, while the Ingress tells AWS to make the ALB.” A finished `db-bootstrap` Job is normal.
6. **ALB:** show the Ingress `ADDRESS` or run `aws elbv2 describe-load-balancers --query 'LoadBalancers[].[DNSName,State.Code,Scheme]' --output table`. Say: “The ALB was made automatically by the AWS Load Balancer Controller from the Ingress.” Terraform supplies its network and IAM settings.
7. **Open the form:** copy the Ingress's `http://` address into a browser. Show the three fields and submit **made-up** name, email and message.
8. **Show it in RDS:** run `./scripts/verify.sh`. It briefly creates a read-only Job in EKS and prints recent rows. Find the fictional entry you just submitted.
9. **Security checks:** open [security controls](security-controls.md) and the [redacted audit](../evidence/security-audit-2026-09-26-redacted.txt). Show private/encrypted RDS, limited security-group access, EKS logs, MFA, non-root Pods and resource limits. Explain the documented HTTP/EKS API/deployer/rotation limits and the Free Plan's Security Hub `SubscriptionRequiredException`. Do **not** say AWS issued a Security Hub compliance score.
10. **Finish:** check the Free Plan balance. Tell the reviewer that after the agreed demo window you will remove the Ingress/ALB and destroy the AWS stack, following the main README.

## Still to do

- [ ] Conduct the interviewer's live end-to-end demonstration.
- [ ] Send the Git repository and documents by the assignment deadline.
- [ ] After the agreed availability window, delete the ALB through its Ingress, run Terraform destroy and check for leftover billable AWS resources.
