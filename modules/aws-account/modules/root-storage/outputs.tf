output "bucket_name" {
  value      = aws_s3_bucket.this.bucket
  depends_on = [aws_s3_bucket_policy.this]
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
