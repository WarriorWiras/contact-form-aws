# Demo settings for Terraform

The two most important settings are in `demo.tfvars`:

| Setting | What it means |
| --- | --- |
| `operator_cidr` | Your **current** public IPv4 address with `/32`. Only that address may reach the EKS public API from the internet. Change it if your home IP changes. |
| `node_count` | Number of EKS workers: `0` pauses the app, `1` is the current running demo, `2` adds another worker. |

`demo.tfvars.example` is safe to share because its IP is only a placeholder. It starts with two workers. On a **first build**, copy it to `demo.tfvars`, edit the IP and check costs before applying. **Do not copy it again over the existing live file.** Git ignores the real `demo.tfvars`, which contains your operator IP and current worker choice.

Other defaults such as region (`us-east-1`), EKS name (`contact-demo`), worker type (`m7i-flex.large`) and database type (`db.t4g.micro`) are defined in `terraform/variables.tf`. [The main Terraform guide](../../README.md) explains the commands. Never put AWS passwords in either settings file.
