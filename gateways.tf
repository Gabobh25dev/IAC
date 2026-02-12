resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "IAC-Internet-Gateway"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "IAC-NAT-EIP"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "IAC-NAT-Gateway"
  }

  depends_on = [aws_internet_gateway.main]
}
