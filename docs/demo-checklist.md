# Live demonstration checklist

- [ ] Confirm AWS account/region, budget alert and no pre-existing demo stack.
- [ ] Run Terraform init/plan/apply locally; show created VPC, EKS and managed nodes.
- [ ] Show private RDS endpoint and Secrets Manager secret **metadata** (never reveal value).
- [ ] Run Ansible locally; show repeatable playbook output and ready Deployment/Service.
- [ ] Show Ingress and ALB healthy targets; open contact form from its DNS name.
- [ ] Submit a sample contact and retrieve the row through a restricted database verification Job.
- [ ] Show EKS/node/RDS network restrictions, Pod Identity, non-root container, logs and actual Security Hub findings.
- [ ] Re-run deployment to show no unexpected changes.
- [ ] After final demo, delete Ingress/ALB, destroy Terraform stack and verify no billable resources remain.
