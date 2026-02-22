output "autoscaling_target_id" {
  value = aws_appautoscaling_target.this.id
}

output "autoscaling_policy_arn" {
  value = aws_appautoscaling_policy.cpu.arn
}
