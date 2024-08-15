
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # https://web.archive.org/web/20240122155758/https://github.com/aws-actions/configure-aws-credentials/issues/357
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# The S3 bucket used!
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "json-files-test-bucket"
}

# Assume role policy
data "aws_iam_policy_document" "github_actions_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # We will provide you the repository name here
      # <owner>/<repository-name>
      values = ["repo:jakob-lj/oidc-terraform-provider:ref:refs/heads/main"]
    }

    # Condition checking that correct audience is used
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Policy used for granting access to the IAM Role
data "aws_iam_policy_document" "gha_iam_policy" {
  statement {
    actions = ["S3:PutObject"]
    # Grant only access to the object 
    resources = ["${aws_s3_bucket.s3_bucket.arn}/terminals.json"]
  }
}

# Role used by GHA
resource "aws_iam_role" "gha_role" {
  name               = "gha-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

resource "aws_iam_policy" "policy" {
  name        = "gha-role-s3-access-policy"
  description = "Grant access to put object on key for s3 bucket"
  policy      = data.aws_iam_policy_document.gha_iam_policy.json
}

resource "aws_iam_role_policy_attachment" "gha_role_policy_attachment" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.gha_role.name
}
