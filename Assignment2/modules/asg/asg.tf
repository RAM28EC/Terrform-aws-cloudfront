
#resource "aws_secretsmanager_secret" "webapp_secrets" {
#  name = "webapp_secrets"
#}

# Add the sensitive information to the secret
#resource "aws_secretsmanager_secret_version" "webapp_secrets_version" {
#  secret_id     = aws_secretsmanager_secret.webapp_secrets.id
#  secret_string = jsonencode({
#    "AWS_ACCESS_KEY_ID"     = var.aws_access_key_id,
 #   "AWS_SECRET_ACCESS_KEY" = var.aws_secret_access_key,
 #   "S3_BUCKET_NAME"        = var.s3_bucket_name,
 #   "AWS_REGION"            = var.aws_region,
  #})
#}
resource "aws_launch_template" "lt_name" {
  name          = "${var.project_name}-tpl"
  image_id      = "ami-07d9b9ddc6cd8dd30"
  instance_type = "t2.micro"
  key_name      = "prodios"
  user_data     = filebase64("../modules/asg/config.sh")


  vpc_security_group_ids = [var.client_sg_id]
  tags = {
    Name = "${var.project_name}-tpl"
  }
}

resource "aws_autoscaling_group" "asg_name" {

  name                      = "${var.project_name}-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 2
  health_check_grace_period = 300
  health_check_type         = "ELB" #"ELB" or default EC2
  vpc_zone_identifier = [var.pri_sub_3a_id,var.pri_sub_4b_id]
  target_group_arns   = [var.tg_arn] #var.target_group_arns

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  launch_template {
    id      = aws_launch_template.lt_name.id
    version = aws_launch_template.lt_name.latest_version 
  }
}

# scale up policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-asg-scale-up"
  autoscaling_group_name = aws_autoscaling_group.asg_name.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1" #increasing instance by 1 
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

# scale up alarm
# alarm will trigger the ASG policy (scale/down) based on the metric (CPUUtilization), comparison_operator, threshold
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.project_name}-asg-scale-up-alarm"
  alarm_description   = "asg-scale-up-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70" # New instance will be created once CPU utilization is higher than 30 %
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.asg_name.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_up.arn]
}

# scale down policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-asg-scale-down"
  autoscaling_group_name = aws_autoscaling_group.asg_name.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1" # decreasing instance by 1 
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

# scale down alarm
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.project_name}-asg-scale-down-alarm"
  alarm_description   = "asg-scale-down-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5" # Instance will scale down when CPU utilization is lower than 5 %
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.asg_name.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_down.arn]
}





# IAM Role for EC2 Instance
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect    = "Allow",
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for EC2 Instance
resource "aws_s3_bucket" "example" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}
resource "aws_iam_policy" "s3_policy" {
  name        = "s3_policy"
  description = "Allows EC2 instances to access S3 bucket"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
        Effect    = "Allow"
        Action    = ["s3:GetObject", "s3:PutObject"]
        Resource  = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
      },
      {
        Sid       = "StateBucketObjectAccess"
        Effect    = "Allow"
        Action    = ["s3:PutObjectAcl", "s3:PutObject", "s3:GetObject"]
        Resource  = "arn:aws:s3:::${var.s3_bucket_name}/992382640915/*"
      },
      
      {
        Sid       = "StateBucketList"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = "arn:aws:s3:::${var.s3_bucket_name}"
        Condition = {
          StringLike = {
            "s3:prefix" = ["992382640915/*"]
          }
        }
      },
      #{
      #  Sid       = "DynamoDBAccess"
      #  Effect    = "Allow"
      #  Action    = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem"]
      #  Resource  = "arn:aws:dynamodb:us-east-1:92382640915:table/remote-backend"
      #}
    ]
  })
}


# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "s3_attach" {
  policy_arn = aws_iam_policy.s3_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance_profile1"

  role = aws_iam_role.ec2_role.name
}
