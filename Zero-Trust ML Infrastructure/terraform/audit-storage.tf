# Tamper-evident audit log storage (ARCHITECTURE L0): S3 + Object Lock in
# compliance mode. Object Lock makes objects immutable for the retention
# window; the hash chain in audit/hash-chain.py detects any after-the-fact
# tampering against this same set of objects.

resource "aws_s3_bucket" "audit" {
  bucket              = var.audit_bucket_name
  object_lock_enabled = true
  force_destroy       = false
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.audit_retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    id     = "tier-and-expire"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration { days = var.audit_retention_days }
  }
}

# IRSA role used by the in-cluster audit log forwarder (fluent-bit) to write
# audit log objects to the bucket. See audit/long-term-storage/.
data "aws_iam_policy_document" "audit_writer_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:audit:audit-forwarder"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "audit_writer" {
  statement {
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = [aws_s3_bucket.audit.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:PutObjectRetention"]
    resources = ["${aws_s3_bucket.audit.arn}/*"]
  }
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
  statement {
    actions = ["logs:DescribeLogStreams", "logs:FilterLogEvents", "logs:GetLogEvents"]
    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/cluster:log-stream:*"]
  }
}

resource "aws_iam_role" "audit_writer" {
  name               = "${var.cluster_name}-audit-writer"
  assume_role_policy = data.aws_iam_policy_document.audit_writer_assume.json
}

resource "aws_iam_role_policy" "audit_writer" {
  role   = aws_iam_role.audit_writer.id
  policy = data.aws_iam_policy_document.audit_writer.json
}
