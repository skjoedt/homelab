output "backups_bucket_name" {
  value = aws_s3_bucket.cnpg_backups.bucket
}

output "backups_bucket_arn" {
  value = aws_s3_bucket.cnpg_backups.arn
}

output "iam_user_name" {
  value = aws_iam_user.cnpg.name
}

output "iam_user_arn" {
  value = aws_iam_user.cnpg.arn
}

output "iam_policy_arn" {
  value = aws_iam_policy.cnpg_backup.arn
}
