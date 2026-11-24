variable "bucket_prefix" {
  description = "Bucket prefix of the S3 bucket for Velero backups"
  type        = string
  default     = "velero-backups"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "velero_user_name" {
  description = "IAM user name for Velero"
  type        = string
  default     = "velero"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Purpose   = "velero-backups"
    ManagedBy = "terraform"
  }
}
