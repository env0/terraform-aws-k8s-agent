data aws_eks_cluster "my_eks" {
  count = var.modules_info.eks.create ? 0 : 1
  name = var.modules_info.eks.cluster_id
}

locals {
  vpc_id          = var.modules_info.vpc.create ? module.vpc[0].vpc_id : var.modules_info.vpc.id
  private_subnets = var.modules_info.vpc.create ? module.vpc[0].private_subnets : var.modules_info.vpc.private_subnets
  efs_id          = var.modules_info.efs.create ? module.efs[0].efs_id : var.modules_info.efs.id
}

module "vpc" {
  count           = var.modules_info.vpc.create ? 1 : 0
  source          = "./modules/vpc"

  cluster_name    = var.cluster_name
  cidr            = var.cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}

module "eks" {
  depends_on = [module.vpc]
  count          = var.modules_info.eks.create ? 1 : 0
  source         = "./modules/eks"

  is_self_hosted = var.is_self_hosted
  vpc_id         = local.vpc_id
  cluster_name   = var.cluster_name
  map_roles      = var.map_roles
  min_capacity   = var.min_capacity
  instance_type  = var.instance_type
}

module "efs" {
  count                                = var.modules_info.efs.create ? 1 : 0
  depends_on                           = [module.eks, module.vpc]
  source                               = "./modules/efs"
             
  region                               = var.region
  vpc_id                               = local.vpc_id
  cluster_name                         = var.cluster_name
  subnets                              = local.private_subnets
  worker_security_group_id             = module.eks[0].worker_security_group_id
  cluster_primary_security_group_id    = module.eks[0].cluster_primary_security_group_id
  additional_cluster_security_group_id = module.eks[0].additional_cluster_security_group_id
}

module "autoscaler" {
  count      = var.modules_info.autoscaler.create ? 1 : 0
  depends_on = [module.eks]
  source     = "./modules/autoscaler"

  cluster_name = var.cluster_name
}

module "csi_driver" {
  count      = var.modules_info.csi_driver.create ? 1 : 0
  depends_on = [module.efs]
  source     = "./modules/csi-driver"

  efs_id         = local.efs_id
  reclaim_policy = var.reclaim_policy
  cluster_name   = var.cluster_name
}
