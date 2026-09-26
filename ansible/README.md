# Ansible: put the app into EKS

Terraform creates the AWS foundation first. **Ansible is the next step:** it takes the Flask app on my laptop and gets it running in EKS.

From the main project folder in Ubuntu WSL, with the `contact-demo` AWS profile active and at least one EKS worker Ready:

```bash
export PATH="$HOME/.local/bin:$PATH"
export AWS_PROFILE=contact-demo AWS_DEFAULT_REGION=us-east-1
ansible-playbook ansible/deploy.yml
```

If Ansible says a Kubernetes collection or Python package is missing, install its support once:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
pipx inject ansible-core kubernetes PyYAML jsonpatch
```

## What the playbook does

1. Checks that I am using the IAM deployment user, not the AWS root account.
2. Reads Terraform's **non-secret** results, such as the EKS name and RDS address.
3. Builds two container images (Flask and the database helper) on my laptop and uploads them to Amazon ECR if those image tags are missing.
4. Installs the AWS Load Balancer Controller and the tool that mounts AWS secrets into Pods.
5. Creates the app's Kubernetes namespace and service accounts.
6. Runs a one-time database Job. It creates the table, limited-access users and their passwords in Secrets Manager.
7. Starts Flask, creates an internal Service and an Ingress, waits for healthy Pods and prints the ALB website address.

The AWS controller makes the ALB **from the Ingress**. Terraform supplies the AWS network and permissions it needs. Ansible does not print database passwords.

## What to show in the demo

```bash
ansible-playbook ansible/deploy.yml
kubectl -n contact-form get deployment,service,ingress,pods
```

The first run changes resources. A second run with the same code should say `changed=0` and `failed=0`: that shows the deployment can be repeated safely. Both Flask Pods should show ready. The completed `db-bootstrap` Pod is expected to say `Completed`; it is a one-time job, not a failed app.

**Note about this documentation update:** the image tag currently includes all Git-tracked `app/` files, including `app/README.md`. Editing that README may make the next run rebuild images and start a new setup Job. Once that finishes, run the same playbook again: it should show `changed=0` if nothing else changed. Check ALB readiness before the interview.
