# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

