# ==============================================================================
# 1. DATABASE SECURITY GROUP (Allow Access from EKS)
# ==============================================================================
resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow EKS nodes to access Aurora MySQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL access from EKS Nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    # This effectively "connects" the database to EKS network-wise
    security_groups = [module.eks.node_security_group_id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db_sg"
  }
}

# ==============================================================================
# 2. DB SUBNET GROUP
# ==============================================================================
resource "aws_db_subnet_group" "wp_subnet" {
  name       = "wp_subnet"
  # Aurora must be in Private Subnets for security
  subnet_ids = module.vpc.private_subnets 

  tags = {
    Name = "wp_subnet"
  }
}

# ==============================================================================
# 3. AURORA CLUSTER (Serverless v2 + Secrets Manager)
# ==============================================================================
resource "aws_rds_cluster" "wordpress" {
  cluster_identifier = "wp-database-1"
  
  # Engine Options
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.10.1" # Compatible with MySQL 8.0.32
  
  # Database Name
  database_name = "wordpress"

  # Master Username & Secrets Manager Integration
  master_username             = "admin"
  manage_master_user_password = true # This automatically creates the Secret in AWS Secrets Manager
  
  # If you want to use a specific KMS key, define it here. 
  # By default (null), it uses the default aws/secretsmanager key.
  master_user_secret_kms_key_id = null 

  # Configuration Options
  db_subnet_group_name   = aws_db_subnet_group.wp_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  # Network
  network_type = "IPV4"
  
  # Serverless v2 Scaling Config
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 1.0
  }

  # Storage Encryption
  storage_encrypted = true

  # Backup & Deletion Protection (Production Settings)
  backup_retention_period = 7
  skip_final_snapshot     = true # Set to 'false' for real production
  deletion_protection     = false # Set to 'true' for real production

  tags = {
    Name = "wp-database-1"
  }
}

# ==============================================================================
# 4. CLUSTER INSTANCE (The Writer)
# ==============================================================================
resource "aws_rds_cluster_instance" "wordpress_writer" {
  identifier         = "wp-database-1-writer"
  cluster_identifier = aws_rds_cluster.wordpress.id
  
  # Instance Class for Serverless v2
  instance_class = "db.serverless"
  engine         = aws_rds_cluster.wordpress.engine
  engine_version = aws_rds_cluster.wordpress.engine_version
  
  publicly_accessible = false
  
  # Monitoring Settings (Unchecked in your requirements)
  performance_insights_enabled = false
  monitoring_interval          = 0 # Enhanced monitoring disabled
}

# ==============================================================================
# 5. OUTPUTS (To help you connect later)
# ==============================================================================
output "db_endpoint" {
  description = "The endpoint URL to connect to the database"
  value       = aws_rds_cluster.wordpress.endpoint
}

output "db_secret_arn" {
  description = "The ARN of the Secret containing the password"
  value       = aws_rds_cluster.wordpress.master_user_secret[0].secret_arn
}
