provider "aws" {
  region = "ap-south-1"
  profile = "Ajay"
}

resource "tls_private_key" "task1_key"  {
  algorithm = "RSA"
}

resource "aws_key_pair" "keypair1" {
  key_name = "cloud_task1_key"
  public_key = "${tls_private_key.task1_key.public_key_openssh}"

  depends_on = [
   tls_private_key.task1_key
  ]
}

resource "local_file" "download_key" {
  content = "${tls_private_key.task1_key.private_key_pem}"
  filename = "cloud_task1_key.pem"
  depends_on = [
   tls_private_key.task1_key
  ]
}

resource "aws_security_group" "task1_sg" {
  name = "task1_sg"
  vpc_id = "vpc-63766a0b"
  
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_http_ssh"
  }
}

resource "aws_s3_bucket" "t1_bucket" {
  bucket = "t1-s3-bucket"
  acl    = "public-read"

  tags = {
    Name        = "task1_s3"
  }
}

resource "aws_s3_bucket_object" "t1_bucket_object" {
  bucket = "${aws_s3_bucket.t1_bucket.bucket}"
  key    = "task1.jpg"
  source = "C:/Users/krishan/Desktop/ajay/Cloud/task1/task1.jpg"
  acl = "public-read"
}

locals {
  s3_origin_id = "aws_s3_bucket.t1_bucket.id"
}

resource "aws_cloudfront_distribution" "task1_cf" {
  origin {
    domain_name = "${aws_s3_bucket.t1_bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "cloudfront_s3"

  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Environment = "t1_cf"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_instance" "task1_os" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.keypair1.key_name}"
  security_groups = [ "${aws_security_group.task1_sg.name}" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.task1_key.private_key_pem}"
    host     = "${aws_instance.task1_os.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "task1"
  }

}


resource "aws_ebs_volume" "task1_ebs" {
  availability_zone = "${aws_instance.task1_os.availability_zone}"
  size              = 1
  tags = {
    Name = "task1_ebs"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.task1_ebs.id}"
  instance_id = "${aws_instance.task1_os.id}"
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.task1_os.public_ip
}

resource "null_resource" "mount_ebs"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.task1_key.private_key_pem}"
    host     = "${aws_instance.task1_os.public_ip}"
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Ajaypathak372/cloudtask1.git /var/www/html/"
    ]
  }
}

resource "null_resource"  "nullremote" {
  depends_on = [	
  aws_instance.task1_os,
  aws_cloudfront_distribution.task1_cf
  ]
  connection {
    type = "ssh"
    port = 22
    user = "ec2-user"
    private_key = "${tls_private_key.task1_key.private_key_pem}"
    host = "${aws_instance.task1_os.public_ip}"
  }
  provisioner "remote-exec"{
    inline = [
    "sudo su << EOF",
    "echo '<img src='https://${aws_cloudfront_distribution.task1_cf.domain_name}/${aws_s3_bucket_object.t1_bucket_object.key}' weidth=300 height=300 ' >> /var/www/html/task1.html ",
    "EOF",
    ]
	
  }
}


