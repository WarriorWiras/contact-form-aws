#!/usr/bin/env bash
# Run a one-shot, read-only SQL query inside the private EKS network.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AWS_PROFILE="${AWS_PROFILE:-contact-demo}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "$arn" == *:root ]]; then
  echo "Refusing to use the root account." >&2
  exit 1
fi

tf() { terraform -chdir="$project_root/terraform" output -raw "$1"; }
cluster="$(tf cluster_name)"
region="$(tf region)"
db_host="$(tf db_host)"
db_name="$(tf db_name)"
verifier_secret="$(tf verifier_secret_arn)"
repository="$(tf ecr_repository_url)"
aws eks update-kubeconfig --name "$cluster" --region "$region" --alias "$cluster" >/dev/null

app_image="$(kubectl -n contact-form get deployment contact-form -o 'jsonpath={.spec.template.spec.containers[0].image}')"
image_tag="${app_image##*:app-}"
if [[ ! "$image_tag" =~ ^[0-9a-f]{16}$ ]]; then
  echo "Unexpected deployed image tag; run Ansible first." >&2
  exit 1
fi

job="db-verify-$(date +%s)-$RANDOM"
cleanup() { kubectl -n contact-form delete job "$job" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT
kubectl create -f - <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: $job
  namespace: contact-form
spec:
  backoffLimit: 2
  template:
    spec:
      serviceAccountName: db-verifier
      restartPolicy: Never
      securityContext:
        runAsUser: 10001
        runAsGroup: 10001
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: query
          image: $repository:bootstrap-$image_tag
          command: ["python", "verify.py"]
          env:
            - name: AWS_REGION
              value: "$region"
            - name: DB_HOST
              value: "$db_host"
            - name: DB_NAME
              value: "$db_name"
            - name: VERIFIER_SECRET_ARN
              value: "$verifier_secret"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          resources:
            requests:
              cpu: 25m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 192Mi
YAML

if ! kubectl -n contact-form wait --for=condition=complete "job/$job" --timeout=300s; then
  kubectl -n contact-form describe job "$job" >&2
  kubectl -n contact-form logs "job/$job" >&2 || true
  exit 1
fi
kubectl -n contact-form logs "job/$job"
