variable "region" {
  default = "us-east-1"
}
# Trust Policy: Trust the EKS Pod Identity Service (pods.eks.amazonaws.com)
data "aws_iam_policy_document" "lbc_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc_role" {
  name               = "${module.eks.cluster_name}-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_trust.json
}

# Download the official AWS Load Balancer Controller Policy
data "http" "lbc_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc_policy" {
  name        = "${module.eks.cluster_name}-lbc-policy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = data.http.lbc_policy.response_body
}

resource "aws_iam_role_policy_attachment" "lbc_attach" {
  role       = aws_iam_role.lbc_role.name
  policy_arn = aws_iam_policy.lbc_policy.arn
}

# ==============================================================================
# 2. POD IDENTITY ASSOCIATION
# This links the IAM Role to the Kubernetes Service Account
# ==============================================================================
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc_role.arn
}

# ==============================================================================
# 3. HELM RELEASE
# ==============================================================================
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1" 

   set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    }
  ]

    
  depends_on = [aws_eks_pod_identity_association.lbc]
}