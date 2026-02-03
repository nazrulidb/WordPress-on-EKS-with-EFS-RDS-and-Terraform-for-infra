resource "aws_iam_role" "efs_csi_role" {
  name = "efs-csi-pod-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" 
  # Wait! Standard EFS policy is actually: AmazonEFSCSIDriverPolicy
  # Double check the policy name below:
  role       = aws_iam_role.efs_csi_role.name
}

# Correct Policy Attachment
resource "aws_iam_role_policy_attachment" "efs_csi_policy_correct" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_role.name
}
