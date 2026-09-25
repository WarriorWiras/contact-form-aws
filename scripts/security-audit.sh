#!/usr/bin/env bash
# Read-only CIS-aligned configuration evidence; review output before sharing.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AWS_PROFILE="${AWS_PROFILE:-contact-demo}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

tf() { terraform -chdir="$project_root/terraform" output -raw "$1"; }
cluster="$(tf cluster_name)"

echo "EKS endpoint access and control-plane logs"
aws eks describe-cluster --name "$cluster" \
  --query 'cluster.{version:version,endpointPrivate:vpcConfig.endpointPrivateAccess,endpointPublic:vpcConfig.endpointPublicAccess,publicCIDRs:vpcConfig.publicAccessCidrs,logging:logging.clusterLogging}' \
  --output json

echo "Managed node placement and capacity"
aws eks describe-nodegroup --cluster-name "$cluster" --nodegroup-name "$cluster-private" \
  --query 'nodegroup.{subnets:subnets,instanceTypes:instanceTypes,scaling:scalingConfig}' \
  --output json

echo "RDS public access, encryption and backups (master secret ARN only)"
aws rds describe-db-instances --db-instance-identifier "$cluster-postgres" \
  --query 'DBInstances[0].{public:PubliclyAccessible,storageEncrypted:StorageEncrypted,backupDays:BackupRetentionPeriod,multiAZ:MultiAZ,masterSecret:MasterUserSecret.SecretArn,subnetGroup:DBSubnetGroup.DBSubnetGroupName}' \
  --output json

echo "Application and verifier secret metadata (never secret values)"
aws secretsmanager describe-secret --secret-id "$(tf app_secret_arn)" \
  --query '{arn:ARN,rotationEnabled:RotationEnabled}' --output json
aws secretsmanager describe-secret --secret-id "$(tf verifier_secret_arn)" \
  --query '{arn:ARN,rotationEnabled:RotationEnabled}' --output json

echo "Internet-facing ALB security group ingress/egress"
aws ec2 describe-security-groups --group-ids "$(tf alb_security_group_id)" \
  --query 'SecurityGroups[0].{ingress:IpPermissions,egress:IpPermissionsEgress}' --output json

echo "Deployer MFA device count"
aws iam list-mfa-devices --user-name contact-demo-deployer \
  --query 'length(MFADevices)' --output text

echo "Kubernetes namespace labels, services and application RBAC"
kubectl get ns contact-form --show-labels
kubectl -n contact-form get serviceaccounts,deployments,ingresses
kubectl -n contact-form auth can-i list secrets \
  --as=system:serviceaccount:contact-form:contact-form
