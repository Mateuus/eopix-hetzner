#!/bin/bash
# ============================================
# Script para Destruir Toda a Infraestrutura Hetzner
# ATENÇÃO: Isso vai deletar TUDO!
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  DESTRUIÇÃO COMPLETA DA INFRAESTRUTURA${NC}"
echo -e "${RED}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Este script vai deletar:${NC}"
echo "  - Servidores (eopix-app, eopix-db)"
echo "  - Load Balancer (eopix-lb)"
echo "  - Firewalls (eopix-app-firewall, eopix-db-firewall)"
echo "  - Rede Privada (eopix-network)"
echo ""
read -p "Tem CERTEZA que deseja continuar? (digite 'DESTRUIR' para confirmar): " CONFIRM

if [ "$CONFIRM" != "DESTRUIR" ]; then
    echo -e "${YELLOW}Operação cancelada${NC}"
    exit 0
fi

# Verificar se hcloud está instalado
if ! command -v hcloud &> /dev/null; then
    echo -e "${RED}❌ hcloud CLI não está instalado${NC}"
    exit 1
fi

# Verificar autenticação
if ! hcloud server list >/dev/null 2>&1; then
    echo -e "${RED}❌ Erro de autenticação do hcloud${NC}"
    echo ""
    echo -e "${BLUE}📝 Configurando autenticação...${NC}"
    
    # Tentar carregar token do .env
    if [ -f .env ]; then
        source .env 2>/dev/null || true
        if [ -n "$HCLOUD_TOKEN" ]; then
            echo -e "${BLUE}  Token encontrado no .env${NC}"
            export HCLOUD_TOKEN="$HCLOUD_TOKEN"
            hcloud context create eopix 2>/dev/null || true
            hcloud context use eopix 2>/dev/null || true
        fi
    fi
    
    # Verificar novamente
    if ! hcloud server list >/dev/null 2>&1; then
        echo ""
        echo -e "${YELLOW}⚠️  Ainda não autenticado. Opções:${NC}"
        echo ""
        echo "  1. Obter token: https://console.hetzner.cloud/ → Security → API Tokens"
        echo "  2. Configurar:"
        echo "     hcloud context create eopix --token SEU_TOKEN"
        echo "     hcloud context use eopix"
        echo ""
        echo "  3. Ou adicionar no .env:"
        echo "     HCLOUD_TOKEN=seu_token_aqui"
        echo ""
        exit 1
    fi
fi

echo -e "${GREEN}✅ Autenticação OK${NC}"

echo ""
echo -e "${BLUE}🗑️  Iniciando destruição...${NC}"
echo ""

# ============================================
# Deletar Servidores
# ============================================
echo -e "${BLUE}🖥️  Deletando servidores...${NC}"

for SERVER in "eopix-app" "eopix-db"; do
    if hcloud server describe "$SERVER" >/dev/null 2>&1; then
        echo -e "${YELLOW}  Deletando servidor: $SERVER${NC}"
        hcloud server delete "$SERVER" 2>/dev/null || true
        echo -e "${GREEN}  ✅ Servidor $SERVER deletado${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Servidor $SERVER não encontrado${NC}"
    fi
done

# Aguardar servidores serem deletados
echo "⏳ Aguardando servidores serem deletados..."
sleep 10

# ============================================
# Deletar Load Balancer
# ============================================
echo ""
echo -e "${BLUE}⚖️  Deletando Load Balancer...${NC}"

if hcloud load-balancer describe "eopix-lb" >/dev/null 2>&1; then
    echo -e "${YELLOW}  Deletando Load Balancer: eopix-lb${NC}"
    hcloud load-balancer delete "eopix-lb" 2>/dev/null || true
    echo -e "${GREEN}  ✅ Load Balancer deletado${NC}"
else
    echo -e "${YELLOW}  ⚠️  Load Balancer não encontrado${NC}"
fi

# ============================================
# Deletar Firewalls
# ============================================
echo ""
echo -e "${BLUE}🔥 Deletando Firewalls...${NC}"

for FW in "eopix-app-firewall" "eopix-db-firewall"; do
    if hcloud firewall describe "$FW" >/dev/null 2>&1; then
        echo -e "${YELLOW}  Deletando firewall: $FW${NC}"
        hcloud firewall delete "$FW" 2>/dev/null || true
        echo -e "${GREEN}  ✅ Firewall $FW deletado${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Firewall $FW não encontrado${NC}"
    fi
done

# ============================================
# Deletar Rede Privada
# ============================================
echo ""
echo -e "${BLUE}🌐 Deletando Rede Privada...${NC}"

if hcloud network describe "eopix-network" >/dev/null 2>&1; then
    echo -e "${YELLOW}  Deletando rede: eopix-network${NC}"
    hcloud network delete "eopix-network" 2>/dev/null || true
    echo -e "${GREEN}  ✅ Rede deletada${NC}"
else
    echo -e "${YELLOW}  ⚠️  Rede não encontrada${NC}"
fi

# ============================================
# Verificar se tudo foi deletado
# ============================================
echo ""
echo -e "${BLUE}🔍 Verificando recursos restantes...${NC}"

REMAINING=0

if hcloud server describe "eopix-app" >/dev/null 2>&1 || hcloud server describe "eopix-db" >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠️  Ainda há servidores${NC}"
    REMAINING=1
fi

if hcloud load-balancer describe "eopix-lb" >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠️  Ainda há Load Balancer${NC}"
    REMAINING=1
fi

if hcloud firewall describe "eopix-app-firewall" >/dev/null 2>&1 || hcloud firewall describe "eopix-db-firewall" >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠️  Ainda há firewalls${NC}"
    REMAINING=1
fi

if hcloud network describe "eopix-network" >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠️  Ainda há rede privada${NC}"
    REMAINING=1
fi

if [ $REMAINING -eq 0 ]; then
    echo -e "${GREEN}  ✅ Todos os recursos foram deletados${NC}"
else
    echo -e "${YELLOW}  ⚠️  Alguns recursos ainda existem (pode levar alguns minutos para serem removidos)${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Destruição concluída!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📝 Próximos passos:${NC}"
echo ""
echo "  1. Execute: ./create-servers.sh"
echo "     (Agora com Traefik ao invés de Nginx)"
echo ""
echo "  2. Aguarde a criação completa"
echo ""
echo -e "${GREEN}✨ Pronto para recriar tudo com Traefik!${NC}"
echo ""
