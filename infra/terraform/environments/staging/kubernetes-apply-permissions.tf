data "aws_iam_policy_document" "kubernetes_provisioning" {
  statement {
    sid    = "DescribeEC2Resources"
    effect = "Allow"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeIamInstanceProfileAssociations",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcs"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "LaunchOnlyApprovedKubernetesNodeTypesInTheProjectVPC"
    effect = "Allow"

    actions = [
      "ec2:RunInstances"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:InstanceType"
      values = [
        var.k8s_control_plane_instance_type,
        var.k8s_worker_instance_type
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:Vpc"
      values   = [module.vpc.vpc_id]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "ec2:Subnet"
      values   = module.vpc.private_app_subnet_ids
    }
  }

  statement {
    sid    = "ManageTaggedKubernetesInstances"
    effect = "Allow"

    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:AssociateIamInstanceProfile",
      "ec2:DisassociateIamInstanceProfile",
      "ec2:ReplaceIamInstanceProfileAssociation"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.kubernetes.account_id}:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid    = "TagResourcesWhenLaunchingKubernetesNodes"
    effect = "Allow"

    actions = [
      "ec2:CreateTags"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances"]
    }
  }

  statement {
    sid    = "DeleteTagsOnlyFromProjectInstances"
    effect = "Allow"

    actions = [
      "ec2:DeleteTags"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.kubernetes.account_id}:instance/*",
      "arn:${data.aws_partition.kubernetes.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.kubernetes.account_id}:volume/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid    = "ManageKubernetesNodeInstanceProfile"
    effect = "Allow"

    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:iam::${data.aws_caller_identity.kubernetes.account_id}:instance-profile/${var.project_name}-${var.environment}-k8s-node-profile"
    ]
  }

  statement {
    sid    = "ListInstanceProfilesForNodeRole"
    effect = "Allow"

    actions = [
      "iam:ListInstanceProfilesForRole"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PassOnlyTheKubernetesNodeRoleToEC2"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      module.kubernetes_ec2.node_role_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid    = "ManageTheDedicatedAnsibleTransferBucket"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketLifecycleConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutBucketLifecycleConfiguration",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketTagging"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:s3:::${var.project_name}-${var.environment}-k8s-ansible-${data.aws_caller_identity.kubernetes.account_id}-${var.aws_region}"
    ]
  }
}

resource "aws_iam_policy" "kubernetes_provisioning" {
  name        = "${var.project_name}-${var.environment}-kubernetes-provisioning"
  description = "Kubernetes provisioning permissions for the IaC apply role"
  policy      = data.aws_iam_policy_document.kubernetes_provisioning.json
}

resource "aws_iam_role_policy_attachment" "kubernetes_provisioning" {
  role       = split("/", module.github_oidc.iac_apply_role_arn)[1]
  policy_arn = aws_iam_policy.kubernetes_provisioning.arn
}
