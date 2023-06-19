terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "default"
}

resource "aws_iam_policy" "s3-policy" {
  name = "shimao-s3-access-role-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.my_bucket_name}/*"
      },
      {
        Action = [
          "s3:GetBucketPublicAccessBlock",
          "s3:ListBucket",
          "s3:GetBucketLocation"

        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.my_bucket_name}"
      },
    ]
  })
}

resource "aws_iam_role" "access-role" {
  name = "shimao-demo-s3-access-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "S3-polisy_attach" {
  role       = aws_iam_role.access-role.name
  policy_arn = aws_iam_policy.s3-policy.arn
}

output "role_name" {
  value = aws_iam_role.access-role.name
}
