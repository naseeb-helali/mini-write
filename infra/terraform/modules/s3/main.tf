locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

resource "aws_s3_bucket" "this" {
  for_each = var.bucket_names

  bucket = each.value

  force_destroy = var.force_destroy

  tags = merge(
    local.common_tags,
    {
      Name   = each.value
      Purpose = each.key
    }
  )
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.bucket_names

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.bucket_names

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.bucket_names

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = var.bucket_names

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = "noncurrent-version-cleanup"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}