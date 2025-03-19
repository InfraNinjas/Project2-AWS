# output "cluster_name" {
#   description = "Name of EKS Cluster"
#   value       = module.eks.cluster_name
# }

# output "tunnel1_preshared_key" {
#   value = nonsensitive(aws_vpn_connection.aws_on_premise.tunnel1_preshared_key)
# }

# output "tunnel1_address" {
#   value = aws_vpn_connection.aws_on_premise.tunnel1_address
# }

#
# RDS
#
# output "db_address" {
#   value = aws_db_instance.myDB.address
# }

#
# WAF
#
output "eks_host" {
  value = module.eks.cluster_endpoint

  depends_on = [module.eks]
}

output "eks_ca_cert" {
  value = module.eks.cluster_certificate_authority_data

  depends_on = [module.eks]
}

output "eks_name" {
  value = module.eks.cluster_name

  depends_on = [module.eks]
}

output "LB_arn" {
  value = aws_wafv2_web_acl.test-waf-acl.arn
}