resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"

  # Instead of multiple 'set' blocks, use one 'values' block with YAML
  values = [
    yamlencode({
      rbac = {
        serviceAccount = {
          create = true
          name   = "cluster-autoscaler"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
          }
        }
      }
      autoDiscovery = {
        clusterName = module.eks.cluster_name
      }
      awsRegion = "us-east-1"
    })
  ]
}
