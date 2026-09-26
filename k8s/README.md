# Kubernetes files

Ansible sends these files to EKS. They are not normally applied one by one.

- `namespace.yaml` gives the app its own namespace and enforces restricted Pod rules.
- `service-accounts.yaml` gives Flask, database setup and the demo verifier separate identities.
- `bootstrap-job.yaml.j2` runs the database setup.
- `application.yaml.j2` defines the Flask Pods, internal Service, secret mount and Ingress.

The `.j2` files are templates. Ansible fills in values such as the RDS address and secret ARN. Passwords are not written into the templates. AWS Pod Identity and the Secrets Store CSI driver provide the app secret inside the Flask Pod; there is no Kubernetes Secret copy of the database password.

```bash
kubectl -n contact-form get deployment,service,ingress,pods
```

The Deployment should show **2/2** ready. The Service is `ClusterIP`, meaning it stays inside EKS. The Ingress gives the ALB its route to Flask. The `db-bootstrap` Pod says `Completed` after setting up PostgreSQL; that is expected.
