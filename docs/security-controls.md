# Security: what I checked and what is still limited

**These are my own checks from 25–26 September 2026.** I used the AWS CLI, kubectl and [the audit script](../scripts/security-audit.sh). They are **not** AWS Security Hub findings or proof that I passed a full CIS benchmark. The links to AWS control IDs below show which published controls I compared against.

The first attempt at an EKS endpoint check printed `null` because my audit script used the wrong AWS response field. I fixed it to use `resourcesVpcConfig`, checked the actual endpoint settings again, and reran the audit. That is the **finding I fixed** in the audit code.

The 26 September check showed one Ready worker, two available Flask Pods, Terraform `No changes` and ALB `/health/ready` HTTP 200. Running Ansible a second time on 25 September gave `changed=0` and `failed=0`.

## What is already protected

| Area | What I observed | What I would say in the demo |
| --- | --- | --- |
| Private database ([RDS.2, RDS.3, RDS.11](https://docs.aws.amazon.com/securityhub/latest/userguide/rds-controls.html)) | `PubliclyAccessible=false`, `StorageEncrypted=true`; the DB subnets have only a route inside the VPC. Its security group permits port 5432 **only** from the EKS worker security group. | “A visitor cannot connect directly to the database. It is private and encrypted at rest.” |
| EKS logging ([EKS.8](https://docs.aws.amazon.com/securityhub/latest/userguide/eks-controls.html)) | All five control-plane log types are on: API, audit, authenticator, controller manager and scheduler. CloudWatch keeps them for seven days. | “I enabled control-plane logs so EKS actions can be investigated.” |
| Database passwords | RDS generated the master password into Secrets Manager. The app and read-only verifier have separate secrets. The app reads its own secret through Pod Identity and a CSI-mounted file. | “Passwords are not written into Terraform variables, the app source or the Kubernetes manifests.” |
| Kubernetes app permissions | The app service account cannot list Kubernetes Secrets (`kubectl auth can-i` returned `no`). Its AWS role is limited to reading the **app** secret. | “Flask only gets the access it needs for this demo.” |
| Flask container | It runs as user `10001`, has a read-only root filesystem, drops extra capabilities, cannot gain privileges and uses the default seccomp protection. Namespace policy is `restricted`. Each Pod requests 75m CPU/96Mi RAM and has a 300m CPU/256Mi RAM limit; it has live and ready checks. | “The app is non-root and has limits and health checks.” |
| Image storage | ECR uses AES256 storage encryption and is configured to scan images on push. | “Scanning is turned on; I have **not** reviewed a vulnerability report.” |
| IAM sign-in ([IAM.5](https://docs.aws.amazon.com/securityhub/latest/userguide/iam-controls.html)) | The non-root deployment user has one MFA device. Root MFA was set up earlier but was not rechecked by this audit. | “I used the IAM deployment user with MFA, not the root account.” |

The app asks RDS for a TLS connection with `sslmode=require`. That gives encryption in transit; this demo does not configure a stricter `verify-full` certificate/hostname check.

## Findings and open demo limits

These are **my manual observations**, not findings produced by Security Hub:

| Finding | Current situation | What a longer-lived system would need |
| --- | --- | --- |
| EKS API is reachable from the internet ([EKS.1](https://docs.aws.amazon.com/securityhub/latest/userguide/eks-controls.html)) | Private access is on, but public access is also on for **one operator IP `/32`** so I can deploy from WSL. No worker has a public IP. | Use only the private endpoint or a private connection for admins. |
| Website is HTTP ([ELB.1](https://docs.aws.amazon.com/securityhub/latest/userguide/elb-controls.html)) | The ALB accepts port 80 from visitors. It sends traffic to the app on port 8000. Browser traffic is **not encrypted**, so only fictional form entries are safe for this demo. | Add a domain, an ACM certificate, HTTPS and an HTTP-to-HTTPS redirect before real use. |
| Application passwords do not rotate automatically ([SecretsManager.1](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-controls-reference.html)) | Secret versions exist, but `RotationEnabled` was not on for the app and verifier users. | Rotate the database password and matching Secrets Manager version together. |
| Temporary broad setup permissions | The deployer IAM group has `AdministratorAccess` for setup and teardown. The Flask app's role is much narrower. | Replace the deployer's broad access with task-specific permissions after the demo. |
| Limited fault tolerance | One `m7i-flex.large` EKS worker currently runs both Flask Pods; NAT and RDS each use a single Availability Zone. | Add workers and multi-AZ network/database resources if uptime matters. |
| Short retention and demo deletion | RDS backup retention is one day, deletion protection is off and no final snapshot is taken at destroy. EKS logs stay seven days. | Increase retention and keep protected backups for real data. |

## Why there is no Security Hub score

I ran a **read-only** `aws securityhub describe-hub` check. AWS returned `SubscriptionRequiredException` for this Free Plan account. I did **not** enable the AWS Foundational Security Best Practices standard and I have **no AWS-generated FSBP/CIS score or findings**. AWS's [new account service list](https://docs.aws.amazon.com/accounts/latest/reference/supported-services-sign-up-new.html) explains plan limits. I did not upgrade the account to claim a security badge.

The AWS control IDs linked above are only a guide for my **manual comparison**. My EKS logging, network restrictions, IAM MFA, RDS encryption, ECR scanning and Pod protections were configured and checked, but the open issues in the table still matter.

## Where the proof is

- [First redacted audit](../evidence/security-audit-redacted.txt): captured before reducing workers; requested worker count was two.
- [26 September redacted audit](../evidence/security-audit-2026-09-26-redacted.txt): captured afterwards; requested worker count is one. Basic checks for exposed account IDs, ARNs, ALB names and the operator `/32` passed before commit.
- Raw output belongs only in ignored `evidence/private/security-audit.txt`. Do **not** print or publish passwords, Terraform state or real contact information.
- The Free Plan CLI reported **ACTIVE** and **USD 133.83 remaining** on 26 September. That number is a dated snapshot, not a prediction of how long the AWS resources can run. Check it again and destroy the demo resources after the agreed window.
