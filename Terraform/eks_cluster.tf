terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }

  helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13.0"

   }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==============================================================================
# 1. VPC (NO NAT GATEWAY)
# ==============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # --- CRITICAL CHANGES ---
  enable_nat_gateway = false  # Disable NAT
  single_nat_gateway = false
  
  # Ensure public subnets auto-assign IPs so nodes can talk to the internet
  map_public_ip_on_launch = true 

  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ==============================================================================
# 2. EKS CLUSTER (PUBLIC NODES)
# ==============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "managed-cluster"
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id

  # ENABLE OIDC (Required for Autoscaler permissions)
  enable_irsa = true   

  # --- CRITICAL CHANGE ---
  # Since we have no NAT Gateway, nodes MUST be in Public Subnets
  # to reach the EKS Control Plane and download Docker images.
  subnet_ids = module.vpc.public_subnets 
  
  # Control Plane still needs to know about all subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    amazon-cloudwatch-observability = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
    # Add EFS Driver
    aws-efs-csi-driver = { most_recent = true }
    }

  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 6
      desired_size = 2

      # --- CRITICAL FOR PUBLIC NODES ---
      # This ensures the nodes get a public IP address
      associate_public_ip_address = true 
      
      iam_role_additional_policies = {
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        AmazonEBSCSIDriverPolicy    = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
