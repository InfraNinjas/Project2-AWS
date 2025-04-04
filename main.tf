
######################################
# VPC 구성
######################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "AWS-VPC"
  }
}

######################################
# Route53 프라이빗 호스팅 존 생성
######################################

# Route53 프라이빗 존 생성
resource "aws_route53_zone" "int_dns" {
  name = "${var.ocp_cluster_name}.${var.ocp_domain_name}"
  vpc {
    vpc_id     = aws_vpc.main.id
    vpc_region = "ap-northeast-2"
  }

  tags = {
    Name = "${var.ocp_domain_name}"
  }
}

# Internal API DNS 레코드 생성
resource "aws_route53_record" "internal_api_server_record_api" {
  zone_id = aws_route53_zone.int_dns.zone_id
  name    = "api.${var.ocp_cluster_name}.${var.ocp_domain_name}"

  type    = "A"
  ttl     = 300
  records = [var.ocp_lb_ip]
}

# Internal APPS DNS 레코드 생성
resource "aws_route53_record" "internal_apps_server_record_api" {
  zone_id = aws_route53_zone.int_dns.zone_id
  name    = "*.apps.${var.ocp_cluster_name}.${var.ocp_domain_name}"

  type    = "A"
  ttl     = 300
  records = [var.ocp_lb_ip]
}

######################################
# Private , Public 서브넷 구성
######################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = var.subnets_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.${count.index + 1}0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                     = "AWS-public${count.index + 1}-SN"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "private" {
  count             = var.subnets_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.1${count.index + 1}0.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "AWS-private${count.index + 1}-SN"
  }
}

resource "aws_subnet" "db" {
  count             = var.subnets_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.2${count.index + 1}0.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "AWS-db${count.index + 1}-SN"
  }
}

######################################
# IGW 생성
######################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-IGW"
  }
}

######################################
# 라우팅 테이블 생성 (Public)
######################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "AWS-public-RT"
  }
}

resource "aws_route_table_association" "public1_association" {
  count          = var.subnets_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

######################################
# 라우팅 테이블 생성 (Private)
######################################
resource "aws_route_table" "private" {
  count  = var.subnets_count
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-private${count.index + 1}-RT"
  }
}
resource "aws_route_table_association" "private_association" {
  count          = var.subnets_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}


resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-DB-RT"
  }
}

resource "aws_route_table_association" "db_association" {
  count          = var.subnets_count
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}


######################################
# NAT Gateway 생성 (Private, Private2)
######################################

# Elastic IP 생성 (NAT Gateway용)
resource "aws_eip" "nat_eip" {
  count = var.subnets_count

  tags = {
    Name = "AWS-NAT-EIP${count.index + 1}"
  }
}

# NAT Gateway 생성 (Private RT용)
resource "aws_nat_gateway" "nat_gw" {
  count         = var.subnets_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "AWS-NAT-GW${count.index + 1}"
  }
}

######################################
# Private 라우팅 테이블 업데이트
######################################

# Private RT에 NAT Gateway 연결
resource "aws_route" "private_rt_nat_route" {
  count                  = var.subnets_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

######################################
# VPN 설정
######################################

# VPN Gateway 생성
resource "aws_vpn_gateway" "aws_vpn_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "On-premise-VPNGW"
  }
}

# VPN 고객 게이트웨이 생성
resource "aws_customer_gateway" "on_premise" {
  bgp_asn    = 65000
  ip_address = var.on_premise_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "On-premise-CGW"
  }
}

# VPN 연결 설정
resource "aws_vpn_connection" "aws_on_premise" {
  vpn_gateway_id      = aws_vpn_gateway.aws_vpn_gw.id
  customer_gateway_id = aws_customer_gateway.on_premise.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "On-premise-VPN-CON"
  }
}

resource "aws_vpn_connection_route" "on_premise" {
  destination_cidr_block = var.on_premise_cidr_block
  vpn_connection_id      = aws_vpn_connection.aws_on_premise.id
}

locals {
  route_table_ids = concat(aws_route_table.public[*].id, aws_route_table.private[*].id, aws_route_table.db[*].id)
}

resource "aws_vpn_gateway_route_propagation" "vpn" {
  count          = length(local.route_table_ids)
  vpn_gateway_id = aws_vpn_gateway.aws_vpn_gw.id
  route_table_id = local.route_table_ids[count.index]
}

######################################
# EKS 보안그룹 생성
######################################

resource "aws_security_group" "allow_on_premise" {
  name        = "allow_on_premise"
  description = "Allow all inbound traffic and all outbound traffic from on-premise"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow_on_premise"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_on_premise" {
  security_group_id = aws_security_group.allow_on_premise.id
  cidr_ipv4         = var.on_premise_cidr_block
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_on_premise" {
  security_group_id = aws_security_group.allow_on_premise.id
  cidr_ipv4         = var.on_premise_cidr_block
  ip_protocol       = "-1"
}

######################################
# EKS 클러스터 생성 (Auto Mode 활성화)
######################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "AWS-cluster"
  cluster_version = "1.31"

  bootstrap_self_managed_addons = false

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  cluster_addons = {
    metrics-server = {}
  }

  # Cluster endpoint public access 설정
  cluster_endpoint_public_access = true

  # Cluster creator admin permissions 활성화
  enable_cluster_creator_admin_permissions = true

  # Compute config for Auto Mode
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  # VPC 및 서브넷 연결
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  cluster_additional_security_group_ids = [aws_security_group.allow_on_premise.id]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

######################################
# RDS 생성
######################################
# 보안 그룹 생성
resource "aws_security_group" "allow_db" {
  name        = "allow_db"
  description = "Allow 3306/TCP inbound traffic and all outbound traffic"
  vpc_id      = data.aws_vpc.selected.id

  tags = {
    Name = "allow_db"
  }
}

# vpc 보안 그룹 내부 규칙 생성
resource "aws_vpc_security_group_ingress_rule" "allow_db" {
  security_group_id = aws_security_group.allow_db.id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

# vpc 보안 그룹 외부 규칙 생성
resource "aws_vpc_security_group_egress_rule" "allow_db" {
  security_group_id = aws_security_group.allow_db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# VPC 지정
data "aws_vpc" "selected" {
  id = aws_vpc.main.id
}

# db 서브넷 지정
resource "aws_db_subnet_group" "my-db-sg" {
  name       = "my-db-sg"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "My DB subnet group"
  }
}

# DB 생성
resource "aws_db_instance" "myDB" {
  allocated_storage    = 10
  db_name              = var.db_name
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  db_subnet_group_name   = aws_db_subnet_group.my-db-sg.name
  vpc_security_group_ids = [aws_security_group.allow_db.id]
}

######################################
# WAF 구성
######################################
# waf acl 생성
resource "aws_wafv2_web_acl" "test-waf-acl" {
  name        = "managed-rule-test-waf-acl"
  description = "test-waf-acl of a managed rule."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "YelbWAFAclMetrics"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
}
