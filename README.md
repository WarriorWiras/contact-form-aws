# Contact form on AWS

I built this for the SIT DevSecOps internship assignment. The form takes a name, email and message. Flask saves it in PostgreSQL on Amazon RDS. It runs in Amazon EKS, with an AWS Application Load Balancer (ALB) in front.

The setup runs from Ubuntu WSL on my Windows laptop. Terraform makes the AWS network, EKS cluster and database. Ansible builds and deploys the app. The AWS Load Balancer Controller makes the ALB from a Kubernetes Ingress. The [architecture page](docs/architecture.md) has a diagram.

The app was tested on 25 September 2026: a test form entry went through the ALB and appeared in RDS. On 26 September, one EKS worker and both Flask Pods were ready, the ALB health check returned HTTP 200, and `terraform plan` showed no changes. I reduced the workers from two to one to use fewer credits. The interview demo and AWS cleanup are still pending.

## Running the current demo

From Windows PowerShell, open WSL with `wsl -d Ubuntu`. In Ubuntu:

```bash
cd ~/projects/contact-form-aws
export PATH="$HOME/.local/bin:$PATH"
export AWS_PROFILE=contact-demo AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity --query Arn --output text
```

The last line should end in `user/contact-demo-deployer`, not `:root`. An expired session is fixed with `aws login --profile contact-demo --region us-east-1` and the normal browser/MFA sign-in.

```bash
aws freetier get-account-plan-state \
  --query '{plan:accountPlanType,status:accountPlanStatus,remaining:accountPlanRemainingCredits}' \
  --output json
kubectl get nodes
kubectl -n contact-form get deployment,service,ingress
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars
```

These show the current credit, EKS worker, app and ALB address. With no AWS changes, Terraform prints `No changes`. The credit figure is only valid at the time of the check. AWS resources use credit even when the laptop is off.

The Ingress has the website address. This command checks both Flask and its database connection:

```bash
ALB_HOST="$(kubectl -n contact-form get ingress contact-form \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl --max-time 15 -i "http://$ALB_HOST/health/ready"
```

A healthy result is HTTP 200 and `ready`. The public form is **HTTP**, so it is only for made-up test details.

## Building the stack from scratch

These are the steps used for the original deployment. The live stack already exists. The real `terraform/envs/demo/demo.tfvars` and Terraform state are kept locally and must not be replaced with the example or committed to Git.

Ubuntu WSL needs AWS CLI, Terraform 1.9+, Docker Desktop WSL integration, kubectl, Helm, Python and Ansible Core. Ansible also needs:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
pipx inject ansible-core kubernetes PyYAML jsonpatch
```

The example `demo.tfvars` uses a placeholder IP and two workers. For a first build, copy it and change `operator_cidr` to the workstation's current public IPv4 followed by `/32`. That is the only public IP allowed to reach the EKS API. The live private file uses `node_count = 1`.

```bash
cp terraform/envs/demo/demo.tfvars.example terraform/envs/demo/demo.tfvars  # first build only
# Edit operator_cidr in demo.tfvars before planning.
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=envs/demo/demo.tfvars -out=demo.tfplan
```

`init` downloads Terraform providers, `validate` checks the code, and `plan` shows what would change. After checking AWS credit, quotas and the plan:

```bash
terraform -chdir=terraform apply demo.tfplan
aws eks update-kubeconfig --name contact-demo --region us-east-1 --alias contact-demo
kubectl get nodes -o wide
aws rds describe-db-instances --db-instance-identifier contact-demo-postgres \
  --query 'DBInstances[0].{status:DBInstanceStatus,public:PubliclyAccessible,encrypted:StorageEncrypted}' \
  --output table
```

`apply` creates the resources. `update-kubeconfig` connects kubectl to EKS. RDS should show `public=False` and `encrypted=True`. Terraform makes the app's empty secret in Secrets Manager; the Ansible database Job creates its password later.

The app deployment is one command:

```bash
ansible-playbook ansible/deploy.yml
kubectl -n contact-form get deployment,service,ingress,pods
```

Ansible builds images on the laptop, uploads them to ECR, prepares the database and starts Flask. A healthy Deployment shows **2/2**, even though both Pods currently share one worker. The finished database setup Pod says `Completed`. The Ingress leads to the ALB.

A test message can be entered through the ALB website. `./scripts/verify.sh` then reads it from RDS with a separate read-only database user. Only fictional data belongs in this demo.

```bash
./scripts/verify.sh
```

The four Flask tests can also run without AWS:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r app/requirements.txt
cd app
python -m unittest discover -s tests -v
cd ..
```

## Credit and cleanup

The live `node_count` is one. Zero workers would stop the form, but EKS, RDS, NAT, ALB and other resources would still use credit. Two workers give more redundancy but use more compute. The last credit figure in the evidence was a snapshot; check AWS again before leaving the stack running.

After the agreed demo window, the Ingress must be removed while the controller is still running. This lets it delete the ALB before Terraform removes the network:

```bash
kubectl -n contact-form delete ingress contact-form --wait=true
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{name:LoadBalancerName,dns:DNSName}' --output table
terraform -chdir=terraform destroy -var-file=envs/demo/demo.tfvars
terraform -chdir=terraform state list
```

Confirm this project's ALB is gone before `destroy`. Destroy deletes the sample database without a final snapshot. Check AWS afterwards for any leftover EKS, RDS, NAT, ALB, ECR or secrets, and keep the local Terraform state until cleanup is complete.

## Project folders

- `terraform/`: AWS network, EKS, RDS, IAM, ECR and Secrets Manager setup.
- `ansible/`: the playbook that builds and deploys the app.
- `app/`: Flask code, database helper and tests.
- `k8s/`: the Kubernetes files Ansible uses.
- `scripts/`: database check and security audit.
- `docs/`: [architecture](docs/architecture.md), [requirements](docs/requirements-matrix.md), [security notes](docs/security-controls.md).
- `evidence/`: redacted checks safe for Git. Raw files stay in the ignored `evidence/private/` folder.

The first worker type tried on 25 September was `t3.medium`, which this Free Plan account rejected. Terraform now defaults to the eligible `m7i-flex.large`. The old failed plan must not be reused; any repair needs a fresh plan with the same private state and variables.
