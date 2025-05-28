# Projeto LocalStack com Terraform no WSL/Ubuntu

## Pré-requisitos

1. WSL com Ubuntu instalado
2. Docker instalado no Windows (o LocalStack roda em containers)
3. Terraform instalado no Ubuntu/WSL

## Passo 1: Instalação do LocalStack

```bash
# Atualize os pacotes
sudo apt update && sudo apt upgrade -y

# Instale o Docker no Ubuntu/WSL (se ainda não tiver)
sudo apt install -y docker.io
sudo usermod -aG docker $USER
newgrp docker

# Instale o docker-compose
sudo apt install -y docker-compose

# Baixe a imagem do LocalStack
docker pull localstack/localstack

# Crie um docker-compose.yml para o LocalStack
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  localstack:
    container_name: localstack
    image: localstack/localstack
    ports:
      - "4566:4566"            # Porta principal da API
      - "4510-4559:4510-4559"  # Portas dos serviços individuais
    environment:
      - SERVICES=ec2,s3,iam   # Serviços que queremos ativar
      - DEBUG=1
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./localstack_data:/tmp/localstack_data"
EOF

# Inicie o LocalStack
docker-compose up -d
```

## Passo 2: Configurar o Terraform para usar o LocalStack

Crie um diretório para seu projeto:

```bash
mkdir localstack-terraform && cd localstack-terraform
```

Crie um arquivo `provider.tf`:

```hcl
# provider.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  
  # Configuração para LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
  }
}
```

## Passo 3: Exemplo de Infraestrutura com EC2, S3 e IAM

Crie um arquivo `main.tf`:

```hcl
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
```

## Passo 4: Inicializar e Aplicar a Infraestrutura

```bash
# Inicialize o Terraform
terraform init

# Aplique a configuração
terraform apply -auto-approve
```

## Passo 5: Verificando os recursos criados

Você pode verificar os recursos criados usando a AWS CLI configurada para o LocalStack:

```bash
# Instale a AWS CLI se ainda não tiver
sudo apt install -y awscli

# Configure a CLI para o LocalStack
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set region us-east-1
aws configure set output json

# Verifique os serviços:

# Listar buckets S3
aws --endpoint-url=http://localhost:4566 s3 ls

# Listar instâncias EC2
aws --endpoint-url=http://localhost:4566 ec2 describe-instances

# Listar usuários IAM
aws --endpoint-url=http://localhost:4566 iam list-users
```

## Passo 6: Limpeza (opcional)

Para destruir os recursos criados:

```bash
terraform destroy -auto-approve
```

Para parar o LocalStack:

```bash
docker-compose down
```

## Dicas Extras

1. **Dashboard do LocalStack**: Acesse http://localhost:4566/_aws/health para ver o status dos serviços.

2. **Mais serviços**: Para adicionar mais serviços AWS, edite a variável `SERVICES` no docker-compose.yml.

3. **Persistência**: Os dados são armazenados no volume `./localstack_data`.

4. **Debug**: Se algo não funcionar, verifique os logs com `docker-compose logs -f`.



## Entendendo a relação entre SERVICES no docker-compose e recursos no Terraform

No LocalStack, existem dois níveis de ativação de serviços:

### 1. Ativação no LocalStack (docker-compose.yml)
A variável `SERVICES` no docker-compose.yml define quais serviços AWS o container do LocalStack vai **simular**. Por exemplo:

```yaml
environment:
  - SERVICES=ec2,s3,iam,lambda,dynamodb
```

Isso significa que:
- O LocalStack só vai iniciar os serviços listados (EC2, S3, IAM, Lambda, DynamoDB)
- Outros serviços (como RDS ou SQS) não estarão disponíveis, mesmo que você tente acessá-los
- Cada serviço consome memória, então é melhor ativar apenas os que você precisa

### 2. Criação de recursos (arquivos .tf)
Os arquivos Terraform (.tf) definem **quais recursos serão criados dentro dos serviços ativados**. Por exemplo:

```hcl
# Isso só funciona se o serviço 'dynamodb' estiver na lista SERVICES
resource "aws_dynamodb_table" "example" {
  name = "my-table"
  # ... outros atributos
}
```

## Por que essa separação?

1. **Eficiência**: O LocalStack não precisa carregar todos os serviços AWS (só os que você vai usar)
2. **Performance**: Cada serviço adicional consome recursos do seu sistema
3. **Compatibilidade**: Alguns serviços podem requerer configurações especiais

## Como adicionar um novo serviço?

1. **Passo 1**: Adicione o serviço no docker-compose.yml
```yaml
environment:
  - SERVICES=ec2,s3,iam,dynamodb  # Adicionei dynamodb
```

2. **Passo 2**: Recrie o container
```bash
docker-compose down
docker-compose up -d
```

3. **Passo 3**: Adicione o endpoint no provider.tf
```hcl
provider "aws" {
  # ...
  endpoints {
    dynamodb = "http://localhost:4566"  # Novo endpoint
  }
}
```

4. **Passo 4**: Agora você pode criar recursos desse serviço nos arquivos .tf

## Lista de serviços disponíveis

Alguns exemplos de serviços que você pode adicionar:
- `lambda`: AWS Lambda
- `dynamodb`: DynamoDB
- `sqs`: Simple Queue Service
- `sns`: Simple Notification Service
- `rds`: Relational Database Service
- `apigateway`: API Gateway

A lista completa está na [documentação do LocalStack](https://docs.localstack.cloud/aws/feature-coverage/).

## Exemplo Prático

Se quisermos adicionar o Lambda:

1. docker-compose.yml:
```yaml
environment:
  - SERVICES=ec2,s3,iam,lambda
```

2. provider.tf:
```hcl
endpoints {
  lambda = "http://localhost:4566"
}
```

3. main.tf:
```hcl
resource "aws_lambda_function" "test_lambda" {
  function_name = "my-function"
  # ... outros parâmetros
}
```

Sem adicionar `lambda` na variável `SERVICES`, você receberia um erro ao tentar criar recursos Lambda, mesmo que o código Terraform estivesse correto.