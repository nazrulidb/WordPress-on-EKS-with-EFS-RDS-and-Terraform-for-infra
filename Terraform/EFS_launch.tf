# Security Group for EFS (Allow Port 2049 from EKS Nodes)
resource "aws_security_group" "efs" {
  name        = "eks-efs-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "NFS from EKS nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The File System
resource "aws_efs_file_system" "eks_efs" {
  creation_token = "eks-efs"
  encrypted      = true
  tags = { Name = "eks-efs" }
}

# Mount Targets (MUST be in Public Subnets because your Nodes are there)
resource "aws_efs_mount_target" "eks_efs_mount" {
  # switch to count to satisfy Terraform validation
  count = length(module.vpc.public_subnets)

  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}
