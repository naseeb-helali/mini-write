output "bucket_ids" {
  description = "S3 bucket IDs keyed by logical purpose."

  value = {
    for key, bucket in aws_s3_bucket.this :
    key => bucket.id
  }
}

output "bucket_arns" {
  description = "S3 bucket ARNs keyed by logical purpose."

  value = {
    for key, bucket in aws_s3_bucket.this :
    key => bucket.arn
  }
}

output "bucket_names" {
  description = "S3 bucket names keyed by logical purpose."

  value = {
    for key, bucket in aws_s3_bucket.this :
    key => bucket.bucket
  }
}