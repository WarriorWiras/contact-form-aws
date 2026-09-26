# Demo evidence

This folder has two redacted security checks:

- `security-audit-redacted.txt` was taken before reducing the EKS workers from two to one.
- `security-audit-2026-09-26-redacted.txt` was taken afterwards.

The checks show AWS and Kubernetes settings. They are not Security Hub findings. The [security notes](../docs/security-controls.md) explain what passed and what is still open.

A fresh raw check can be collected from the project root:

```bash
mkdir -p evidence/private
chmod 700 evidence/private
./scripts/security-audit.sh > evidence/private/security-audit.txt
chmod 600 evidence/private/security-audit.txt
```

Git ignores `evidence/private/`. Raw output stays there. Before any evidence goes into this public repo, account numbers, ARNs, IP addresses, ALB addresses and personal details need to be removed and checked. No passwords, secret values, Terraform state or real contact messages belong in Git.
