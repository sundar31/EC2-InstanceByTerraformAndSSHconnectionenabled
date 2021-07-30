provider "aws"{
    region = "ap-south-1"
    access_key=var.acc_key
    secret_key=var.sec_key
}

variable "acc_key" {
    description = "access key for provider"
}
variable "sec_key"{
    description="secret key for provider"
}

#1.create vpc

resource "aws_vpc" "my-prod-vpc"{
    cidr_block="10.0.0.0/16"
    tags = {
        Name = "production"
    }
}

#2.create internet gateway

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.my-prod-vpc.id

}

#3.create custum route table

resource "aws_route_table" "pro-route-table" {
  vpc_id = aws_vpc.my-prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

#4.Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.my-prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
      Name = "prod-subnet"
  }
}

#5. Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.pro-route-table.id
}

#6.Create security group

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my-prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  tags = {
    Name = "allow_web"
  }
}

#7.Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#8.Assign an elastic IP to the netwrok interface created in step7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

#9.Create Ubuntu server and initialize/ enable nginx
variable "ami_id"{
    description = "value for ami"
}
variable "pub_key" {
    description="Public key"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key =var.pub_key
}
resource "aws_instance" "ubuntu-web-server"{
    ami=var.ami_id
    instance_type="t2.micro"
    availability_zone = "ap-south-1a"
   
    key_name = aws_key_pair.deployer.key_name

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install nginx -y
                sudo systemctl start nginx
                sudo bash -c 'echo your first web server > /var/www/html/index.html'
                EOF

    tags = {
    Name="Ubuntuserver"
}
}
