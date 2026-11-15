resource "random_id" "bucket_suffix" {
  byte_length = 8

  keepers = {
    region = var.region
  }
}

locals {
  bucket_name = var.bucket_name != null ? var.bucket_name : "longhorn-backup-${random_id.bucket_suffix.hex}"
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"
  object_arn  = var.prefix == "" ? "${local.bucket_arn}/*" : "${local.bucket_arn}/${var.prefix}/*"
  list_prefix = var.prefix == "" ? "*" : "${var.prefix}/*"
  target_path = var.prefix == "" ? "huutoapi-images" : "${var.prefix}/huutoapi-images"
  use_kms     = var.kms_key_arn != null
}

# ---------------------------------------------------------------- bucket

resource "aws_s3_bucket" "backup" {
  bucket        = local.bucket_name
  force_destroy = false

  lifecycle {
    # A stray `terraform destroy` must not delete backups.
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explicitly unversioned: Longhorn deletes blocks it no longer references, and
# versioned deletes would keep every old block forever.
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? var.kms_key_arn : null
    }

    bucket_key_enabled = local.use_kms ? true : null
  }
}

# Only stale multipart cleanup. Deliberately NO object expiration:
# Longhorn's docs forbid any retention/lifecycle policy on the backupstore.
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  count  = var.abort_incomplete_multipart_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_days
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [local.bucket_arn, "${local.bucket_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyBucketDeletion"
    effect    = "Deny"
    actions   = ["s3:DeleteBucket"]
    resources = [local.bucket_arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.backup.id
  policy = data.aws_iam_policy_document.bucket.json
}

# ---------------------------------------------------------------- IAM

data "aws_iam_policy_document" "longhorn_backup" {
  statement {
    sid    = "ListBackupPrefix"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [local.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [local.list_prefix]
    }
  }

  statement {
    sid    = "BackupObjectReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = [local.object_arn]
  }

  dynamic "statement" {
    for_each = local.use_kms ? [1] : []

    content {
      sid       = "KmsForSseKms"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_policy" "longhorn_backup" {
  name        = "${var.iam_user_name}-s3"
  description = "Longhorn S3 backupstore access for ${local.bucket_name}"
  policy      = data.aws_iam_policy_document.longhorn_backup.json
}

resource "aws_iam_user" "longhorn_backup" {
  name = var.iam_user_name
  path = "/system/"
}

resource "aws_iam_user_policy_attachment" "longhorn_backup" {
  user       = aws_iam_user.longhorn_backup.name
  policy_arn = aws_iam_policy.longhorn_backup.arn
}

# No aws_iam_user_login_profile is created, so this user cannot log into the console.
resource "aws_iam_access_key" "longhorn_backup" {
  user = aws_iam_user.longhorn_backup.name
}
