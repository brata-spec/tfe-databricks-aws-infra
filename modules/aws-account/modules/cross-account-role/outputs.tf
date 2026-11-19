output "role_arn" {
  description = "Ready to register (waits for IAM propagation)"
  value       = aws_iam_role.this.arn
  depends_on  = [time_sleep.propagation]
}
