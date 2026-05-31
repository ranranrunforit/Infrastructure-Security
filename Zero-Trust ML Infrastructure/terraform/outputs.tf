output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
output "vpc_id"           { value = module.vpc.vpc_id }
output "audit_bucket"     { value = aws_s3_bucket.audit.bucket }
output "audit_writer_role_arn" {
  value       = aws_iam_role.audit_writer.arn
  description = "Bind to the audit-forwarder ServiceAccount via eks.amazonaws.com/role-arn."
}
