data "aws_iam_policy_document" "pod_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app-secret-reader"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}

data "aws_iam_policy_document" "app_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.app.arn]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "ReadOnlyAppSecret"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_secret.json
}

resource "aws_eks_pod_identity_association" "app" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "contact-form"
  service_account = "contact-form"
  role_arn        = aws_iam_role.app.arn
  depends_on      = [aws_iam_role_policy.app, aws_eks_addon.pod_identity_agent]
}

resource "aws_iam_role" "bootstrap" {
  name               = "${var.name}-db-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}

data "aws_iam_policy_document" "bootstrap" {
  statement {
    sid       = "ReadRDSGeneratedMasterCredential"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
  }

  statement {
    sid = "InitializeRestrictedAppCredential"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
    ]
    resources = [aws_secretsmanager_secret.app.arn]
  }

  statement {
    sid = "InitializeReadOnlyVerifierCredential"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
    ]
    resources = [aws_secretsmanager_secret.verifier.arn]
  }
}

resource "aws_iam_role_policy" "bootstrap" {
  name   = "InitializeAppDBSecret"
  role   = aws_iam_role.bootstrap.id
  policy = data.aws_iam_policy_document.bootstrap.json
}

resource "aws_eks_pod_identity_association" "bootstrap" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "contact-form"
  service_account = "db-bootstrap"
  role_arn        = aws_iam_role.bootstrap.arn
  depends_on      = [aws_iam_role_policy.bootstrap, aws_eks_addon.pod_identity_agent]
}

resource "aws_iam_role" "verifier" {
  name               = "${var.name}-db-read-only"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}

data "aws_iam_policy_document" "verifier" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.verifier.arn]
  }
}

resource "aws_iam_role_policy" "verifier" {
  name   = "ReadOnlyVerifierSecret"
  role   = aws_iam_role.verifier.id
  policy = data.aws_iam_policy_document.verifier.json
}

resource "aws_eks_pod_identity_association" "verifier" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "contact-form"
  service_account = "db-verifier"
  role_arn        = aws_iam_role.verifier.arn
  depends_on      = [aws_iam_role_policy.verifier, aws_eks_addon.pod_identity_agent]
}

# AWS publishes the controller's versioned IAM document. Fetch at Terraform
# plan time so the policy is provisioned by Terraform, not by manual IAM clicks.
# This tag and the Helm chart version are intentionally paired (v2.14.1 / 1.14.0).
data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.name}-alb-controller"
  policy = data.http.alb_controller_policy.response_body
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_trust.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller.arn
  depends_on      = [aws_iam_role_policy_attachment.alb_controller, aws_eks_addon.pod_identity_agent]
}
