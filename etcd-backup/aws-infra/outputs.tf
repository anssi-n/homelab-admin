output "s3_bucket_name" {
  description = "Name of the S3 bucket for etcd backups"
  value       = aws_s3_bucket.etcd_backups.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.etcd_backups.arn
}

output "etcd_backup_role_arn" {
  description = "IAM Role ARN that Vault should use (credential_type = assumed_role)"
  value       = aws_iam_role.etcd_backup.arn
}

output "aws_region" {
  value = var.aws_region
}

output "aws_account_id" {
  value = var.aws_account_id
}

# output "iam_user_name" {
#   description = "IAM user used by the backup CronJob"
#   value       = aws_iam_user.etcd_backup_uploader.name
# }

# output "aws_access_key_id" {
#   description = "Access Key ID (put into Kubernetes Secret)"
#   value       = aws_iam_access_key.etcd_backup_uploader.id
# }

# output "aws_secret_access_key" {
#   description = "Secret Access Key"
#   value       = aws_iam_access_key.etcd_backup_uploader.secret
#   sensitive   = true
# }

