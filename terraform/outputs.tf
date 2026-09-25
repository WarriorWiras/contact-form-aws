output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "region" {
  value = var.region
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "db_host" {
  value = aws_db_instance.postgres.address
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "db_master_secret_arn" {
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "verifier_secret_arn" {
  value = aws_secretsmanager_secret.verifier.arn
}
