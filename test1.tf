

# Create a VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Demo VPC"
  }
}

# Create Web Public Subnet
resource "aws_subnet" "web-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.1.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-1a"
  }
}

resource "aws_subnet" "web-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-2b"
  }
}

# Create Application Private Subnet
resource "aws_subnet" "application-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "Application-1a"
  }
}

resource "aws_subnet" "application-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.1.3.0/24"
  availability_zone       = "us-east-1b"

  tags = {
    Name = "Application-2b"
  }
}

  


# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "Demo IGW"
  }
}

# Create Web layber route table
resource "aws_route_table" "web-rt" {
  vpc_id = aws_vpc.my-vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "WebRT"
  }
}

# Create Web Subnet association with Web route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-subnet-1.id
  route_table_id = aws_route_table.web-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.web-subnet-2.id
  route_table_id = aws_route_table.web-rt.id
}

#Create Public EC2 Instance
resource "aws_instance" "pubserver1" {
  ami                    = "ami-000db10762d0c4c05"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.application-subnet-1.id
  user_data              = file("install_apache.sh")

  tags = {
    Name = "Web Server"
  }

}

# Creating the autoscaling launch configuration that contains AWS EC2 instance details
resource "aws_launch_configuration" "aws_autoscale_conf" {
# Defining the name of the Autoscaling launch configuration
  name          = "web_config"
# Defining the image ID of AWS EC2 instance
  image_id      = "ami-000db10762d0c4c05"
# Defining the instance type of the AWS EC2 instance
  instance_type = "t2.micro"
# Defining the Key that will be used to access the AWS EC2 instance
  key_name = "automateinfra"
# Script
 user_data              = file("install_apache.sh")
}

# Creating the autoscaling group within us-east-1a availability zone
resource "aws_autoscaling_group" "mygroup" {
 vpc_security_group_ids = [application-sg.id]
  subnet_id              = [aws_subnet.application-subnet-1.id] [aws_subnet.application-subnet-2.id]
  availability_zones        = ["us-east-1a"] ["us-east-1b"]
# Specifying the name of the autoscaling group
  name                      = "autoscalegroup"
# Defining the maximum number of AWS EC2 instances while scaling
  max_size                  = 6
# Defining the minimum number of AWS EC2 instances while scaling
  min_size                  = 2
# Grace period is the time after which AWS EC2 instance comes into service before checking health.
  health_check_grace_period = 30
# The Autoscaling will happen based on health of AWS EC2 instance defined in AWS CLoudwatch Alarm 
  health_check_type         = "EC2"
# force_delete deletes the Auto Scaling Group without waiting for all instances in the pool to terminate
  force_delete              = true
# Defining the termination policy where the oldest instance will be replaced first 
  termination_policies      = ["OldestInstance"]
# Scaling group is dependent on autoscaling launch configuration because of AWS EC2 instance configurations
  launch_configuration      = aws_launch_configuration.aws_autoscale_conf.name
}
# Creating the autoscaling schedule of the autoscaling group

resource "aws_autoscaling_schedule" "mygroup_schedule" {
  scheduled_action_name  = "autoscalegroup_action"
# The minimum size for the Auto Scaling group
  min_size               = 2
# The maxmimum size for the Auto Scaling group
  max_size               = 6
# Desired_capacity is the number of running EC2 instances in the Autoscaling group
  desired_capacity       = 2
# defining the start_time of autoscaling if you think traffic can peak at this time.
  start_time             = "2022-02-09T18:00:00Z"
  autoscaling_group_name = aws_autoscaling_group.mygroup.name
}

# Creating the autoscaling policy of the autoscaling group
resource "aws_autoscaling_policy" "mygroup_policy" {
  name                   = "autoscalegroup_policy"
# The number of instances by which to scale.
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
# The amount of time (seconds) after a scaling completes and the next scaling starts.
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.mygroup.name
}
# Creating the AWS CLoudwatch Alarm that will autoscale the AWS EC2 instance based on CPU utilization.
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
# defining the name of AWS cloudwatch alarm
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
# Defining the metric_name according to which scaling will happen (based on CPU) 
  metric_name = "CPUUtilization"
# The namespace for the alarm's associated metric
  namespace = "AWS/EC2"
# After AWS Cloudwatch Alarm is triggered, it will wait for 60 seconds and then autoscales
  period = "60"
  statistic = "Average"
# CPU Utilization threshold is set to 10 percent
  threshold = "10"
  alarm_actions = [
        "${aws_autoscaling_policy.mygroup_policy.arn}"
    ]
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.mygroup.name}"
  }
}

#Create EC2 Instance


resource "aws_instance" "webserver2" {
  ami                    = "ami-0f095f89ae15be883"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1b"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-2.id
  user_data              = file("install_apache.sh")

  tags = {
    Name = "Web Server"
  }

}

# Create Web Security Group
resource "aws_security_group" "web-sg" {
  name        = "Web-SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }


# Create Application Security Group
resource "aws_security_group" "application-sg" {
  name        = "Application-SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver-sg.id]
  }

  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Application-SG"
  }
}

resource "aws_lb" "external-elb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]
}

resource "aws_lb_target_group" "external-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = mygroup.id
  port             = 80

  
}


resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}


}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.external-elb.dns_name
}

resource "aws_s3_bucket" "logs" {
    bucket  = "coalfire"
    acl     = "private"
    lifecycle_rule {
        id      = "quarterly_retention"
        prefix  = "logs/"
        enabled = true

        expiration {
            days = 92
        }
    }
}

resource "aws_s3_bucket" "images" {
    bucket  = "coalfire"
    acl     = "private"
    lifecycle_rule {
        id      = "permanent_retention"
        enabled = true
        prefix  = "images/"

        transition {
            days            = 90
            storage_class   = "GLACIER"
        }
    }

