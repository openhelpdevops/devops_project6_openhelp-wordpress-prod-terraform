resource "aws_efs_file_system" "wordpress" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-efs"
  }
}

resource "aws_efs_mount_target" "wordpress" {
  count = 2

  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = aws_subnet.app[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_db_subnet_group" "wordpress" {
  name       = "${var.project_name}-${var.environment}-db-subnets"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnets"
  }
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-=?"
}

resource "aws_db_instance" "wordpress" {
  identifier = "${var.project_name}-${var.environment}-wordpress-mysql"

  engine         = "mysql"
  engine_version = "8.4"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  deletion_protection = false
  skip_final_snapshot = true

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-mysql"
  }
}

resource "aws_secretsmanager_secret" "wordpress_db" {
  name                    = "${var.project_name}/${var.environment}/wordpress/database"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "wordpress_db" {
  secret_id = aws_secretsmanager_secret.wordpress_db.id

  secret_string = jsonencode({
    host     = aws_db_instance.wordpress.address
    port     = aws_db_instance.wordpress.port
    database = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}
