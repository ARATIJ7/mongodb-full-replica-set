resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "jumpbox" {
  ami           = "ami-0c55b159cbfafe1f0"  # Replace with a suitable Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.jumpbox_sg.name]

  tags = {
    Name = "Jumpbox"
  }
}

resource "aws_instance" "mongo" {
  count         = 3  # Change this to the desired number of MongoDB nodes
  ami           = "ami-0c55b159cbfafe1f0"  # Replace with a suitable Amazon Linux 2 AMI
  instance_type = var.mongo_instance_type
  key_name      = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.private.id
  security_groups = [aws_security_group.mongo_sg.name]

  tags = {
    Name = "MongoDBServer-${count.index}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo tee /etc/yum.repos.d/mongodb-org-4.4.repo <<EOF
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF",
      "sudo yum install -y mongodb-org",
      "sudo systemctl start mongod",
      "sudo systemctl enable mongod"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.private_ip
    }
  }

  provisioner "file" {
    content     = templatefile("initiate_replicaset.sh.tpl", { ip0 = aws_instance.mongo[0].private_ip, ip1 = aws_instance.mongo[1].private_ip, ip2 = aws_instance.mongo[2].private_ip })
    destination = "/tmp/initiate_replicaset.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.private_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/initiate_replicaset.sh",
      "/tmp/initiate_replicaset.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = aws_instance.mongo[0].private_ip
    }
  }
}
