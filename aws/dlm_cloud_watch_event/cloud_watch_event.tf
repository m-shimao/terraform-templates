# SSM Automation用のIAM Role
data "aws_iam_policy_document" "test_ssm_automation_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "test_ssm_automation" {
  name               = "TestSSMautomation"
  assume_role_policy = "${data.aws_iam_policy_document.test_ssm_automation_trust.json}"
}

# SSM Automation用のIAM RoleにPolicy付与
resource "aws_iam_role_policy_attachment" "ssm-automation-atach-policy" {
  role       = "${aws_iam_role.test_ssm_automation.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

data "aws_iam_policy_document" "test_ssm_automation" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["${aws_iam_role.test_ssm_automation.arn}"]
  }
}

resource "aws_iam_role_policy" "test_ssm_automation" {
  name   = "TestSSMautomation"
  role   = "${aws_iam_role.test_ssm_automation.id}"
  policy = "${data.aws_iam_policy_document.test_ssm_automation.json}"
}

# CloudWatchイベント用のIAM Role
data "aws_iam_policy_document" "event_invoke_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "event_invoke_assume_role" {
  name               = "testCloudWatchEventRole"
  assume_role_policy = "${data.aws_iam_policy_document.event_invoke_assume_role.json}"
}


# CloudWatchイベント用のIAM RoleにPolicy付与
data "aws_caller_identity" "self" {}

data "aws_iam_policy_document" "event_invoke_policy" {
  statement {
    effect  = "Allow"
    actions = ["ssm:StartAutomationExecution"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.self.account_id}:automation-definition/AWS-StartEC2Instance:*",
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.self.account_id}:automation-definition/AWS-StopEC2Instance:*",
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["${aws_iam_role.test_ssm_automation.arn}"]

    condition {
      test     = "StringLikeIfExists"
      variable = "iam:PassedToService"
      values   = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "event_invoke_policy" {
  name   = "testCloudWatchEventPolicy"
  role   = "${aws_iam_role.event_invoke_assume_role.id}"
  policy = "${data.aws_iam_policy_document.event_invoke_policy.json}"
}

# CloudWatchイベント - EC2の定時起動
resource "aws_cloudwatch_event_rule" "start_test_ec2_rule" {
  name                = "StartInstanceRule"
  description         = "Start instances after batch execution."
  schedule_expression = "cron(0 22 * * ? *)"
}

resource "aws_cloudwatch_event_target" "start_test_instance" {
  target_id = "StartInstanceTarget"
  arn       = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.self.account_id}:automation-definition/AWS-StartEC2Instance"
  rule      = "${aws_cloudwatch_event_rule.start_test_ec2_rule.name}"
  role_arn  = "${aws_iam_role.event_invoke_assume_role.arn}"

  input = <<DOC
{
  "InstanceId": ["${aws_instance.test_instance.id}"],
  "AutomationAssumeRole": ["${aws_iam_role.test_ssm_automation.arn}"]
}
DOC
}

# CloudWatchイベント - EC2の定時停止
resource "aws_cloudwatch_event_rule" "stop_test_ec2_rule" {
  name                = "StopInstanceRule"
  description         = "Stop instances after batch execution."
  schedule_expression = "cron(0 10 * * ? *)"
}

resource "aws_cloudwatch_event_target" "stop-test-instance" {
  target_id = "StopInstanceTarget"
  arn       = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.self.account_id}:automation-definition/AWS-StopEC2Instance"
  rule      = "${aws_cloudwatch_event_rule.stop_test_ec2_rule.name}"
  role_arn  = "${aws_iam_role.event_invoke_assume_role.arn}"

  input = <<DOC
{
  "InstanceId": ["${aws_instance.test_instance.id}"],
  "AutomationAssumeRole": ["${aws_iam_role.test_ssm_automation.arn}"]
}
DOC
}
