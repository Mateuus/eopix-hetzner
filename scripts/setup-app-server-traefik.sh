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
# Verificar se docker compose (plugin) está disponível
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose (plugin) já está instalado${NC}"
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose (standalone) já está instalado${NC}"
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo -e "${BLUE}📦 Instalando Docker Compose...${NC}"
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose instalado${NC}"
    DOCKER_COMPOSE_CMD="docker-compose"
fi

# Função para executar docker compose (compatível com ambas versões)
docker_compose() {
    if [ -n "$DOCKER_COMPOSE_CMD" ]; then
        $DOCKER_COMPOSE_CMD "$@"
    elif docker compose version &> /dev/null; then
        docker compose "$@"
    elif command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        echo -e "${RED}❌ Docker Compose não encontrado!${NC}"
        exit 1
    fi
}

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
# Copiar arquivos de configuração (Git ou SCP)
# ============================================
echo -e "${BLUE}📋 Obtendo arquivos de configuração...${NC}"

# Verificar se GIT_REPO está definido
if [ -n "$GIT_REPO" ] && [ -n "$GIT_BRANCH" ]; then
    echo -e "${BLUE}📥 Clonando repositório Git: ${GIT_REPO} (branch: ${GIT_BRANCH})${NC}"
    
    # Clonar ou atualizar repositório
    GIT_TMP_DIR="/tmp/eopix-hetzner-git"
    if [ -d "$GIT_TMP_DIR" ]; then
        cd "$GIT_TMP_DIR"
        git fetch origin
        git checkout "$GIT_BRANCH" 2>/dev/null || git checkout -b "$GIT_BRANCH" origin/"$GIT_BRANCH"
        git pull origin "$GIT_BRANCH" || true
    else
        if ! git clone -b "$GIT_BRANCH" "$GIT_REPO" "$GIT_TMP_DIR" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  Falha ao clonar Git, usando arquivos de /tmp como fallback${NC}"
            GIT_TMP_DIR=""
        fi
    fi
    
    # Copiar arquivos do repositório clonado
    if [ -n "$GIT_TMP_DIR" ] && [ -d "$GIT_TMP_DIR/app-server" ]; then
        cp -r "$GIT_TMP_DIR/app-server"/* /opt/eopix/app-server/
        echo -e "${GREEN}✅ Arquivos copiados do repositório Git${NC}"
    else
        echo -e "${YELLOW}⚠️  Diretório app-server não encontrado no Git, usando /tmp como fallback${NC}"
        if [ -d /tmp/app-server ]; then
            cp -r /tmp/app-server/* /opt/eopix/app-server/
        else
            echo -e "${RED}❌ Erro: Arquivos não encontrados nem no Git nem em /tmp${NC}"
            exit 1
        fi
    fi
else
    echo -e "${BLUE}📋 Copiando arquivos via SCP (de /tmp)...${NC}"
    cp -r /tmp/app-server/* /opt/eopix/app-server/ 2>/dev/null || {
        echo -e "${RED}❌ Erro: Arquivos não encontrados em /tmp/app-server${NC}"
        echo -e "${YELLOW}💡 Dica: Defina GIT_REPO e GIT_BRANCH no .env para baixar do Git${NC}"
        exit 1
    }
fi

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

# Criar .env se não existir
if [ ! -f /opt/eopix/app-server/.env ]; then
    if [ -f /opt/eopix/app-server/.env.example ]; then
        cp /opt/eopix/app-server/.env.example /opt/eopix/app-server/.env
        echo -e "${GREEN}✅ Arquivo .env criado a partir do .env.example${NC}"
    else
        # Criar .env básico se .env.example não existir
        echo -e "${YELLOW}⚠️  Arquivo .env.example não encontrado. Criando .env básico...${NC}"
        cat > /opt/eopix/app-server/.env <<EOF
# EoPix Backend - Environment Variables
BACKEND_IMAGE=mateuus27/eopix-backend:latest
DOMAIN=api-prod.eopix.me
NODE_ENV=production
PORT=4000
SESSION_SECRET=change-me-minimum-32-characters-long-secret-key
COOKIE_DOMAIN=.eopix.me
DB_HOST=${DB_SERVER_PRIVATE_IP:-10.0.0.2}
DB_PORT=3306
DB_USER=eopix
DB_PASS=change-me-strong-password
DB_NAME=eopix
REDIS_HOST=${DB_SERVER_PRIVATE_IP:-10.0.0.2}
REDIS_PORT=6379
VALKEY_NAMESPACE=eopix
CORS_ENABLED=true
CORS_ORIGIN=https://eopix.me
CORS_ORIGINS=https://eopix.me,https://www.eopix.me
CORS_ALLOW_CREDENTIALS=true
R2_ACCOUNT_ID=your-r2-account-id
R2_ACCESS_KEY_ID=your-r2-access-key
R2_SECRET_ACCESS_KEY=your-r2-secret-key
R2_BUCKET_NAME=your-bucket-name
R2_PUBLIC_URL=https://your-r2-public-url.com
APP_URL=https://eopix.me
API_BASE_URL=https://api-prod.eopix.me
FRONTEND_URL=https://eopix.me
EOF
        echo -e "${GREEN}✅ Arquivo .env básico criado${NC}"
    fi
fi

# Atualizar IPs se disponíveis (mesmo se .env já existir)
if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
    if [ -f /opt/eopix/app-server/.env ]; then
        sed -i "s/DB_HOST=.*/DB_HOST=${DB_SERVER_PRIVATE_IP}/" /opt/eopix/app-server/.env
        sed -i "s/REDIS_HOST=.*/REDIS_HOST=${DB_SERVER_PRIVATE_IP}/" /opt/eopix/app-server/.env
        echo -e "${GREEN}✅ IPs do servidor DB atualizados no .env${NC}"
    fi
