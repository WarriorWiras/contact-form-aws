# Security controls and actual findings

**Status:** Infrastructure has not yet been provisioned. Implementation is written; every *observed result* below is pending. Fill in the observed column from a live deployment and save redacted evidence under `evidence/`. Run `./scripts/security-audit.sh` and check the AWS console/API after Ansible deploys. Do not present implementation intent as an AWS finding.

| Control / CIS alignment | Implemented configuration | Observed result / evidence | Remediation or exception |
| --- | --- | --- | --- |
| Network exposure and EKS endpoint | ALB HTTP 80 publicly accessible; EKS API public CIDR restricted to operator `/32`, private endpoint enabled; nodes/private RDS without public IP | Pending live `describe-cluster`, RDS and security group checks | Public HTTP is a demo exception until a controlled domain and ACM certificate are available |
| Database security | RDS storage encrypted, one-day backup retention, isolated DB subnets and SG 5432 only from worker SG | Pending live RDS/route table checks | One-day retention and no final snapshot suit disposable demo; increase for real data |
| IAM and credentials | Pod Identity grants app read on app secret ARN only; bootstrap reads RDS master secret and initializes two restricted secrets; verifier reads its own secret | Pending IAM association, policy and secret metadata checks | IAM deployer has broad temporary provisioning rights; review MFA; narrow access for production |
| Database access | App role has INSERT on `contact_messages`; verifier role has SELECT; master is RDS managed | Pending successful restricted verification Job | Rotation of app/verifier credentials is manual; document if remains |
| Kubernetes protection | Namespace `restricted` Pod Security Admission, non-root Pods, read-only rootfs, seccomp, dropped capabilities, service accounts without Kubernetes RoleBindings, CPU/memory limits, probes | Pending live manifest and `kubectl auth can-i` checks | CSI driver/controller have cluster permissions needed for their function |
| Monitoring | EKS audit/API/authenticator/controller/scheduler logs, 7-day CloudWatch retention, ECR scan on push | Pending `describe-cluster` and ECR check | Monitoring beyond the assignment is not configured |
| AWS Foundational Security Best Practices / CIS | CIS-aligned configuration checks via `scripts/security-audit.sh`; enable Security Hub CSPM controls only if account plan supports them | Pending; do not claim Security Hub enabled | On Free Plan, record if Security Hub CSPM is unavailable; assignment allows CIS-aligned controls |
| TLS | TLS required for PostgreSQL connections; public ALB HTTP only until a domain/certificate can be used | Pending live checks | Never enter real personal data over HTTP; add ACM + HTTPS for production |
| Availability | Two private worker nodes across two AZs; one NAT and single-AZ RDS | Pending placement check | Single NAT and single-AZ RDS are budget choices for this temporary demo |

## Findings log (complete after deployment)

| Time (UTC) | Source and check ID | Resource | Observed finding | Severity | Fix or explicit exception | Recheck/evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Pending | Pending | Pending | Pending | Pending | Pending | Pending |

If Security Hub is unavailable on the Free Plan, record the actual console/API result here; do not upgrade the account merely to make the checker work. For a live control, capture its exact ID, timestamp and current state. Screenshots must hide contact submissions, credentials and account identifiers.
