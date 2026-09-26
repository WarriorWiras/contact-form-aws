# Demo Terraform values

`demo.tfvars.example` is a shareable sample. The real `demo.tfvars` is ignored by Git and stays on the local workstation.

It has two important values:

- `operator_cidr` is the current public IPv4 address plus `/32`. Only that IP can reach the EKS public API. A changed home IP needs a new Terraform plan and apply.
- `node_count` is the number of EKS workers. The example starts with two. The live demo uses one. Zero stops the workers and the form, but other AWS resources still use credit.

Other defaults, including `us-east-1`, `m7i-flex.large` and `db.t4g.micro`, are in `terraform/variables.tf`. Passwords are not stored in tfvars. The [Terraform README](../../README.md) has the setup commands.

The existing live `demo.tfvars` should not be overwritten with the example.
