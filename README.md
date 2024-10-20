# Desafio de Infraestrutura como Código (IaC) com Terraform

## Objetivo

Demonstrar conhecimentos em Infraestrutura como Código (IaC) utilizando Terraform, bem como habilidades em segurança e automação de configuração de servidores.

## Descrição do Desafio

Este projeto utiliza o Terraform para criar uma infraestrutura básica na AWS, incluindo uma VPC, Subnet, Grupo de Segurança, Key Pair e uma instância EC2 com Nginx instalado e configurado automaticamente.

## Recursos Criados

O arquivo `main.tf` define os seguintes recursos na AWS:

- **VPC**: Uma Virtual Private Cloud (VPC) com suporte a DNS e hostnames.
- **Subnets**: Subnets configuradas para isolar recursos em uma rede privada e pública.
- **Internet Gateway**: Permite acesso à internet para a VPC.
- **Tabela de Rotas**: Configurada para permitir o tráfego entre a subnet pública e a internet.
- **Grupo de Segurança**: Permite conexões SSH de um IP específico, além de tráfego HTTP e HTTPS.
- **Key Pair**: Gera um par de chaves para acessar a instância EC2.
- **Instância EC2**: Uma instância EC2 com Nginx instalada automaticamente via `user_data`.

## Melhorias Implementadas

1. **Segurança**: 
   - Implementação de um Security Group restrito para acesso SSH.
   - Utilização de Secrets Manager para armazenar a chave privada gerada.

2. **Automação**: 
   - A instância EC2 é configurada para instalar e iniciar o servidor Nginx automaticamente após a criação.

3. **Outras Melhorias**: 
   - Consideração para a criação de subnets separadas para maior segurança e organização.

## Como Usar

### Pré-requisitos

- Ter o [Terraform](https://www.terraform.io/downloads.html) instalado.
- Ter uma conta AWS com credenciais configuradas.

### Passos

## Como clonar este repositório

1. Clone este repositório:

   ```bash
   git clone https://github.com/clayton-oly/desafio_devops.git
   cd desafio_devops
