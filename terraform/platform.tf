data "aws_iam_policy_document" "eks_cluster_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.name}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_trust.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "eks_node_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_nodes" {
  name               = "${var.name}-eks-nodes"
  assume_role_policy = data.aws_iam_policy_document.eks_node_trust.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# Demo tradeoff: CNI uses the node role; split it to Pod Identity in a longer-lived environment.
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 7
}

resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = aws_subnet.app[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.operator_cidr]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_cloudwatch_log_group.eks,
    aws_route.app_nat,
  ]
}

# Include the EKS-created cluster security group: managed nodes require it when
# a custom launch-template security group is specified.
resource "aws_launch_template" "nodes" {
  name_prefix            = "${var.name}-nodes-"
  update_default_version = true
  vpc_security_group_ids = [
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
    aws_security_group.nodes.id,
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-worker" }
  }
}

resource "aws_eks_node_group" "private" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name}-private"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.app[*].id
  capacity_type   = "ON_DEMAND"
  instance_types  = [var.node_instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.node_count
    min_size     = 0
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_cni,
  ]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  depends_on   = [aws_eks_node_group.private]
}

resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${var.name}-postgres"
  engine                      = "postgres"
  engine_version              = "16.9"
  instance_class              = var.db_instance_class
  db_name                     = "contacts"
  username                    = "dbadmin"
  manage_master_user_password = true

  allocated_storage       = 20
  storage_type            = "gp3"
  storage_encrypted       = true
  multi_az                = false
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.database.name
  vpc_security_group_ids  = [aws_security_group.database.id]
  backup_retention_period = 1

  auto_minor_version_upgrade = true
  deletion_protection        = false
  skip_final_snapshot        = true
  copy_tags_to_snapshot      = true
}

# Terraform owns only the empty secret. A one-time in-cluster bootstrap Job
# generates its password and writes the first version; no password enters state.
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name}/app-db"
  description             = "Restricted PostgreSQL application role"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "verifier" {
  name                    = "${var.name}/read-only-db"
  description             = "Read-only PostgreSQL demo verifier"
  recovery_window_in_days = 0
}
