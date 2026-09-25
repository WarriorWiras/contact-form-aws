# Security controls and findings log

Status: **planned; no AWS environment deployed or findings observed yet**.

| Control / requirement | Planned implementation | Actual result and evidence | Remediation / exception |
| --- | --- | --- | --- |
| CIS-aligned checks for network, IAM, encryption, logging | Implement in Terraform; collect actual configuration and findings after deployment | Pending | Pending |
| Security Hub CSPM AWS Foundational Security Best Practices | Conditional: requires access to Security Hub in chosen account plan | Pending or unavailable on Free account plan | Document exception if unavailable |
| Restricted network exposure | Public ALB only; private nodes and RDS; allowlisted EKS API | Pending | Pending |
| Secrets and least privilege | RDS-managed master, separate app role and secret, Pod Identity | Pending | Pending |
| Encryption and logging | RDS storage encryption, EKS control-plane logging, encrypted AWS secrets | Pending | Pending |
| Kubernetes workload hardening | Non-root, restricted RBAC, probes, resource limits | Pending | Pending |
| HTTPS | ACM certificate and HTTPS listener if domain supplied | Pending | HTTP demo exception if no domain |

After provisioning, export and redact actual findings by standard/control ID, resource, severity, first-seen date, remediation, and recheck result. Do not mark controls passed before Security Hub evaluations complete. Keep evidence out of Git if it contains account identifiers or contact submissions.
