#!/bin/bash
# ============================================
# Setup do Servidor APP (CPX31) com Traefik
# Instala Docker, configura Traefik e Backends
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Configurando Servidor APP com Traefik...${NC}"

# Carregar IPs
if [ -f /tmp/server-ips.env ]; then
    source /tmp/server-ips.env
fi

# ============================================
# Atualizar sistema
# ============================================
echo -e "${BLUE}📦 Atualizando sistema...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# ============================================
# Instalar dependências básicas
# ============================================
echo -e "${BLUE}📦 Instalando dependências...${NC}"
apt-get install -y \
    curl \
    wget \
    git \
    ufw \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# ============================================
# Instalar Docker
# ============================================
echo -e "${BLUE}🐳 Instalando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # Adicionar repositório Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo -e "${GREEN}✅ Docker instalado${NC}"
else
    echo -e "${GREEN}✅ Docker já está instalado${NC}"
fi

# ============================================
# Instalar Docker Compose (standalone)
# ============================================
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${BLUE}📦 Instalando Docker Compose...${NC}"
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose instalado${NC}"
else
    echo -e "${GREEN}✅ Docker Compose já está instalado${NC}"
fi

# ============================================
# Configurar Firewall (UFW)
# ============================================
echo -e "${BLUE}🔥 Configurando firewall...${NC}"
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp  # Dashboard Traefik (proteger em produção!)
echo -e "${GREEN}✅ Firewall configurado${NC}"

# ============================================
# Criar estrutura de diretórios
# ============================================
echo -e "${BLUE}📁 Criando estrutura de diretórios...${NC}"
mkdir -p /opt/eopix/app-server
mkdir -p /opt/eopix/app-server/letsencrypt
chmod 600 /opt/eopix/app-server/letsencrypt
echo -e "${GREEN}✅ Diretórios criados${NC}"

# ============================================
# Copiar arquivos de configuração
# ============================================
echo -e "${BLUE}📋 Copiando arquivos de configuração...${NC}"
cp -r /tmp/app-server/* /opt/eopix/app-server/
chmod +x /opt/eopix/app-server/*.sh 2>/dev/null || true
chmod +x /opt/eopix/app-server/scripts/*.sh 2>/dev/null || true

# Renomear docker-compose para usar Traefik
if [ -f /opt/eopix/app-server/docker-compose.traefik.yml ]; then
    # Fazer backup do docker-compose.yml antigo (se existir)
    if [ -f /opt/eopix/app-server/docker-compose.yml ]; then
        mv /opt/eopix/app-server/docker-compose.yml /opt/eopix/app-server/docker-compose.nginx.yml.backup
    fi
    # Usar Traefik
    cp /opt/eopix/app-server/docker-compose.traefik.yml /opt/eopix/app-server/docker-compose.yml
    echo -e "${GREEN}✅ Docker Compose configurado para Traefik${NC}"
else
    echo -e "${YELLOW}⚠️  docker-compose.traefik.yml não encontrado, usando docker-compose.yml padrão${NC}"
fi

# ============================================
# Configurar .env do backend
# ============================================
echo -e "${BLUE}⚙️  Configurando variáveis de ambiente...${NC}"
if [ -f /opt/eopix/app-server/.env.example ]; then
    if [ ! -f /opt/eopix/app-server/.env ]; then
        cp /opt/eopix/app-server/.env.example /opt/eopix/app-server/.env
        
        # Atualizar IPs se disponíveis
        if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
            sed -i "s/DB_HOST=.*/DB_HOST=${DB_SERVER_PRIVATE_IP}/" /opt/eopix/app-server/.env
            sed -i "s/REDIS_HOST=.*/REDIS_HOST=${DB_SERVER_PRIVATE_IP}/" /opt/eopix/app-server/.env
        fi
        
        # Adicionar DOMAIN se não existir
        if ! grep -q "^DOMAIN=" /opt/eopix/app-server/.env; then
            echo "DOMAIN=api-prod.eopix.me" >> /opt/eopix/app-server/.env
        fi
        
        echo -e "${YELLOW}⚠️  IMPORTANTE: Edite /opt/eopix/app-server/.env com suas configurações antes de iniciar!${NC}"
    fi
fi

# ============================================
# Criar usuário para aplicação (opcional)
# ============================================
if ! id "eopix" &>/dev/null; then
    useradd -r -s /bin/false eopix
    usermod -aG docker eopix
fi

# ============================================
# Configurar logs
# ============================================
chown -R root:root /opt/eopix
chmod -R 755 /opt/eopix

# ============================================
# Resumo
# ============================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Servidor APP configurado com Traefik!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📝 Próximos passos:${NC}"
echo ""
echo "  1. Edite as variáveis de ambiente:"
echo "     nano /opt/eopix/app-server/.env"
echo ""
echo "  2. Inicie os serviços:"
echo "     cd /opt/eopix/app-server"
echo "     docker-compose up -d"
echo ""
echo "  3. Verifique os logs:"
echo "     docker-compose logs -f traefik"
echo ""
echo "  4. Acesse o dashboard Traefik:"
echo "     http://<IP_SERVIDOR>:8080"
echo ""
echo "  5. Teste o health check:"
echo "     curl http://localhost/health"
echo ""
echo -e "${BLUE}🔒 SSL será configurado automaticamente pelo Traefik!${NC}"
echo ""
echo -e "${GREEN}✨ Setup concluído!${NC}"
