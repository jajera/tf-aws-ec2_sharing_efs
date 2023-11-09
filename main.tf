# create rg, list created resources
resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name  = "tf-rg-example"
    Owner = "John Ajera"
  }
}

# create vpc
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "tf-vpc-example"
    Owner = "John Ajera"
  }
}

# create subnet
resource "aws_subnet" "example_a" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-southeast-1a"

  tags = {
    Name  = "tf-subnet-example_a"
    Owner = "John Ajera"
  }
}

resource "aws_subnet" "example_b" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-southeast-1b"

  tags = {
    Name  = "tf-subnet-example_b"
    Owner = "John Ajera"
  }
}

# create ig
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name  = "tf-ig-example"
    Owner = "John Ajera"
  }
}

# create rt
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.example.id
  }

  tags = {
    Name  = "tf-rt-example"
    Owner = "John Ajera"
  }
}

# set rt association
resource "aws_route_table_association" "example_a" {
  subnet_id      = aws_subnet.example_a.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "example_b" {
  subnet_id      = aws_subnet.example_b.id
  route_table_id = aws_route_table.example.id
}


# create sg
resource "aws_security_group" "example_ssh" {
  name        = "tf-sg-example-ssh"
  description = "Security group for example resources to allow ssh"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name  = "tf-sg-example_ssh"
    Owner = "John Ajera"
  }
}

resource "aws_security_group" "example_efs" {
  name        = "tf-sg-example-efs"
  description = "Security group for example resources to allow access to efs"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name  = "tf-sg-example_efs"
    Owner = "John Ajera"
  }
}

# get image ami
data "aws_ami" "example" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-8.8.0_HVM-20230623-x86_64-3-Hourly2-GP2"]
  }
}

# create efs
resource "aws_efs_file_system" "example" {
  creation_token   = "example"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name  = "tf-efs-example"
    Owner = "John Ajera"
  }
}

# create efs mount target
resource "aws_efs_mount_target" "example_a" {
  file_system_id  = aws_efs_file_system.example.id
  subnet_id       = aws_subnet.example_a.id
  security_groups = [aws_security_group.example_efs.id]
}

resource "aws_efs_mount_target" "example_b" {
  file_system_id  = aws_efs_file_system.example.id
  subnet_id       = aws_subnet.example_b.id
  security_groups = [aws_security_group.example_efs.id]
}

# get ssh key pair
resource "aws_key_pair" "example" {
  key_name   = "tf-kp-example"
  public_key = file("~/.ssh/id_ed25519_aws.pub")
}

# create vm
resource "aws_instance" "example_a" {
  ami                         = data.aws_ami.example.image_id
  instance_type               = "t2.small"
  key_name                    = aws_key_pair.example.key_name
  subnet_id                   = aws_subnet.example_a.id
  vpc_security_group_ids      = [aws_security_group.example_ssh.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum install -y nfs-utils
    mkdir -p /mnt/efs
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${aws_efs_mount_target.example_a.dns_name}:/ /mnt/efs
    echo '${aws_efs_mount_target.example_a.dns_name}:/ /mnt/efs nfs4 defaults 0 0' >> /etc/fstab
    mount -a
    echo "created from example 1" > /mnt/efs/file1.txt
    EOF

  lifecycle {
    ignore_changes = [
      associate_public_ip_address
    ]
  }

  tags = {
    Name  = "tf-instance-example_a"
    Owner = "John Ajera"
  }
}

resource "aws_instance" "example_b" {
  ami                         = data.aws_ami.example.image_id
  instance_type               = "t2.small"
  key_name                    = aws_key_pair.example.key_name
  subnet_id                   = aws_subnet.example_b.id
  vpc_security_group_ids      = [aws_security_group.example_ssh.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum install -y nfs-utils
    mkdir -p /mnt/efs
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${aws_efs_mount_target.example_b.dns_name}:/ /mnt/efs
    echo '${aws_efs_mount_target.example_b.dns_name}:/ /mnt/efs nfs4 defaults 0 0' >> /etc/fstab
    mount -a
    echo "created from example 2" > /mnt/efs/file2.txt
    EOF

  lifecycle {
    ignore_changes = [
      associate_public_ip_address
    ]
  }

  tags = {
    Name  = "tf-instance-example_b"
    Owner = "John Ajera"
  }
}

output "public_ip" {
  value = {
    example_a = aws_instance.example_a.public_ip
    example_b = aws_instance.example_b.public_ip
  }
}
