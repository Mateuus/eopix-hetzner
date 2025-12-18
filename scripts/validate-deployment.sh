#!/bin/bash
# ============================================
# Script de Validação do Deploy
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Carregar .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [ ! -f .env ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

source .env

# Obter IPs dos servidores
APP_SERVER_IP=$(hcloud server describe "${APP_SERVER_NAME}" -o format='{{.PublicNet.IPv4.IP}}' 2>/dev/null || echo "")
DB_SERVER_IP=$(hcloud server describe "${DB_SERVER_NAME}" -o format='{{.PublicNet.IPv4.IP}}' 2>/dev/null || echo "")
DB_SERVER_PRIVATE_IP=$(hcloud server describe "${DB_SERVER_NAME}" -o format='{{.PrivateNet[0].IP}}' 2>/dev/null || echo "")

if [ -z "$APP_SERVER_IP" ] || [ -z "$DB_SERVER_IP" ]; then
    echo -e "${RED}❌ Não foi possível obter IPs dos servidores${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Validando deploy EoPix...${NC}"
echo ""

# Contadores
PASSED=0
FAILED=0

# Função de teste
test_check() {
    local name="$1"
    local command="$2"
    
    echo -n "  Testando: ${name}... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSOU${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC}"
        ((FAILED++))
        return 1
    fi
}

# ============================================
# 1. Testes de Conectividade
# ============================================
echo -e "${BLUE}1. Testes de Conectividade${NC}"

test_check "SSH APP Server" "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${APP_SERVER_IP} 'echo ok'"
test_check "SSH DB Server" "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${DB_SERVER_IP} 'echo ok'"

# ============================================
# 2. Testes do Servidor APP
# ============================================
echo ""
echo -e "${BLUE}2. Testes do Servidor APP${NC}"

test_check "Docker instalado" "ssh root@${APP_SERVER_IP} 'docker --version'"
test_check "Docker Compose instalado" "ssh root@${APP_SERVER_IP} 'docker-compose --version'"
test_check "Nginx rodando" "ssh root@${APP_SERVER_IP} 'docker ps | grep eopix-nginx'"
test_check "Backend 1 rodando" "ssh root@${APP_SERVER_IP} 'docker ps | grep eopix-backend-1'"
test_check "Backend 2 rodando" "ssh root@${APP_SERVER_IP} 'docker ps | grep eopix-backend-2'"
test_check "Backend 3 rodando" "ssh root@${APP_SERVER_IP} 'docker ps | grep eopix-backend-3'"

# Health checks locais
test_check "Health Backend 1" "ssh root@${APP_SERVER_IP} 'curl -sf http://localhost:3001/health > /dev/null'"
test_check "Health Backend 2" "ssh root@${APP_SERVER_IP} 'curl -sf http://localhost:3002/health > /dev/null'"
test_check "Health Backend 3" "ssh root@${APP_SERVER_IP} 'curl -sf http://localhost:3003/health > /dev/null'"
test_check "Health via Nginx" "ssh root@${APP_SERVER_IP} 'curl -sf http://localhost/health > /dev/null'"

# Health check público (se domínio configurado)
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "api.seudominio.com" ]; then
    test_check "Health via domínio" "curl -sf http://${DOMAIN}/health > /dev/null"
fi

# ============================================
# 3. Testes do Servidor DB
# ============================================
echo ""
echo -e "${BLUE}3. Testes do Servidor DB${NC}"

test_check "Docker instalado" "ssh root@${DB_SERVER_IP} 'docker --version'"
test_check "Docker Compose instalado" "ssh root@${DB_SERVER_IP} 'docker-compose --version'"
test_check "MySQL rodando" "ssh root@${DB_SERVER_IP} 'docker ps | grep eopix-mysql'"
test_check "Valkey rodando" "ssh root@${DB_SERVER_IP} 'docker ps | grep eopix-valkey'"

# Teste de conexão MySQL (local)
test_check "MySQL acessível" "ssh root@${DB_SERVER_IP} 'docker exec eopix-mysql mysqladmin ping -h localhost -uroot -p${MYSQL_ROOT_PASSWORD} 2>/dev/null'"

# Teste de conexão MySQL (do APP server)
if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
    test_check "MySQL acessível do APP" "ssh root@${APP_SERVER_IP} 'nc -zv ${DB_SERVER_PRIVATE_IP} 3306 2>&1 | grep -q succeeded'"
fi

# Teste Valkey (local)
test_check "Valkey acessível" "ssh root@${DB_SERVER_IP} 'docker exec eopix-valkey valkey-cli ping 2>/dev/null | grep -q PONG'"

# Teste Valkey (do APP server)
if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
    test_check "Valkey acessível do APP" "ssh root@${APP_SERVER_IP} 'nc -zv ${DB_SERVER_PRIVATE_IP} 6379 2>&1 | grep -q succeeded'"
fi

# ============================================
# 4. Testes de Backup
# ============================================
echo ""
echo -e "${BLUE}4. Testes de Backup${NC}"

test_check "Script de backup existe" "ssh root@${DB_SERVER_IP} 'test -f /opt/eopix/db-server/backup.sh'"
test_check "Script de backup executável" "ssh root@${DB_SERVER_IP} 'test -x /opt/eopix/db-server/backup.sh'"
test_check "Cron configurado" "ssh root@${DB_SERVER_IP} 'crontab -l 2>/dev/null | grep -q backup.sh'"

# ============================================
# 5. Testes de Firewall
# ============================================
echo ""
echo -e "${BLUE}5. Testes de Firewall${NC}"

test_check "UFW ativo no APP" "ssh root@${APP_SERVER_IP} 'ufw status | grep -q Status: active'"
test_check "UFW ativo no DB" "ssh root@${DB_SERVER_IP} 'ufw status | grep -q Status: active'"

# ============================================
# Resumo
# ============================================
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Resumo da Validação${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}✅ Testes passados: ${PASSED}${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}❌ Testes falhados: ${FAILED}${NC}"
else
    echo -e "  ${GREEN}✅ Testes falhados: 0${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 Todos os testes passaram! Deploy validado com sucesso!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Alguns testes falharam. Revise os erros acima.${NC}"
    exit 1
fi
