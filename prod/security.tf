resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow HTTPS from the internet to the public ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
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
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Allow web traffic only from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-sg"
  }
}

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Allow NFS from WordPress instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from application servers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-efs-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow MySQL only from WordPress instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from application servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Allow SSH to the bastion only from approved administrator CIDRs"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from administrator CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.effective_bastion_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.bastion.id
  description                  = "SSH to private WordPress instances only from bastion"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}
