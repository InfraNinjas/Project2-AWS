
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
# Private , Public 서브넷 구성
######################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = var.subnets_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.${count.index + 1}0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "AWS-public${count.index + 1}-SN"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "private" {
  count = var.subnets_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.1${count.index + 1}0.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "AWS-private${count.index + 1}-SN"
  }
}

resource "aws_subnet" "db" {
  count = var.subnets_count
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
  count = var.subnets_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

######################################
# 라우팅 테이블 생성 (Private)
######################################
resource "aws_route_table" "private" {
  count = var.subnets_count
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-private${count.index + 1}-RT"
  }
}
resource "aws_route_table_association" "private_association" {
  count = var.subnets_count
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
  count = var.subnets_count
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
  count = var.subnets_count
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
  count = var.subnets_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
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
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
