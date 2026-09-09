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