fi

# Adicionar DOMAIN se não existir
if [ -f /opt/eopix/app-server/.env ] && ! grep -q "^DOMAIN=" /opt/eopix/app-server/.env; then
    echo "DOMAIN=api-prod.eopix.me" >> /opt/eopix/app-server/.env
fi

if [ -f /opt/eopix/app-server/.env ]; then
    echo -e "${YELLOW}⚠️  IMPORTANTE: Edite /opt/eopix/app-server/.env com suas configurações antes de iniciar!${NC}"
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
# Iniciar serviços Docker (Traefik)
# ============================================
echo -e "${BLUE}🚀 Iniciando serviços Docker (Traefik)...${NC}"
cd /opt/eopix/app-server

# Verificar se .env existe antes de iniciar
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  Arquivo .env não encontrado. Criando...${NC}"
    
    # Tentar criar a partir do .env.example
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ Arquivo .env criado a partir do .env.example${NC}"
    else
        # Se .env.example não existir, criar um .env básico
        echo -e "${YELLOW}⚠️  Arquivo .env.example não encontrado. Criando .env básico...${NC}"
        cat > .env <<EOF
# EoPix Backend - Environment Variables
# Edite este arquivo com suas configurações antes de iniciar!

BACKEND_IMAGE=mateuus27/eopix-backend:latest

# Domain
DOMAIN=api-prod.eopix.me

# Node.js
NODE_ENV=production
PORT=4000
SESSION_SECRET=change-me-minimum-32-characters-long-secret-key
COOKIE_DOMAIN=.eopix.me

# Database
DB_HOST=${DB_SERVER_PRIVATE_IP:-10.0.0.2}
DB_PORT=3306
DB_USER=eopix
DB_PASS=change-me-strong-password
DB_NAME=eopix

# Redis/Valkey
REDIS_HOST=${DB_SERVER_PRIVATE_IP:-10.0.0.2}
REDIS_PORT=6379
VALKEY_NAMESPACE=eopix

# CORS
CORS_ENABLED=true
CORS_ORIGIN=https://eopix.me
CORS_ORIGINS=https://eopix.me,https://www.eopix.me
CORS_ALLOW_CREDENTIALS=true

# R2 Storage (Cloudflare)
R2_ACCOUNT_ID=your-r2-account-id
R2_ACCESS_KEY_ID=your-r2-access-key
R2_SECRET_ACCESS_KEY=your-r2-secret-key
R2_BUCKET_NAME=your-bucket-name
R2_PUBLIC_URL=https://your-r2-public-url.com

