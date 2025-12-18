#!/bin/bash
# ============================================
# Script para Configurar Autenticação hcloud
# ============================================

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔐 Configurando autenticação hcloud...${NC}"
echo ""

# Verificar se hcloud está instalado
if ! command -v hcloud &> /dev/null; then
    echo -e "${RED}❌ hcloud CLI não está instalado${NC}"
    echo ""
    echo "Instale:"
    echo "  curl -fsSL https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar -xz"
    echo "  sudo mv hcloud /usr/local/bin/"
    exit 1
fi

# Verificar se já está autenticado
if hcloud server list >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Já está autenticado!${NC}"
    echo ""
    echo "Contexto ativo:"
    hcloud context active
    exit 0
fi

# Tentar carregar do .env
if [ -f .env ]; then
    echo -e "${BLUE}📄 Carregando token do .env...${NC}"
    source .env 2>/dev/null || true
    
    if [ -n "$HCLOUD_TOKEN" ]; then
        echo -e "${GREEN}✅ Token encontrado no .env${NC}"
        
        # Exportar token
        export HCLOUD_TOKEN="$HCLOUD_TOKEN"
        
        # Criar ou usar contexto
        if hcloud context describe eopix >/dev/null 2>&1; then
            echo -e "${BLUE}  Usando contexto existente: eopix${NC}"
            hcloud context use eopix
        else
            echo -e "${BLUE}  Criando contexto: eopix${NC}"
            hcloud context create eopix 2>/dev/null || true
            hcloud context use eopix
        fi
        
        # Verificar
        if hcloud server list >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Autenticação configurada com sucesso!${NC}"
            exit 0
        fi
    fi
fi

# Se não funcionou, pedir token manualmente
echo -e "${YELLOW}⚠️  Token não encontrado ou inválido${NC}"
echo ""
echo -e "${BLUE}📝 Para obter um token:${NC}"
echo ""
echo "  1. Acesse: https://console.hetzner.cloud/"
echo "  2. Vá em: Security → API Tokens"
echo "  3. Clique em: Generate API Token"
echo "  4. Dê um nome (ex: eopix-deployment)"
echo "  5. Selecione: Read & Write"
echo "  6. Copie o token (ele só aparece uma vez!)"
echo ""
read -p "Cole o token aqui: " TOKEN

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Token vazio${NC}"
    exit 1
fi

# Criar contexto usando variável de ambiente
echo ""
echo -e "${BLUE}🔧 Criando contexto...${NC}"

# Exportar token
export HCLOUD_TOKEN="$TOKEN"

# Criar contexto (hcloud vai usar HCLOUD_TOKEN automaticamente)
if hcloud context describe eopix >/dev/null 2>&1; then
    echo -e "${BLUE}  Contexto já existe, usando...${NC}"
    hcloud context use eopix
else
    echo -e "${BLUE}  Criando novo contexto...${NC}"
    # hcloud context create pede token interativamente, mas usa HCLOUD_TOKEN se estiver definido
    echo "$TOKEN" | hcloud context create eopix 2>/dev/null || {
        # Se falhar, tentar criar sem token e depois usar
        hcloud context create eopix <<< "$TOKEN" 2>/dev/null || {
            # Último recurso: criar contexto vazio e usar token via env
            hcloud context create eopix 2>/dev/null || true
            hcloud context use eopix
        }
    }
fi

# Verificar (com token exportado)
if HCLOUD_TOKEN="$TOKEN" hcloud server list >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Autenticação configurada com sucesso!${NC}"
    echo ""
    echo -e "${BLUE}💡 Dica: Adicione no .env para não precisar fazer isso novamente:${NC}"
    echo "  HCLOUD_TOKEN=$TOKEN"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE: Exporte HCLOUD_TOKEN antes de usar hcloud:${NC}"
    echo "  export HCLOUD_TOKEN=\"$TOKEN\""
else
    echo -e "${RED}❌ Erro ao autenticar. Verifique o token.${NC}"
    echo ""
    echo -e "${YELLOW}💡 Tente manualmente:${NC}"
    echo "  export HCLOUD_TOKEN=\"$TOKEN\""
    echo "  hcloud server list"
    exit 1
fi
