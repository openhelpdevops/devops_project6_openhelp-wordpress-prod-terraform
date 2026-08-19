data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "wordpress" {
  name               = "${var.project_name}-${var.environment}-wordpress-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.wordpress.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.wordpress.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "wordpress_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_secretsmanager_secret.wordpress_db.arn]
  }
}

resource "aws_iam_role_policy" "wordpress_secrets" {
  name   = "${var.project_name}-${var.environment}-wordpress-secrets"
  role   = aws_iam_role.wordpress.id
  policy = data.aws_iam_policy_document.wordpress_secrets.json
}

resource "aws_iam_instance_profile" "wordpress" {
  name = "${var.project_name}-${var.environment}-wordpress-profile"
  role = aws_iam_role.wordpress.name
}
