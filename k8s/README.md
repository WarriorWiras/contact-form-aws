# Kubernetes manifests

Ansible applies the namespace/service accounts and renders Jinja templates for the database bootstrap Job and app's SecretProviderClass, Deployment, ClusterIP Service, and ALB Ingress. Flask reads a CSI-mounted AWS Secrets Manager file via EKS Pod Identity. A separate `db-verifier` service account and PostgreSQL SELECT-only role are used by `scripts/verify.sh`. The `restricted` Pod Security Admission policy and least privilege Pod Identity associations are set separately. No Kubernetes Secret copies the database password.
