# Kubernetes files: how the app runs in EKS

After Terraform has created EKS, the Ansible playbook reads these files and sends them to the cluster. **You normally run Ansible, not each YAML file by hand.**

| File | What it tells Kubernetes to do |
| --- | --- |
| `namespace.yaml` | Put the app in `contact-form` and require basic Pod security rules. |
| `service-accounts.yaml` | Give Flask, the database setup Job and the read-only verifier separate identities. |
| `bootstrap-job.yaml.j2` | Run the one-time database setup. Ansible fills in addresses and secret ARNs. |
| `application.yaml.j2` | Run two Flask Pods, check their health, give them CPU/memory limits, create an internal Service and publish an Ingress for the ALB. |

`.j2` means **Ansible fills in values** such as the database address before submitting the YAML. None of these files contains a database password. The app uses AWS Pod Identity and the Secrets Store CSI driver to mount **only its app secret** from Secrets Manager. Kubernetes does not keep a second password copy in a Kubernetes Secret.

To look at what is running:

```bash
kubectl -n contact-form get deployment,service,ingress,pods
kubectl -n contact-form rollout status deployment/contact-form
```

The Deployment should be **2/2** ready, and the Service should be `ClusterIP` (internal). The Ingress shows the public ALB address. A `db-bootstrap` Pod marked `Completed` is normal: its setup work finished.

The app container runs as a non-root user, cannot gain extra privileges and has resource limits. Its service account cannot list Kubernetes Secrets. [The security page](../docs/security-controls.md) records the checks and exceptions.
