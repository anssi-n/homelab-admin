resource "aws_iam_role" "etcd_backup" {
  name = "etcd-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:user/${var.vault_user_name}"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose   = "Short-lived credentials for etcd backups via Vault"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "etcd_backup" {
  name = "EtcdBackupS3Access"
  role = aws_iam_role.etcd_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.etcd_backups.arn
        ]
      },
      {
        Sid    = "WriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "${aws_s3_bucket.etcd_backups.arn}/etcd/*"
        ]
      }
    ]
  })
}
# resource "aws_iam_user" "etcd_backup_uploader" {
#   name = "etcd-backup-uploader"

#   tags = {
#     Purpose   = "Upload encrypted etcd snapshots"
#     ManagedBy = "terraform"
#   }
# }

# resource "aws_iam_user_policy" "etcd_backup_uploader" {
#   name = "EtcdBackupUpload"
#   user = aws_iam_user.etcd_backup_uploader.name

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "ListBucket"
#         Effect = "Allow"
#         Action = [
#           "s3:ListBucket"
#         ]
#         Resource = [
#           aws_s3_bucket.etcd_backups.arn
#         ]
#       },
#       {
#         Sid    = "WriteObjects"
#         Effect = "Allow"
#         Action = [
#           "s3:PutObject",
#           "s3:AbortMultipartUpload"
#         ]
#         Resource = [
#           "${aws_s3_bucket.etcd_backups.arn}/etcd/*"
#         ]
#       }
#     ]
#   })
# }

# resource "aws_iam_access_key" "etcd_backup_uploader" {
#   user = aws_iam_user.etcd_backup_uploader.name
# }

