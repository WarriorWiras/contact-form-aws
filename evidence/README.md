# Evidence: proof from the live demo

This folder holds **redacted** records of what I checked in AWS and Kubernetes:

| File | What it shows |
| --- | --- |
| `security-audit-redacted.txt` | First security check, before the worker count was reduced. It shows two requested workers. |
| `security-audit-2026-09-26-redacted.txt` | Later security check, with one requested worker. |

These are my **manual checks**, not Security Hub findings or a CIS certificate. [The security page](../docs/security-controls.md) explains what passed and which limits remain.

To take a fresh check from the main project folder:

```bash
mkdir -p evidence/private
chmod 700 evidence/private
./scripts/security-audit.sh > evidence/private/security-audit.txt
chmod 600 evidence/private/security-audit.txt
```

The `private/` folder is ignored by Git. Before sharing any copy, remove account numbers, ARNs, IP addresses, ALB addresses and personal details; check the result carefully. **Never commit the raw file, a password, a secret value, a real contact submission or Terraform state.** Only put a reviewed, redacted copy in this public folder.
