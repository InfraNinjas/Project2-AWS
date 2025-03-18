variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnets_count" {
  description = "Number of subnets to make"
  type        = number
  default     = 2
}

variable "on_premise_public_ip" {
  description = "Public ip"
  type        = string
}

variable "on_premise_cidr_block" {
  description = "On-premise CIDR block"
  type        = string
  default     = "192.168.20.0/24"
}


variable "ocp_cluster_name" {
  description = "Name of Openshift cluster"
  type        = string
  default     = "okd4"
}

variable "ocp_domain_name" {
  description = "Domain name of Openshift cluster"
  type        = string
  default     = "cluster.local"
}

variable "ocp_lb_ip" {
  description = "IP of Openshift Internal API server"
  type        = string
  default     = "192.168.20.1"
}
