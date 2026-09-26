# Terraform: create the AWS foundation

Terraform is the part I run from my laptop **before** Ansible. It makes the network, private EKS cluster workers, private PostgreSQL RDS database, IAM roles, ECR image repository, logging and Secrets Manager secret containers.

The public ALB itself is created later by the AWS Load Balancer Controller when Ansible adds the Kubernetes Ingress. Terraform creates the subnets, network rules and IAM permissions that allow the controller to do that.

## If this is the first build

From the **main repository folder** in Ubuntu WSL:

```bash
export AWS_PROFILE=contact-demo AWS_DEFAULT_REGION=us-east-1
cp terraform/envs/demo/demo.tfvars.example terraform/envs/demo/demo.tfvars
# Edit demo.tfvars and replace operator_cidr with YOUR current public IPv4/32.
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars -out=demo.tfplan
```

`init` downloads the providers Terraform needs. `validate` checks the code. `plan` lists the changes without creating anything. Review cost and remaining Free Plan credit before running:

```bash
terraform -chdir=terraform apply demo.tfplan
```

**This AWS stack already exists.** Do not copy the example over the real `demo.tfvars`, lose the state file, or apply an old saved plan. For the live demo, read the current setup with:

```bash
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars
```

`No changes` means AWS and Terraform still match. Terraform's outputs include database/secret **addresses and ARNs**, not passwords. RDS generates its own master password and stores it in Secrets Manager.

## Why the network has three kinds of subnet

- **Public subnets:** contain the ALB and a NAT gateway.
- **Private app subnets:** contain EKS workers and Flask Pods. The workers have no public IP.
- **Isolated database subnets:** contain RDS and have no route to the internet. RDS allows PostgreSQL traffic only from the worker network.

There is one NAT gateway to spend fewer credits; it is also a single point of failure. The RDS database runs in one Availability Zone to keep the demo small. These choices are listed as limitations in the [security page](../docs/security-controls.md).

## Saving credit and cleaning up

The live private `demo.tfvars` uses `node_count = 1`; the example starts at two. Setting it to `0` and running a new Terraform plan/apply stops workers **but also stops the form**. EKS, RDS, NAT, ALB and other resources continue using credit. Before a demo, bring the count back to at least `1` and check that the app is healthy.

After the agreed demo window, remove the Ingress and let the controller delete the ALB **before** using `terraform destroy`. Destroy removes the sample database without a final snapshot. Keep the state file safe until the teardown is complete. The [main guide](../README.md#credits-pause-and-cleanup) gives the commands.

The workstation deployment user has temporary broad IAM access for this demo, although the app itself has a role limited to its own secret. Explain this openly; it is not a fully locked-down production deployment.
