variable "region" {
  description = "AWS region for the zero-trust ML cluster."
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "zero-trust-ml"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "azs" {
  description = "Availability zones to span."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "node_instance_types" {
  description = "EKS managed-node-group instance types."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_desired_size" {
  description = "Desired EKS node count."
  type        = number
  default     = 3
}

variable "audit_bucket_name" {
  description = "S3 bucket for tamper-evident audit log storage. Must be globally unique."
  type        = string
}

variable "audit_retention_days" {
  description = "Object Lock retention period in days (compliance mode)."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    project = "zero-trust-ml"
    owner   = "platform-security"
  }
}
