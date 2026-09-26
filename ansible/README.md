# Ansible deployment

Terraform creates the AWS resources. This playbook puts Flask on EKS.

From the project root in Ubuntu WSL, after signing into the `contact-demo` AWS profile:

```bash
ansible-playbook ansible/deploy.yml
```

Ansible reads the Terraform outputs, builds the Flask and database-helper Docker images, and uploads them to ECR. It installs the AWS Load Balancer Controller and the Secrets Manager mount. It then runs the database setup Job and deploys the Flask Pods, internal Service and Ingress.

The database Job creates the table and two limited users: one to save messages and another to read demo rows. Their passwords go to Secrets Manager, not the Ansible files. The ALB controller reads the Ingress and creates the public ALB.

The result can be checked with:

```bash
kubectl -n contact-form get deployment,service,ingress,pods
```

Two Flask Pods should be ready. The database setup Pod saying `Completed` is normal.

The playbook can be run again. A run with no new changes should end in `changed=0` and `failed=0`. One detail for this documentation update: Ansible's image tag also includes `app/README.md`, so its first run after this commit may rebuild images. A second run should settle back to no changes.

Ansible's Kubernetes support comes from `ansible/requirements.yml` and the `kubernetes`, `PyYAML` and `jsonpatch` packages installed in its pipx environment.
