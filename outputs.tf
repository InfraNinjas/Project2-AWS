output "cluster_name" {
  description = "Name of EKS Cluster"
  value       = module.eks.cluster_name
}

output "tunnel1_preshared_key" {
  value = nonsensitive(aws_vpn_connection.aws_on_premise.tunnel1_preshared_key)
}

output "tunnel1_address" {
  value = aws_vpn_connection.aws_on_premise.tunnel1_address
}
