output "s3_bucket_name" {
  description = "The name of the S3 bucket where CloudTrail logs are stored"
  value       = aws_s3_bucket.cloudtrail_bucket.id
}

output "cloudtrail_arn" {
  description = "The ARN of the CloudTrail"
  value       = aws_cloudtrail.root_login_trail.arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group receiving CloudTrail logs"
  value       = aws_cloudwatch_log_group.cloudtrail_logs.name
}

output "sns_topic_arn" {
  description = "The ARN of the SNS Topic for alerts"
  value       = aws_sns_topic.root_login_topic.arn
}

output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch Alarm for root logins"
  value       = aws_cloudwatch_metric_alarm.root_login_alarm.arn
}
