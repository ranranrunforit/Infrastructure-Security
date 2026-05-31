module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Audit log + control-plane logs go to CloudWatch; fluent-bit ships them
  # onward to the tamper-evident S3 bucket (see audit/long-term-storage/).
  cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

  cluster_addons = {
    coredns = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = 1
      max_size       = 6
      desired_size   = var.node_desired_size
      labels         = { workload = "general" }
    }
  }

  # Required by IRSA modules so EKS issues OIDC discovery docs.
  enable_irsa = true
}
