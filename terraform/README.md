# Terraform

The root module provisions a two-AZ VPC, internet-facing ALB security group, isolated RDS subnets, private EKS nodes, ECR, Pod Identity permissions and Secrets Manager secret metadata. The ALB itself is created by the Kubernetes AWS Load Balancer Controller from the Ansible-managed Ingress. No credential values are Terraform variables or state outputs; RDS manages its master password in Secrets Manager.

Copy `envs/demo/demo.tfvars.example` to `envs/demo/demo.tfvars` and replace the sample IPv4 `/32` with your workstation's actual public address. Run `terraform -chdir=terraform init`, `validate`, `plan -var-file=envs/demo/demo.tfvars -out=demo.tfplan`, review cost, then `apply demo.tfplan` from the repository root. Keep `.tfstate` and the real `.tfvars` private and preserve state until destroy. See the repository README for deployment and teardown commands.

A single NAT gateway reduces fixed cost and is a single-zone failure point. Node count 0 pauses workers only; EKS control plane, RDS and the network still consume credits. The `aws_eks_cluster` creator receives cluster-admin for the demo, and the workstation IAM deployer has temporary broad provisioning rights; narrow this for a long-lived environment.
