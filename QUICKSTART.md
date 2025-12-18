# 🚀 Quick Start - Deploy EoPix na Hetzner

Guia rápido para colocar o EoPix em produção na Hetzner Cloud.

## ⚡ Setup Rápido (5 minutos)

### 1. Pré-requisitos

```bash
# Instalar Hetzner CLI
curl -sSLO https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
sudo tar -C /usr/local/bin --no-same-owner -xzf hcloud-linux-amd64.tar.gz hcloud
rm hcloud-linux-amd64.tar.gz

# Configurar token
export HCLOUD_TOKEN="seu-token-aqui"
hcloud context create eopix
# Cole o token quando solicitado

# Verificar SSH Key
hcloud ssh-key list
# Se não tiver, adicione:
hcloud ssh-key create --name eopix-key --public-key-from-file ~/.ssh/id_rsa.pub
```

### 2. Configurar Variáveis

```bash
cd eopix_hetzner
cp .env.example .env
nano .env  # Edite com suas configurações
```

**Importante**: Preencha pelo menos:
- `HCLOUD_TOKEN` - Token da API Hetzner
- `SSH_KEY_NAME` - Nome da sua SSH key no Hetzner
- `MYSQL_ROOT_PASSWORD` - Senha forte para MySQL root
- `MYSQL_PASSWORD` - Senha forte para usuário da aplicação
- `DOMAIN` - Seu domínio (ex: api.seudominio.com)

### 3. Criar Servidores

```bash
chmod +x create-servers.sh
./create-servers.sh
```

Este script irá:
- ✅ Criar servidor APP (CPX31)
- ✅ Criar servidor DB (CPX21)
- ✅ Criar rede privada
- ✅ Configurar firewall
- ✅ Instalar Docker e dependências
- ✅ Configurar Nginx e backends

### 4. Configurar Backend

```bash
# Obter IP do servidor APP
APP_IP=$(hcloud server describe eopix-app -o format='{{.PublicNet.IPv4.IP}}')

# SSH no servidor APP
ssh root@${APP_IP}

# Editar variáveis de ambiente
cd /opt/eopix/app-server
nano .env  # Configure todas as variáveis necessárias

# Iniciar serviços
docker-compose up -d

# Verificar logs
docker-compose logs -f
```

### 5. Configurar Banco de Dados

```bash
# Obter IP do servidor DB
DB_IP=$(hcloud server describe eopix-db -o format='{{.PublicNet.IPv4.IP}}')

# SSH no servidor DB
ssh root@${DB_IP}

# Editar variáveis de ambiente
cd /opt/eopix/db-server
nano .env  # Configure senhas

# Iniciar serviços
docker-compose up -d

# Aguardar MySQL inicializar (30-60 segundos)
sleep 60

# Criar banco e usuário
docker-compose exec mysql mysql -uroot -p
```

No MySQL, execute:

```sql
CREATE DATABASE eopix;
CREATE USER 'eopix'@'%' IDENTIFIED BY 'sua-senha-aqui';
GRANT ALL PRIVILEGES ON eopix.* TO 'eopix'@'%';
FLUSH PRIVILEGES;
EXIT;
```

### 6. Configurar Load Balancer

1. Acesse [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Vá em **Networking** → **Load Balancers**
3. Clique em **Add Load Balancer**
4. Configure:
   - **Name**: `eopix-lb`
   - **Type**: HTTP/HTTPS
   - **Location**: Mesma do servidor APP
   - **Algorithm**: Round Robin
5. Adicione Target:
   - **Type**: Server
   - **Server**: `eopix-app`
   - **Port**: 80
6. Configure Health Check:
   - **Protocol**: HTTP
   - **Port**: 80
   - **Path**: `/health`
   - **Interval**: 10s
   - **Timeout**: 5s
   - **Retries**: 3

### 7. Configurar DNS

Configure seu domínio para apontar para o IP do Load Balancer:

```
api.seudominio.com  A  <IP_DO_LOAD_BALANCER>
```

### 8. Validar Deploy

```bash
cd eopix_hetzner
chmod +x scripts/validate-deployment.sh
./scripts/validate-deployment.sh
```

## 🔒 Configurar TLS (Opcional)

### Opção A: Let's Encrypt no Servidor

```bash
# No servidor APP
ssh root@<IP_APP_SERVER>
cd /opt/eopix/app-server

# Instalar certbot
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Obter certificado
certbot certonly --standalone -d api.seudominio.com --email admin@seudominio.com --agree-tos --non-interactive

# Copiar certificados
mkdir -p ssl
cp /etc/letsencrypt/live/api.seudominio.com/fullchain.pem ssl/
cp /etc/letsencrypt/live/api.seudominio.com/privkey.pem ssl/

# Editar nginx.conf e descomentar bloco HTTPS
nano nginx.conf

# Reiniciar nginx
docker-compose restart nginx
```

### Opção B: TLS no Load Balancer (Recomendado)

1. No Hetzner Cloud Console, vá no Load Balancer
2. Configure HTTPS:
   - **Certificate**: Upload seu certificado ou use Let's Encrypt
   - **Port**: 443
3. Configure HTTP → HTTPS redirect

## 📊 Comandos Úteis

### Ver Logs

```bash
# APP Server
ssh root@<IP_APP>
cd /opt/eopix/app-server
docker-compose logs -f

# DB Server
ssh root@<IP_DB>
cd /opt/eopix/db-server
docker-compose logs -f mysql
```

### Reiniciar Serviços

```bash
# APP Server
cd /opt/eopix/app-server
docker-compose restart

# DB Server
cd /opt/eopix/db-server
docker-compose restart
```

### Backup Manual

```bash
# No servidor DB
ssh root@<IP_DB>
cd /opt/eopix/db-server
./backup.sh
```

### Verificar Health

```bash
# Local
curl http://localhost/health

# Via domínio
curl https://api.seudominio.com/health
```

## 🐛 Troubleshooting

### Backend não inicia

```bash
# Ver logs
docker-compose logs backend1

# Verificar variáveis
docker-compose exec backend1 env | grep DB_

# Testar conexão MySQL
docker-compose exec backend1 sh -c "nc -zv <IP_DB> 3306"
```

### MySQL não aceita conexões

```bash
# Verificar se está rodando
docker ps | grep mysql

# Verificar logs
docker-compose logs mysql

# Testar conexão local
docker-compose exec mysql mysql -uroot -p -e "SELECT 1;"
```

## 📚 Documentação Completa

Veja o [README.md](./README.md) para documentação completa e detalhada.
