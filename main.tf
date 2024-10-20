#Especificar a versao do terraform pois pode ser necessario em alguns casos 
terraform {
   required_version = ">= 1.2.0"
}
#Separa as variaves em um arquivo variables.tf
#Variaveis para facilitar a reutilização em diferentes ambientes
variable "projeto" {
  description = "Teste Pratico"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Clayton William Oliveira Rocha"
  type        = string
  default     = "Clayton"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

#Qual Cloud sera utilizada
provider "aws" {
  region = var.region
}

#Criação da Chave Privada TLS para EC2
#Aumento de 2048 para 4096 pode tornar mais segura
#Aqui daria para usar o AWS Secrets Manager
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Criação de Key Pair para acessar a instância EC2 via SSH usando a chave gerada localmente
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key" # Nome da chave baseada no projeto e candidato
  public_key = tls_private_key.ec2_key.public_key_openssh
}

#Criar o Secret do AWS Secrets Manager
resource "aws_secretsmanager_secret" "ec2_key_secret" {
  name = "${var.projeto}-${var.candidato}-ec2-key"

  tags = {
    Name = "${var.projeto}-${var.candidato}-key-secret"
  }
}

#Versão do Secret
resource "aws_secretsmanager_secret_version" "ec2_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.ec2_key_secret.id
  secret_string = tls_private_key.ec2_key.private_key_pem
}

#Criação VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
#Habitar Flow Log para fins de auditorias

#Criacao Subnet
#Boa pratica seria separar subnet em publica(Servidor Web) e privada(Ex Database)
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

#Criação Internet Gateway para que a VPC tenha acesso a internet
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

#Criação da Tabela de Rotas (Que determina quais subnets têm acesso a outras subnets e à internet através da tabela de rotas)
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

#Associação da Tabela de Rotas com a Subnet
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

#Criaçao do Grupo de Segurançã e as regras de entrada e saida para os protocolos que vao ser necessarios
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir acesso  personalizado"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description      = "Permitir SSH somente para um IP especifico"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["138.36.58.151/32"] #"Permitir SSH somente para um IP especifico"
    ipv6_cidr_blocks = ["::/0"]
  }

  # Permitir tráfego HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permite acesso de qualquer lugar
  }

  # Permitir tráfego HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permite acesso de qualquer lugar
  }

  # Regras de saída
  egress {
    description = "Permitir Trafego via HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Permite acesso de qualquer lugar
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "Permitir Trafego via HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // Permite acesso de qualquer lugar
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

#Essa etapa é onde ele busca a imagem do (AMI) mais recente do debian
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

#Essa etapa é para provisionar uma instancia EC2 na AWS
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.main_sg.id] # Utilizar ID do Security Group ao inves do nome

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  # Script para atualizar pacotes, instalar e iniciar o Nginx
  #Adição de Logs
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "Instância inicializada corretamente" >> /var/log/user_data.log
              echo "<html><h1>Teste Servidor Web!</h1></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

#Outra possivel solução seria salvar a chave privada ao inves de expor ela no console
resource "local_file" "private_key" {
  filename = "${path.module}/ec2_key.pem"
  content  = tls_private_key.ec2_key.private_key_pem
  file_permission = "0600"
}

#Separa os output  em um arquivo especifico

#Saidas no Console
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
