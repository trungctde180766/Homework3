variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "ap-southeast-1"
}

variable "alert_email" {
  type        = string
  description = "The email address to subscribe to the SNS topic for AWS Root Login alerts"
}

variable "alert_phone_number" {
  type        = string
  description = "Optional phone number to receive SMS alerts (e.g., +84987654321). Leaving it empty will skip SMS subscription."
  default     = ""
}

variable "enable_recovery_notification" {
  type        = bool
  description = "Enable notification when the system recovers back to OK state"
  default     = true
}
