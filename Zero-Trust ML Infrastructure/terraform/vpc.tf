module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.7"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_flow_log        = true
  flow_log_destination_type        = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"      = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb"               = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
