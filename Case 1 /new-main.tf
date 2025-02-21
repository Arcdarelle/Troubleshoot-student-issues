# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a docker-lab VPC
resource "aws_vpc" "docker-lab_vpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "docker-lab-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.docker-lab_vpc.id
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.docker-lab_vpc.id

  tags = {
    Name = "docker-lab-igw"
  }
}

# Create a route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.docker-lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create Web Security Group
resource "aws_security_group" "web_sg" {
  name        = "docker-Web-SG"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.docker-lab_vpc.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow app traffic"
    from_port   = 8000
    to_port     = 8100
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
    Name = "docker-Web-SG"
  }
}

# Generate a secure private key
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS key pair
resource "aws_key_pair" "ec2_key" {
  key_name   = "docker-keypair"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Save private key to a local file
resource "local_file" "ssh_key" {
  filename        = "${aws_key_pair.ec2_key.key_name}.pem"
  content         = tls_private_key.ec2_key.private_key_pem
  file_permission = "400"
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"]
}

# Create EC2 instance
resource "aws_instance" "DockerInstance" {
  ami                    = data.aws_ami.amazon_2.id
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.ec2_key.key_name
  user_data              = file("install.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name = "docker-instance"
  }
}

# Outputs
output "ssh_command" {
  value = "ssh -i ${aws_key_pair.ec2_key.key_name}.pem ec2-user@${aws_instance.DockerInstance.public_dns}"
}

output "public_ip" {
  value = aws_instance.DockerInstance.public_ip
}
