resource "aws_autoscaling_group" "app_asg" {
  name                      = "iac-app-asg"
  vpc_zone_identifier       = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "IAC-App-Instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "IAC-Terraform-AWS"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "iac-cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
