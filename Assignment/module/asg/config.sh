#!/bin/bash
  # Retrieve secrets from AWS Secrets Manager
#secrets=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.webapp_secrets.arn} --output json | jq -r '.SecretString | fromjson')
sudo apt install docker.io -y
sudo usermod -aG docker $USER
sudo chmod 666 /var/run/docker.sock
# Set environment variables for Docker container
#export AWS_ACCESS_KEY_ID=${secrets["AWS_ACCESS_KEY_ID"]}
#export AWS_SECRET_ACCESS_KEY=${secrets["AWS_SECRET_ACCESS_KEY"]}
#export S3_BUCKET_NAME=${secrets["S3_BUCKET_NAME"]}
#export AWS_REGION=${secrets["AWS_REGION"]}

# Run Docker container
docker run -d -e AWS_ACCESS_KEY_ID=${var.aws_access_key_id} \
              -e AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key} \
              -e S3_BUCKET_NAME=${var.s3_bucket_name} \
              -e AWS_REGION=${var.aws_region} \
              -p 80:80 nginx:latest

              