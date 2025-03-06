
######################################
# VPC 구성
######################################

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "AWS-VPC"
  }
}


######################################
# Private , Public 서브넷 구성
######################################
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.0.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "AWS-public1-SN"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.10.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "AWS-public2-SN"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.100.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "AWS-private1-SN"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.110.0/24"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "AWS-private2-SN"
  }
}

resource "aws_subnet" "private3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.120.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "AWS-private3-SN"
  }
}

resource "aws_subnet" "private4" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.130.0/24"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "AWS-private4-SN"
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
resource "aws_route_table" "public_rt" {
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
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public2_association" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}

######################################
# 라우팅 테이블 생성 (Private)
######################################
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-private-RT"
  }
}
resource "aws_route_table_association" "private1_association" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private_rt.id
}


resource "aws_route_table" "private2_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-private2-RT"
  }
}

resource "aws_route_table_association" "private2_association" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2_rt.id
}



resource "aws_route_table" "private_db_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "AWS-DB-RT"
  }
}

resource "aws_route_table_association" "private3_association" {
  subnet_id      = aws_subnet.private3.id
  route_table_id = aws_route_table.private_db_rt.id
}

resource "aws_route_table_association" "private4_association" {
  subnet_id      = aws_subnet.private4.id
  route_table_id = aws_route_table.private_db_rt.id
}


######################################
# NAT Gateway 생성 (Private, Private2)
######################################

# Elastic IP 생성 (NAT Gateway용)
resource "aws_eip" "nat_eip1" {
  tags = {
    Name = "AWS-NAT-EIP1"
  }
}

resource "aws_eip" "nat_eip2" {
  tags = {
    Name = "AWS-NAT-EIP2"
  }
}

# NAT Gateway 생성 (Private RT용)
resource "aws_nat_gateway" "nat_gw1" {
  allocation_id = aws_eip.nat_eip1.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "AWS-NAT-GW1"
  }
}

# NAT Gateway 생성 (Private2 RT용)
resource "aws_nat_gateway" "nat_gw2" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.public2.id

  tags = {
    Name = "AWS-NAT-GW2"
  }
}

######################################
# Private 라우팅 테이블 업데이트
######################################

# Private RT에 NAT Gateway 연결
resource "aws_route" "private_rt_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw1.id
}

# Private2 RT에 NAT Gateway 연결
resource "aws_route" "private2_rt_nat_route" {
  route_table_id         = aws_route_table.private2_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw2.id
}


######################################
# EKS 클러스터 생성 (Auto Mode 활성화)
######################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "AWS-cluster"
  cluster_version = "1.31"

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






