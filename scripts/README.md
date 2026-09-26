# Small demo scripts

Run these from the **main project folder** in Ubuntu WSL after signing into the `contact-demo` AWS profile. They use your local Terraform state and access to the existing EKS cluster.

## Show that a form entry reached RDS

First submit a **made-up** name, email and message in the ALB website. Then run:

```bash
./scripts/verify.sh
```

The script briefly creates a Job **inside EKS**, uses a database user with **read-only** access, prints up to five recent rows and removes that Job. It cannot change or delete stored messages. Do not use real personal data in the HTTP demo or share rows containing private details.

## Check security settings

```bash
mkdir -p evidence/private
./scripts/security-audit.sh > evidence/private/security-audit.txt
chmod 600 evidence/private/security-audit.txt
```

This script reads settings such as the EKS API access, logging, private/encrypted RDS, security groups, secret **names** (not values), ECR image checks, MFA count and Flask Pod security. It does not turn Security Hub on or fetch passwords. The result is a **manual audit**, so read it and remove identifiers before putting a copy in Git. The raw file stays in the ignored `evidence/private/` folder.

For the command to remove the AWS stack **after** the demo, see the [main guide](../README.md#credits-pause-and-cleanup).
