data "aws_iam_policy_document" "test_dlm_lifecycle_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "test_dlm_lifecycle_role" {
  name               = "TestDlmLifecycleRole"
  assume_role_policy = "${data.aws_iam_policy_document.test_dlm_lifecycle_role.json}"
}

data "aws_iam_policy_document" "test_dlm_lifecycle" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateSnapshot", "ec2:DeleteSnapshot", "ec2:DescribeVolumes", "ec2:DescribeSnapshots"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*::snapshot/*"]
  }
}

resource "aws_iam_role_policy" "test_dlm_lifecycle" {
  name   = "testdlm-lifecycle-policy"
  role   = "${aws_iam_role.test_dlm_lifecycle_role.id}"
  policy = "${data.aws_iam_policy_document.test_dlm_lifecycle.json}"
}

resource "aws_dlm_lifecycle_policy" "test_dlm_lifecycle_policy" {
  description        = "DLM lifecycle policy"
  execution_role_arn = "${aws_iam_role.test_dlm_lifecycle_role.arn}"
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "daily snapshots in last week"

      create_rule {
        interval = 2
        #interval      = 24
        interval_unit = "HOURS"
        times         = ["18:00"] # UTC(JSTの3-4時を想定)
      }

      retain_rule {
        count = 7 # 保持するスナップショットの最大数
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
      }

      copy_tags = true
    }

    target_tags = {
      Snapshot = "true"
    }
  }
}
