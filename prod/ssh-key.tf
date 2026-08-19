resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "${var.project_name}-${var.environment}-wordpress-bastion"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-bastion"
  }
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.root}/${var.ssh_private_key_filename}"
  file_permission = "0600"
}
