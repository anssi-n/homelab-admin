variable "region" {
  description = "AWS region. Must match the region embedded in the Longhorn backup target URL."
  type        = string
  default     = "eu-north-1"
}

variable "bucket_name" {
  description = "Globally unique bucket name. Defaults to longhorn-backup-<8 random hex bytes>."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Key prefix Longhorn writes under. Set to \"\" to allow the whole bucket."
  type        = string
  default     = "longhorn"
}

variable "iam_user_name" {
  description = "IAM user Longhorn uses to reach the bucket."
  type        = string
  default     = "longhorn-backup"
}

variable "kms_key_arn" {
  description = "Optional KMS CMK ARN for SSE-KMS. When null, SSE-S3 (AES256) is used."
  type        = string
  default     = null
}

variable "abort_incomplete_multipart_days" {
  description = "Abort stale multipart uploads after N days (0 disables). Object expiration is never configured."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to all created resources."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Purpose   = "longhorn-backup"
  }
}
