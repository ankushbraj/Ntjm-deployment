##################################################################################
# Test env with a single instance
##################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
    region = var.region
}


provider "consul" {
  address    = "${var.consul_address}:${var.consul_port}"
  datacenter = var.consul_datacenter
}

# Create a VPC
resource "aws_vpc" "NtjmVPC1" {
  cidr_block = "10.1.0.0/16"

    tags = {
    Name = "NtjmVPC1"
  }

}

resource "aws_subnet" "NtjmSubnetA1" {
  vpc_id     = aws_vpc.NtjmVPC1.id
  cidr_block = "10.1.0.0/24"
  availability_zone = "eu-central-1a"

    tags = {
    Name = "NtjmSubnetA1"
  }
}

resource "aws_subnet" "NtjmSubnetB1" {
  vpc_id     = aws_vpc.NtjmVPC1.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "eu-central-1b"

      tags = {
    Name = "NtjmSubnetB1"
  }
}

resource "aws_internet_gateway" "NtjmIGW1" {
  vpc_id = aws_vpc.NtjmVPC1.id

      tags = {
    Name = "NtjmIGW1"
  }
}

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.NtjmSubnetA1.id
    route_table_id = aws_route_table.NtjmRouteTable1.id
}

resource "aws_route_table_association" "b" {
    subnet_id = aws_subnet.NtjmSubnetB1.id
    route_table_id = aws_route_table.NtjmRouteTable1.id
}

resource "aws_route_table" "NtjmRouteTable1" {
    vpc_id = aws_vpc.NtjmVPC1.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.NtjmIGW1.id
    }

        tags = {
    Name = "NtjmRouteTable1"
  }
}

resource "aws_security_group" "NtjmServer1" {
  name        = "Allow Web traffic"
  description = "Allow Web traffic"
  vpc_id = aws_vpc.NtjmVPC1.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.albsg1.id]
  } 

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "NtjmServer1"
  }
}

/*
resource "aws_instance" "test-iac" {
  ami           = "ami-0de9f803fcac87f46"
  instance_type = "t2.micro"
  availability_zone = "eu-central-1a"
  key_name = "ankush"
  vpc_security_group_ids = [ aws_security_group.NtjmServer1.id ]
  subnet_id = aws_subnet.NtjmSubnetA1.id
  associate_public_ip_address = true
  user_data = <<-EOF
                #!/bin/bash
                sudo yum install git -y
                sudo yum install python-pip -y
                git clone https://github.com/komarserjio/notejam.git
                cd notejam/flask/
                sudo pip install -r requirements.txt
                echo 'from notejam import app' >> rserver.py
                echo 'app.run(host="0.0.0.0",port=80)' >> rserver.py
                chmod +x rserver.py
                sudo python rserver.py
                EOF


       tags = {
    Name = "test-iac"
  }           
      
}

*/

resource "aws_security_group" "albsg1" {
  name        = "albsg1"
  description = "albsg1"
  vpc_id = aws_vpc.NtjmVPC1.id


   ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "albsg1"
  }
}

resource "aws_lb" "NtjmALB1" {
  name               = "NtjmALB1"
  load_balancer_type = "application"
  subnets            = [aws_subnet.NtjmSubnetA1.id, aws_subnet.NtjmSubnetB1.id]
  security_groups    = [aws_security_group.albsg1.id]
  enable_cross_zone_load_balancing = true

}

resource "aws_lb_listener" "NtjmALBlist1" {
  load_balancer_arn = aws_lb.NtjmALB1.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Ntjmtg1.arn
  }
}


resource "aws_lb_target_group" "Ntjmtg1" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.NtjmVPC1.id

  load_balancing_algorithm_type = "least_outstanding_requests"

  stickiness {
    enabled = true
    type    = "lb_cookie"
  }

  health_check {
    healthy_threshold   = 2
    interval            = 30
    protocol            = "HTTP"
    unhealthy_threshold = 2
    path = "/signin/?next=%2F"
  }
}





resource "aws_launch_configuration" "NtjmLC" {
  name_prefix   = "NtjmLC"
  image_id      = "ami-0de9f803fcac87f46"
  instance_type = "t2.micro"
  key_name = "ankush"

  security_groups = [ aws_security_group.NtjmServer1.id ]
  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash
                sudo yum install git -y
                sudo yum install python-pip -y
                git clone https://github.com/komarserjio/notejam.git
                cd notejam/flask/
                sudo pip install -r requirements.txt
                echo 'from notejam import app' >> rserver.py
                echo 'app.run(host="0.0.0.0",port=80)' >> rserver.py
                chmod +x rserver.py
                sudo python rserver.py
                EOF

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "NtjmASG" {
  name = "NtjmASG"

  max_size              = 2
  min_size              = 1
  desired_capacity      = 1

  
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true

  #load_balancers            = [aws_lb.NtjmALB1.id]

  launch_configuration = aws_launch_configuration.NtjmLC.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [aws_subnet.NtjmSubnetA1.id, aws_subnet.NtjmSubnetB1.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "ASG"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_attachment" "target" {
  autoscaling_group_name = aws_autoscaling_group.NtjmASG.id
  alb_target_group_arn   = aws_lb_target_group.Ntjmtg1.arn
}


resource "aws_autoscaling_policy" "NtjmASGP" {
  name                   = "NtjmASGP"
  scaling_adjustment     = 4
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.NtjmASG.name
}

resource "aws_cloudwatch_metric_alarm" "NtjmCW" {
  alarm_name          = "NtjmCW"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.NtjmASG.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.NtjmASGP.arn]
}


output "NTJM_test_dns_name" {
  description = "The DNS name of the load balancer."
  value       = concat(aws_lb.NtjmALB1.*.dns_name, [""])[0]
}