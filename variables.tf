variable "vpc_cidr" {
  description = "CIDR for VPC"
  type = string
  default = "10.10.0.0/16"
}

variable "subnets_count" {
  description = "Number of subnets to make"
  type = number
  default = 2
}
