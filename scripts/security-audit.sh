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
  --query 'cluster.{version:version,endpointPrivate:resourcesVpcConfig.endpointPrivateAccess,endpointPublic:resourcesVpcConfig.endpointPublicAccess,publicCIDRs:resourcesVpcConfig.publicAccessCidrs,logging:logging.clusterLogging}' \
  --output json

echo "Managed node placement and capacity"
aws eks describe-nodegroup --cluster-name "$cluster" --nodegroup-name "$cluster-private" \
  --query 'nodegroup.{subnets:subnets,instanceTypes:instanceTypes,scaling:scalingConfig}' \
  --output json

echo "RDS public access, encryption and backups (master secret ARN only)"
aws rds describe-db-instances --db-instance-identifier "$cluster-postgres" \
  --query 'DBInstances[0].{public:PubliclyAccessible,storageEncrypted:StorageEncrypted,backupDays:BackupRetentionPeriod,multiAZ:MultiAZ,masterSecret:MasterUserSecret.SecretArn,subnetGroup:DBSubnetGroup.DBSubnetGroupName}' \
  --output json

echo "Database subnet routes (only the VPC local route is expected)"
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=$cluster-isolated-db" \
  --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId]' --output json

echo "Database security group rules"
db_sg="$(aws rds describe-db-instances --db-instance-identifier "$cluster-postgres" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)"
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$db_sg" \
  --query 'SecurityGroupRules[].[IsEgress,IpProtocol,FromPort,ToPort,CidrIpv4,ReferencedGroupInfo.GroupId]' \
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

echo "EKS control-plane log retention and ECR image scanning/encryption"
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$cluster/cluster" \
  --query 'logGroups[].[logGroupName,retentionInDays]' --output json
aws ecr describe-repositories --repository-names "$cluster" \
  --query 'repositories[].[repositoryName,imageScanningConfiguration.scanOnPush,encryptionConfiguration.encryptionType]' \
  --output json

echo "Kubernetes namespace labels, services and application RBAC"
kubectl get ns contact-form --show-labels
kubectl -n contact-form get serviceaccounts,deployments,ingresses
kubectl -n contact-form auth can-i list secrets \
  --as=system:serviceaccount:contact-form:contact-form

echo "Live Flask Pod security, resources and probes (no env/secret values)"
kubectl -n contact-form get deployment contact-form -o json | python3 -c \
  'import json,sys; p=json.load(sys.stdin)["spec"]["template"]["spec"]; c=p["containers"][0]; print(json.dumps({"podSecurityContext":p.get("securityContext"),"containerSecurityContext":c.get("securityContext"),"resources":c.get("resources"),"readinessProbe":c.get("readinessProbe"),"livenessProbe":c.get("livenessProbe")},indent=2))'
