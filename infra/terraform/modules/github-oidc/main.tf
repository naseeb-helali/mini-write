data "aws_s3_bucket" "tfstate" {
  bucket = var.tfstate_bucket_name
}

data "aws_iam_policy_document" "tfstate_access" {
  statement {
    sid    = "S3StateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      data.aws_s3_bucket.tfstate.arn
    ]
  }

  statement {
    sid    = "S3StateObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${data.aws_s3_bucket.tfstate.arn}/*"
    ]
  }
}


data "aws_partition" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-actions-oidc"
    }
  )
}

data "aws_iam_policy_document" "iac_plan_assume_role" {
  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = var.plan_subjects
    }
  }
}

resource "aws_iam_role" "iac_plan" {
  name = "${var.project}-github-iac-plan"

  assume_role_policy = data.aws_iam_policy_document.iac_plan_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-iac-plan"
    }
  )
}

data "aws_iam_policy_document" "iac_apply_assume_role" {
  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        var.apply_subject
      ]
    }
  }
}

resource "aws_iam_role" "iac_apply" {
  name = "${var.project}-github-iac-apply"

  assume_role_policy = data.aws_iam_policy_document.iac_apply_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-iac-apply"
    }
  )
}


resource "aws_iam_role_policy" "iac_plan_tfstate" {
  name   = "${var.project}-iac-plan-tfstate-policy"
  role   = aws_iam_role.iac_plan.name
  policy = data.aws_iam_policy_document.tfstate_access.json
}

resource "aws_iam_role_policy" "iac_apply_tfstate" {
  name   = "${var.project}-iac-apply-tfstate-policy"
  role   = aws_iam_role.iac_apply.name
  policy = data.aws_iam_policy_document.tfstate_access.json
}
