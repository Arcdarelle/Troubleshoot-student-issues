
# create security group for the ec2 instance
resource "aws_security_group" "webserver_security_group" {
  name        = "sg"
  description = "allow access on ports 80 and 22"
  vpc_id      = aws_vpc.lab_vpc.id

  # allow access on these port 80 and 22 for Server using Dynamic blocks. Values are all defined in the variables.tf file
  # allow access on port 8080 for Jenkins Server
  ingress {
    description = "http proxy access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow access on port 22 ssh connection
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security group"
  }
}

# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "webserver_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create the Key Pair
resource "aws_key_pair" "webserver_key" {
  key_name   = "webserver_key_pair"
  public_key = tls_private_key.webserver_key.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename        = "${aws_key_pair.webserver_key.key_name}.pem"
  content         = tls_private_key.webserver_key.private_key_pem
  file_permission = "400"
}