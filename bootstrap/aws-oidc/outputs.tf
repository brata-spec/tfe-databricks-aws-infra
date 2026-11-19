output "plan_role_arn" {
  description = "Already wired by tfe/ into variable set dpl-aws-<env> (TFC_AWS_PLAN_ROLE_ARN)"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Already wired by tfe/ into variable set dpl-aws-<env> (TFC_AWS_APPLY_ROLE_ARN)"
  value       = aws_iam_role.apply.arn
}

output "trusted_subjects" {
  value = [for scope in local.sub_scope : "${scope}:run_phase:{plan,apply}"]
}
