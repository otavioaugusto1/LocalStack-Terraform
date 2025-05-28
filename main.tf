# main.tf

# Cria um bucket S3
resource "aws_s3_bucket" "meu_bucket" {
  bucket = "meu-bucket-localstack-test"
}

# Cria uma política IAM
resource "aws_iam_policy" "s3_policy" {
  name        = "s3_full_access_policy"
  description = "Política que permite acesso total ao S3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Cria um usuário IAM
resource "aws_iam_user" "s3_user" {
  name = "s3_user"
}

# Anexa a política ao usuário
resource "aws_iam_user_policy_attachment" "s3_attach" {
  user       = aws_iam_user.s3_user.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# Cria uma instância EC2 (simulada)
resource "aws_instance" "web" {
  ami           = "ami-123456" # No LocalStack, qualquer AMI funciona
  instance_type = "t2.micro"
  
  tags = {
    Name = "LocalStackInstance"
  }
}

# Mostra as saídas
output "bucket_name" {
  value = aws_s3_bucket.meu_bucket.bucket
}

output "iam_user_name" {
  value = aws_iam_user.s3_user.name
}

output "ec2_instance_id" {
  value = aws_instance.web.id
}