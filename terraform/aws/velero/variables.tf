variable "metadata_bucket_name" {
  description = "S3 bucket name for Velero metadata"
  type        = string
  default     = "homelab-velero-metadata"
}

variable "backups_bucket_name" {
  description = "S3 bucket name for Velero data backups"
  type        = string
  default     = "homelab-velero-data"
}