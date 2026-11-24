output "bucket_name" {
  value = aws_s3_bucket.velero.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.velero.arn
}

output "velero_access_key_id" {
  value     = aws_iam_access_key.velero.id
  sensitive = true
}

output "velero_secret_access_key" {
  value     = aws_iam_access_key.velero.secret
  sensitive = true
}

output "credentials_file_content" {
  value     = <<-EOT
[default]
aws_access_key_id=${aws_iam_access_key.velero.id}
aws_secret_access_key=${aws_iam_access_key.velero.secret}
EOT
  sensitive = true
}
