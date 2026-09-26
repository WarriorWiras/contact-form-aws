# Terraform setup

Terraform creates the AWS side of the project: VPC and subnets, EKS and its workers, private PostgreSQL RDS, IAM roles, ECR, logs and Secrets Manager secret containers. The actual ALB is made later by the AWS Load Balancer Controller from the Ingress that Ansible deploys.

The database has no public address. EKS workers are in private subnets, and RDS is in subnets with no route to the internet. Public access goes to the ALB. The EKS API is also reachable from one allowed operator IP (`/32`) so the laptop can deploy.

On a first build, `envs/demo/demo.tfvars.example` is copied to `envs/demo/demo.tfvars`, and `operator_cidr` is changed to the workstation's current public IP. The real tfvars and Terraform state stay out of Git. From the project root:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars -out=demo.tfplan
terraform -chdir=terraform apply demo.tfplan
```

The live stack is already built. Its private tfvars currently requests **one** worker. For the demo, this read-only check is enough to show that the AWS resources still match the code:

```bash
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars
```

The expected result is `No changes`. Terraform outputs include names, addresses and secret ARNs, not password values. RDS generates its own master password in Secrets Manager.

A worker count of zero stops the app but not the other AWS costs. A single NAT gateway and single-AZ RDS keep this short demo smaller, with less redundancy. The deployment user has temporary broad IAM permissions for setup and cleanup; the app role is more limited.

After the agreed demo window, the Ingress/ALB must be removed before `terraform destroy`. The [main README](../README.md#credit-and-cleanup) has those commands. Destroy removes the sample database without a final snapshot, so the local state must be kept until cleanup is complete.
