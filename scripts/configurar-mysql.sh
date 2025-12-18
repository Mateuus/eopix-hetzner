#!/bin/bash
# ============================================
# Script de Configuração Automática do MySQL
# Cria banco de dados, usuário e permissões
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Configurando MySQL...${NC}"

# Diretório do MySQL
MYSQL_DIR="/opt/eopix/db-server"

# Verificar se .env existe
if [ ! -f "${MYSQL_DIR}/.env" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em ${MYSQL_DIR}${NC}"
    echo -e "${YELLOW}💡 Execute: cp ${MYSQL_DIR}/.env.example ${MYSQL_DIR}/.env${NC}"
    exit 1
fi

# Carregar variáveis de ambiente
source "${MYSQL_DIR}/.env"

# Verificar variáveis obrigatórias
if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
    echo -e "${RED}❌ MYSQL_ROOT_PASSWORD não definido no .env${NC}"
    exit 1
fi

if [ -z "${MYSQL_DATABASE}" ]; then
    echo -e "${YELLOW}⚠️  MYSQL_DATABASE não definido, usando 'eopix' como padrão${NC}"
    MYSQL_DATABASE="eopix"
fi

if [ -z "${MYSQL_USER}" ]; then
    echo -e "${YELLOW}⚠️  MYSQL_USER não definido, usando 'eopix' como padrão${NC}"
    MYSQL_USER="eopix"
fi

if [ -z "${MYSQL_PASSWORD}" ]; then
    echo -e "${RED}❌ MYSQL_PASSWORD não definido no .env${NC}"
    exit 1
fi

# Verificar se o container está rodando
echo -e "${BLUE}🔍 Verificando se o container MySQL está rodando...${NC}"
if ! docker ps | grep -q eopix-mysql; then
    echo -e "${YELLOW}⚠️  Container MySQL não está rodando. Iniciando...${NC}"
    cd "${MYSQL_DIR}"
    docker-compose up -d mysql
    
    echo -e "${BLUE}⏳ Aguardando MySQL inicializar (pode levar 30-60 segundos)...${NC}"
    
    # Aguardar MySQL estar pronto (máximo 2 minutos)
    MAX_WAIT=120
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if docker exec eopix-mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent 2>/dev/null; then
            echo -e "${GREEN}✅ MySQL está pronto!${NC}"
            break
        fi
        echo -n "."
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo -e "${RED}❌ Timeout: MySQL não respondeu após ${MAX_WAIT} segundos${NC}"
        echo -e "${YELLOW}💡 Verifique os logs: docker-compose logs mysql${NC}"
        exit 1
    fi
    
    # Aguardar mais alguns segundos para garantir que está totalmente inicializado
    sleep 5
else
    echo -e "${GREEN}✅ Container MySQL está rodando${NC}"
fi

# Função para executar comandos SQL
execute_sql() {
    docker exec -i eopix-mysql mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "$@" 2>/dev/null
}

# Verificar se o banco de dados já existe
echo -e "${BLUE}🔍 Verificando banco de dados '${MYSQL_DATABASE}'...${NC}"
DB_EXISTS=$(execute_sql -e "SHOW DATABASES LIKE '${MYSQL_DATABASE}';" | grep -c "${MYSQL_DATABASE}" || echo "0")

if [ "$DB_EXISTS" -eq "0" ]; then
    echo -e "${BLUE}📦 Criando banco de dados '${MYSQL_DATABASE}'...${NC}"
    execute_sql -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    echo -e "${GREEN}✅ Banco de dados '${MYSQL_DATABASE}' criado${NC}"
else
    echo -e "${GREEN}✅ Banco de dados '${MYSQL_DATABASE}' já existe${NC}"
fi

# Verificar se o usuário já existe
echo -e "${BLUE}🔍 Verificando usuário '${MYSQL_USER}'...${NC}"
USER_EXISTS=$(execute_sql mysql -e "SELECT COUNT(*) FROM mysql.user WHERE User='${MYSQL_USER}';" | tail -1 | tr -d ' ' || echo "0")

if [ "$USER_EXISTS" -eq "0" ]; then
    echo -e "${BLUE}👤 Criando usuário '${MYSQL_USER}'...${NC}"
    execute_sql -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"
    echo -e "${GREEN}✅ Usuário '${MYSQL_USER}' criado${NC}"
else
    echo -e "${GREEN}✅ Usuário '${MYSQL_USER}' já existe${NC}"
    # Atualizar senha caso tenha mudado
    echo -e "${BLUE}🔐 Atualizando senha do usuário...${NC}"
    execute_sql -e "ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" 2>/dev/null || true
fi

# Conceder permissões
echo -e "${BLUE}🔑 Concedendo permissões ao usuário '${MYSQL_USER}' no banco '${MYSQL_DATABASE}'...${NC}"
execute_sql -e "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';"
execute_sql -e "FLUSH PRIVILEGES;"
echo -e "${GREEN}✅ Permissões concedidas${NC}"

# Testar conexão com o usuário da aplicação
echo -e "${BLUE}🧪 Testando conexão com usuário '${MYSQL_USER}'...${NC}"
if docker exec -i eopix-mysql mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "USE ${MYSQL_DATABASE}; SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Conexão testada com sucesso!${NC}"
else
    echo -e "${RED}❌ Erro ao testar conexão${NC}"
    exit 1
fi

# Mostrar informações
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ MySQL configurado com sucesso!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Informações de conexão:${NC}"
echo "  Host: $(docker inspect eopix-mysql | grep -A 20 '"Networks"' | grep '"IPAddress"' | head -1 | cut -d'"' -f4 || echo 'localhost')"
echo "  Porta: 3306"
echo "  Banco: ${MYSQL_DATABASE}"
echo "  Usuário: ${MYSQL_USER}"
echo ""
echo -e "${BLUE}🔗 Para conectar do servidor APP:${NC}"
echo "  DB_HOST=<IP_PRIVADO_DO_DB_SERVER>"
echo "  DB_PORT=3306"
echo "  DB_NAME=${MYSQL_DATABASE}"
echo "  DB_USER=${MYSQL_USER}"
echo "  DB_PASS=${MYSQL_PASSWORD}"
echo ""
echo -e "${GREEN}✨ Configuração concluída!${NC}"

exit 0
