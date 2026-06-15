data "aws_caller_identity" "current" {}

# Generate a random suffix for a unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "aws-cloudtrail-logs-root-alert-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "CloudTrail S3 Bucket"
    Environment = "Homework3"
  }
}

# Block all public access to the S3 bucket (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket_access" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Create CloudWatch Logs Group to receive CloudTrail logs
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/root-login-trail"
  retention_in_days = 7

  tags = {
    Name        = "CloudTrail CloudWatch Logs Group"
    Environment = "Homework3"
  }
}

# IAM Role to allow CloudTrail to write logs to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_to_cloudwatch_role" {
  name = "cloudtrail-to-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy to allow writing logs
resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch_policy" {
  name = "cloudtrail-to-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_to_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
      }
    ]
  })
}

# Enable CloudTrail & Send Logs to CloudWatch Logs Group (Step 1)
resource "aws_cloudtrail" "root_login_trail" {
  name                          = "root-login-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cloudwatch_role.arn
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_policy,
    aws_iam_role_policy.cloudtrail_to_cloudwatch_policy
  ]
}

# Create CloudWatch Metric Filter (Step 2)
resource "aws_cloudwatch_log_metric_filter" "root_login_filter" {
  name           = "RootAccountLoginMetricFilter"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name          = "RootAccountLoginCount"
    namespace     = "Security"
    value         = "1"
    default_value = 0 # Ensures that a 0 is recorded when no root logins occur
  }
}

# Create CloudWatch Alarm (Step 3)
resource "aws_cloudwatch_metric_alarm" "root_login_alarm" {
  alarm_name          = "RootAccountLoginAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.root_login_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.root_login_filter.metric_transformation[0].namespace
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm if RootAccountLoginCount >= 1 in any 5-minute period. Any single root login will trigger this."
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.root_login_topic.arn]
  ok_actions    = var.enable_recovery_notification ? [aws_sns_topic.root_login_topic.arn] : []
}

# Notify via SNS - Create SNS Topic (Step 4)
resource "aws_sns_topic" "root_login_topic" {
  name         = "root-login-alarm-topic"
  display_name = "AWS Root Login Alert"
}

# SNS Action - Email Subscription
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.root_login_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Action - SMS Subscription (Optional)
resource "aws_sns_topic_subscription" "sms_subscription" {
  count     = var.alert_phone_number != "" ? 1 : 0
  topic_arn = aws_sns_topic.root_login_topic.arn
  protocol  = "sms"
  endpoint  = var.alert_phone_number
}
