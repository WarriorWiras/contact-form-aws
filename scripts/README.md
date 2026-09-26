# Demo scripts

These scripts run from the project root in Ubuntu WSL. They need the `contact-demo` AWS profile, the local Terraform state and access to EKS.

`./scripts/verify.sh` starts a short-lived Job inside EKS. It uses a database user with read-only access and prints up to five recent form entries. The Job is removed afterwards. The website uses HTTP, so form entries for the demo must be fictional.

`./scripts/security-audit.sh` reads AWS and Kubernetes settings such as EKS logging, RDS encryption, network rules, MFA count, ECR scanning and Pod limits. It does not fetch passwords or enable Security Hub.

Raw audit output should stay in the ignored private folder:

```bash
mkdir -p evidence/private
./scripts/security-audit.sh > evidence/private/security-audit.txt
chmod 600 evidence/private/security-audit.txt
```

The two files already in `evidence/` were redacted before they were committed. A fresh output needs the same review before sharing. Cleanup commands are in the [main README](../README.md#credit-and-cleanup).
