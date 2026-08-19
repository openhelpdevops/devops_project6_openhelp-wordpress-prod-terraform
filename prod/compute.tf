locals {
  wordpress_user_data = [for index in range(2) : <<-EOT
    #!/bin/bash
    set -euxo pipefail

    dnf upgrade -y
    dnf install -y httpd php php-mysqlnd php-gd php-mbstring php-xml php-intl jq amazon-efs-utils amazon-cloudwatch-agent

    systemctl enable --now httpd

    if [ ! -f /var/www/html/wp-login.php ]; then
      rm -f /var/www/html/index.html
      curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wordpress.tar.gz
      tar -xzf /tmp/wordpress.tar.gz -C /tmp
      cp -a /tmp/wordpress/. /var/www/html/
    fi

    mkdir -p /var/www/html/wp-content/uploads

    EFS_ID="${aws_efs_file_system.wordpress.id}"
    echo "$EFS_ID:/ /var/www/html/wp-content/uploads efs _netdev,tls 0 0" >> /etc/fstab

    # AWS recommends allowing time for new EFS mount-target DNS records to propagate.
    sleep 60
    for attempt in $(seq 1 30); do
      if mount -a; then
        break
      fi
      sleep 10
    done

    mountpoint -q /var/www/html/wp-content/uploads

    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${aws_secretsmanager_secret.wordpress_db.name}" --region "${var.aws_region}" --query SecretString --output text)
    DB_HOST=$(echo "$SECRET_JSON" | jq -r .host)
    DB_NAME=$(echo "$SECRET_JSON" | jq -r .database)
    DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
    DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)

    if [ ! -f /var/www/html/wp-config.php ]; then
      cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

      DB_NAME_ESCAPED=$(printf '%s' "$DB_NAME" | sed 's/[&/]/\\&/g')
      DB_USER_ESCAPED=$(printf '%s' "$DB_USER" | sed 's/[&/]/\\&/g')
      DB_PASSWORD_ESCAPED=$(printf '%s' "$DB_PASSWORD" | sed 's/[&/]/\\&/g')
      DB_HOST_ESCAPED=$(printf '%s' "$DB_HOST" | sed 's/[&/]/\\&/g')

      sed -i "s/database_name_here/$DB_NAME_ESCAPED/" /var/www/html/wp-config.php
      sed -i "s/username_here/$DB_USER_ESCAPED/" /var/www/html/wp-config.php
      sed -i "s/password_here/$DB_PASSWORD_ESCAPED/" /var/www/html/wp-config.php
      sed -i "s/localhost/$DB_HOST_ESCAPED/" /var/www/html/wp-config.php

      curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ -o /tmp/wp-salts
      awk '
        FNR == NR { salts = salts $0 ORS; next }
        /put your unique phrase here/ {
          if (!replaced) {
            printf "%s", salts
            replaced=1
          }
          next
        }
        { print }
      ' /tmp/wp-salts /var/www/html/wp-config.php > /tmp/wp-config.php
      mv /tmp/wp-config.php /var/www/html/wp-config.php
    fi

    cat > /etc/httpd/conf.d/wordpress.conf <<'APACHECONF'
    <Directory "/var/www/html">
        AllowOverride All
        Require all granted
    </Directory>
    APACHECONF

    chown -R apache:apache /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
    {
      "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/httpd/access_log",
                "log_group_name": "/${var.project_name}/${var.environment}/wordpress/apache-access",
                "log_stream_name": "{instance_id}"
              },
              {
                "file_path": "/var/log/httpd/error_log",
                "log_group_name": "/${var.project_name}/${var.environment}/wordpress/apache-error",
                "log_stream_name": "{instance_id}"
              },
              {
                "file_path": "/var/log/cloud-init-output.log",
                "log_group_name": "/${var.project_name}/${var.environment}/wordpress/cloud-init",
                "log_stream_name": "{instance_id}"
              }
            ]
          }
        }
      },
      "metrics": {
        "append_dimensions": {
          "InstanceId": "$${aws:InstanceId}"
        },
        "metrics_collected": {
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["*"]
          },
          "mem": {
            "measurement": ["mem_used_percent"]
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

    httpd -t
    systemctl restart httpd
  EOT
  ]
}

resource "aws_instance" "wordpress" {
  count = 2

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.app[count.index].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.wordpress.name
  key_name                    = aws_key_pair.ssh.key_name

  user_data                   = local.wordpress_user_data[count.index]
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  depends_on = [
    aws_efs_mount_target.wordpress,
    aws_secretsmanager_secret_version.wordpress_db,
    aws_cloudwatch_log_group.apache_access,
    aws_cloudwatch_log_group.apache_error,
    aws_cloudwatch_log_group.cloud_init
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-${count.index + 1}"
  }
}
