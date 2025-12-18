#!/bin/bash
# ============================================
# Setup do Servidor DB (CPX21)
# Instala Docker, configura MySQL e Valkey
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Configurando Servidor DB...${NC}"

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
    lsb-release \
    cron

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
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo -e "${GREEN}✅ Docker instalado${NC}"
else
    echo -e "${YELLOW}⚠️  Docker já está instalado${NC}"
fi

# ============================================
# Instalar Docker Compose (standalone)
# ============================================
if ! command -v docker-compose &> /dev/null; then
    echo -e "${BLUE}📦 Instalando Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose instalado${NC}"
fi

# ============================================
# Configurar Firewall UFW
# ============================================
echo -e "${BLUE}🔥 Configurando firewall...${NC}"
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
# MySQL e Valkey serão acessíveis apenas via rede privada (configurado no Hetzner Firewall)
echo -e "${GREEN}✅ Firewall configurado${NC}"

# ============================================
# Criar estrutura de diretórios
# ============================================
echo -e "${BLUE}📁 Criando estrutura de diretórios...${NC}"
mkdir -p /opt/eopix/db-server
mkdir -p /opt/eopix/db-server/backups/mysql
mkdir -p /opt/eopix/db-server/mysql-data
mkdir -p /opt/eopix/db-server/valkey-data
mkdir -p /opt/eopix/db-server/mysql-config

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
    if [ -n "$GIT_TMP_DIR" ] && [ -d "$GIT_TMP_DIR/db-server" ]; then
        cp -r "$GIT_TMP_DIR/db-server"/* /opt/eopix/db-server/
        echo -e "${GREEN}✅ Arquivos copiados do repositório Git${NC}"
    else
        echo -e "${YELLOW}⚠️  Diretório db-server não encontrado no Git, usando /tmp como fallback${NC}"
        if [ -d /tmp/db-server ]; then
            cp -r /tmp/db-server/* /opt/eopix/db-server/
        else
            echo -e "${RED}❌ Erro: Arquivos não encontrados nem no Git nem em /tmp${NC}"
            exit 1
        fi
    fi
else
    echo -e "${BLUE}📋 Copiando arquivos via SCP (de /tmp)...${NC}"
    cp -r /tmp/db-server/* /opt/eopix/db-server/ 2>/dev/null || {
        echo -e "${RED}❌ Erro: Arquivos não encontrados em /tmp/db-server${NC}"
        echo -e "${YELLOW}💡 Dica: Defina GIT_REPO e GIT_BRANCH no .env para baixar do Git${NC}"
        exit 1
    }
fi

chmod +x /opt/eopix/db-server/*.sh 2>/dev/null || true

# ============================================
# Configurar .env
# ============================================
echo -e "${BLUE}⚙️  Configurando variáveis de ambiente...${NC}"
if [ -f /opt/eopix/db-server/.env.example ]; then
    if [ ! -f /opt/eopix/db-server/.env ]; then
        cp /opt/eopix/db-server/.env.example /opt/eopix/db-server/.env
        echo -e "${YELLOW}⚠️  IMPORTANTE: Edite /opt/eopix/db-server/.env com senhas fortes antes de iniciar!${NC}"
    fi
fi

# ============================================
# Configurar permissões
# ============================================
chown -R root:root /opt/eopix
chmod -R 755 /opt/eopix
chmod 600 /opt/eopix/db-server/.env 2>/dev/null || true

# ============================================
# Configurar backup via cron
# ============================================
echo -e "${BLUE}📅 Configurando backup automático...${NC}"
if [ -f /opt/eopix/db-server/backup.sh ]; then
    chmod +x /opt/eopix/db-server/backup.sh
    
    # Adicionar ao crontab (backup diário às 02:00 UTC)
    (crontab -l 2>/dev/null | grep -v "/opt/eopix/db-server/backup.sh"; \
     echo "0 2 * * * /opt/eopix/db-server/backup.sh >> /opt/eopix/db-server/backup.log 2>&1") | crontab -
    
    echo -e "${GREEN}✅ Backup automático configurado (02:00 UTC diariamente)${NC}"
fi

# ============================================
# Resumo
# ============================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Servidor DB configurado!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📝 Próximos passos:${NC}"
echo ""
echo "  1. Edite as variáveis de ambiente:"
echo "     nano /opt/eopix/db-server/.env"
echo ""
echo "  2. Inicie os serviços:"
echo "     cd /opt/eopix/db-server"
echo "     docker-compose up -d"
echo ""
echo "  3. Aguarde MySQL inicializar (30-60 segundos)"
echo ""
echo "  4. Crie o banco de dados e usuário:"
echo "     docker-compose exec mysql mysql -uroot -p"
echo "     # Execute:"
echo "     # CREATE DATABASE eopix;"
echo "     # CREATE USER 'eopix'@'%' IDENTIFIED BY 'senha-segura';"
echo "     # GRANT ALL PRIVILEGES ON eopix.* TO 'eopix'@'%';"
echo "     # FLUSH PRIVILEGES;"
echo ""
echo "  5. Verifique os logs:"
echo "     docker-compose logs -f"
echo ""
echo -e "${GREEN}✨ Setup concluído!${NC}"
