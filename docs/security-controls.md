# Security notes

These notes come from checks made on 25 and 26 September 2026 with AWS CLI, kubectl and [the audit script](../scripts/security-audit.sh). They are manual checks, not a Security Hub report or proof of full CIS compliance.

## What was checked

| Area | Result |
| --- | --- |
| EKS API ([EKS.1](https://docs.aws.amazon.com/securityhub/latest/userguide/eks-controls.html)) | Private access is on. Public access is also on, but restricted to one operator IP `/32` for deployment from WSL. Workers have no public IP. |
| EKS logs ([EKS.8](https://docs.aws.amazon.com/securityhub/latest/userguide/eks-controls.html)) | API, audit, authenticator, controller manager and scheduler logs are enabled. CloudWatch keeps them for seven days. |
| RDS ([RDS.2, RDS.3, RDS.11](https://docs.aws.amazon.com/securityhub/latest/userguide/rds-controls.html)) | `PubliclyAccessible=false`, `StorageEncrypted=true`. The DB subnets have no internet route. Its security group allows port 5432 only from the EKS worker group. Backups are kept for one day. |
| Database secrets ([SecretsManager.1](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-controls-reference.html)) | RDS has a managed master secret. Separate app and read-only verifier secrets exist. Their passwords were never included in the audit output. Automatic rotation is not enabled. |
| ALB ([ELB.1](https://docs.aws.amazon.com/securityhub/latest/userguide/elb-controls.html)) | The ALB is public on port 80 and passes traffic to Flask on port 8000. The app's Kubernetes Service is internal (`ClusterIP`). Public browser traffic is HTTP. |
| IAM ([IAM.5](https://docs.aws.amazon.com/securityhub/latest/userguide/iam-controls.html)) | The non-root deployment user has an MFA device. The app's AWS role can read only its own secret. The setup user's group still has temporary `AdministratorAccess`. |
| Flask Pods | The namespace enforces restricted Pod rules. Flask runs as user `10001`, with no privilege escalation or extra capabilities, a read-only root filesystem, seccomp, CPU/memory limits, and live/ready checks. Its service account cannot list Kubernetes Secrets. |
| Container images | ECR encryption is AES256 and scan-on-push is on. Image scan results themselves were not reviewed. |

Both Flask Pods were ready on one worker after the scale-down. The ALB health check returned HTTP 200. RDS connections ask for TLS with `sslmode=require`; this is not the stricter `verify-full` certificate and hostname check.

## Findings

The first EKS endpoint check showed `null` because `scripts/security-audit.sh` used the wrong response field. That was **fixed** to read `resourcesVpcConfig`. A separate AWS check confirmed private access on and public access limited to the operator's `/32`. A later redacted audit used the corrected script.

The following points are **still open for this demo**:

- The website uses HTTP. A domain and ACM certificate are needed for HTTPS and an HTTP-to-HTTPS redirect before real submissions.
- The EKS API has a public endpoint for the operator's `/32`. A long-term setup would use private admin access.
- The app and verifier passwords have no automatic rotation.
- The deployment user has broad temporary IAM access. The app itself has a narrower role.
- One EKS worker holds both Flask Pods. One NAT gateway and single-AZ RDS also leave single points of failure.
- RDS keeps one day of backups; deletion protection and a final snapshot are off. EKS logs stay seven days. These are short-demo settings.

No real contact information was submitted. The verifier used a separate PostgreSQL user with read-only access to show that a fictional message reached RDS.

## Security Hub on the Free Plan

`aws securityhub describe-hub` returned `SubscriptionRequiredException`. I did not enable AWS Foundational Security Best Practices or get AWS-generated FSBP/CIS findings. The control IDs in the table are links used for **manual comparison**. AWS's [new-account service list](https://docs.aws.amazon.com/accounts/latest/reference/supported-services-sign-up-new.html) also describes plan limits. The account was not upgraded to make this demo look compliant.

## Evidence kept in Git

- [First redacted audit](../evidence/security-audit-redacted.txt): before scale-down, desired workers two.
- [26 September redacted audit](../evidence/security-audit-2026-09-26-redacted.txt): after scale-down, desired workers one.

Basic checks for exposed account IDs, ARNs, ALB hostnames and the operator `/32` passed on the newer file before it was committed. Raw audit output stays in the ignored `evidence/private/` folder.

The Free Plan CLI reported `ACTIVE` and USD 133.83 remaining on 26 September. That was only the balance shown at that time. It needs another check while the AWS stack is running.