# URLs
APP_URL=https://eopix.me
API_BASE_URL=https://api-prod.eopix.me
FRONTEND_URL=https://eopix.me
EOF
        echo -e "${GREEN}✅ Arquivo .env básico criado${NC}"
    fi
    
    # Atualizar IPs se disponíveis
    if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
        sed -i "s/DB_HOST=.*/DB_HOST=${DB_SERVER_PRIVATE_IP}/" .env
        sed -i "s/REDIS_HOST=.*/REDIS_HOST=${DB_SERVER_PRIVATE_IP}/" .env
        echo -e "${GREEN}✅ IPs do servidor DB atualizados no .env${NC}"
    fi
    
    # Adicionar DOMAIN se não existir
    if ! grep -q "^DOMAIN=" .env; then
        echo "DOMAIN=api-prod.eopix.me" >> .env
    fi
    
    echo -e "${YELLOW}⚠️  IMPORTANTE: Edite /opt/eopix/app-server/.env com suas configurações antes de continuar!${NC}"
    echo -e "${YELLOW}⚠️  Execute: nano /opt/eopix/app-server/.env${NC}"
    echo -e "${YELLOW}⚠️  Depois execute: cd /opt/eopix/app-server && docker compose up -d${NC}"
    echo ""
    echo -e "${BLUE}📝 Pulando inicialização automática. Configure o .env primeiro.${NC}"
else
    # Iniciar serviços
    echo -e "${BLUE}🐳 Iniciando containers Docker...${NC}"
    docker_compose up -d
    
    echo -e "${GREEN}✅ Serviços iniciados${NC}"
    
    # Aguardar Traefik estar pronto
    echo -e "${BLUE}⏳ Aguardando Traefik inicializar (pode levar 10-20 segundos)...${NC}"
    sleep 10
    
    # Verificar se Traefik está respondendo
    MAX_WAIT=60
    WAITED=0
    TRAEFIK_READY=0
    
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s http://localhost:8080/ping >/dev/null 2>&1; then
            TRAEFIK_READY=1
            break
        fi
        echo -n "."
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    echo "" # Nova linha após os pontos
    
    if [ $TRAEFIK_READY -eq 1 ]; then
        echo -e "${GREEN}✅ Traefik está pronto!${NC}"
    else
        echo -e "${YELLOW}⚠️  Traefik ainda não está respondendo após ${MAX_WAIT} segundos${NC}"
        echo -e "${YELLOW}💡 Verifique os logs: docker compose logs traefik${NC}"
    fi
fi

# ============================================
# Resumo
# ============================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Servidor APP configurado com Traefik!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
if [ -f /opt/eopix/app-server/.env ]; then
    echo -e "${BLUE}📋 Status dos serviços:${NC}"
    echo ""
    echo "  # Verificar status"
    echo "  cd /opt/eopix/app-server"
    echo "  docker compose ps"
    echo ""
    echo "  # Ver logs"
    echo "  docker compose logs -f traefik"
    echo ""
    echo -e "${BLUE}🌐 Acesse o dashboard Traefik:${NC}"
    echo ""
    echo "  # Via IP do servidor (porta 8080):"
    echo "  http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "  # Ou via domínio (após configurar DNS):"
    echo "  https://traefik.${DOMAIN:-api-prod.eopix.me}"
    echo ""
    echo "  # Teste o health check:"
    echo "  curl http://localhost/health"
    echo ""
    echo -e "${BLUE}🔒 SSL será configurado automaticamente pelo Traefik!${NC}"
else
    echo -e "${BLUE}📝 Próximos passos:${NC}"
    echo ""
    echo "  1. Edite as variáveis de ambiente:"
    echo "     nano /opt/eopix/app-server/.env"
    echo ""
    echo "  2. Inicie os serviços:"
    echo "     cd /opt/eopix/app-server"
    echo "     docker compose up -d"
    echo ""
    echo "  3. Acesse o dashboard Traefik:"
    echo "     http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
fi
echo ""
echo -e "${GREEN}✨ Setup concluído!${NC}"
