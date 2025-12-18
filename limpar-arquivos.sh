#!/bin/bash
# ============================================
# Script para Limpar Arquivos Desnecessários
# Remove arquivos relacionados a Nginx (agora usamos Traefik)
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧹 Limpando arquivos desnecessários...${NC}"
echo ""

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Arquivos para remover (relacionados a Nginx/SSL manual)
FILES_TO_REMOVE=(
    # Nginx config
    "app-server/nginx.conf"
    "app-server/docker-compose.yml"  # Antigo do Nginx
    
    # Scripts Nginx/SSL manual
    "scripts/setup-ssl.sh"
    "scripts/ativar-ssl.sh"
    "scripts/verificar-ssl.sh"
    "scripts/fix-nginx-ssl.sh"
    "scripts/setup-app-server.sh"  # Versão antiga com Nginx
    "scripts/configurar-lb-https.sh"
    
    # Documentação Nginx/SSL manual
    "ATIVAR_SSL.md"
    "ATIVAR_SSL_AGORA.md"
    "ATIVAR_SSL_RAPIDO.md"
    "INSTALAR_SSL.md"
    "INSTALAR_SSL_RAPIDO.md"
    "CORRIGIR_NGINX_SSL.md"
    "CORRIGIR_SSL_PARTIAL.md"
    "CORRIGIR_AGORA.md"
    "SOLUCAO_RAPIDA_NGINX.md"
    "TESTAR_NGINX_AGORA.md"
    "INICIAR_NGINX_AGORA.md"
    "ATUALIZAR_DOMINIO.md"
    "CONFIGURAR_LB_HTTPS.md"
    "ADICIONAR_HTTPS_LB_MANUAL.md"
    "CORRIGIR_LB_HTTPS.md"
    
    # Documentação redundante
    "AUTENTICAR_HCLOUD.md"
    "AUTENTICAR_RAPIDO.md"
    "AUTENTICAR_MANUAL.md"
    "CORRIGIR_AUTENTICACAO_HCLOUD.md"
    "DIAGNOSTICAR_503.md"
    "DIAGNOSTICO.md"
    "COMO_TESTAR.md"
    "REINICIAR_SERVICOS.md"
    "VERIFICAR_STATUS.md"
    "PRIMEIRO_ACESSO.md"
    "SSH_QUICK_GUIDE.md"
    "CONFIGURAR_APP.md"
    "ESTRUTURA.md"
    "CHECKLIST.md"
    "MIGRAR_PARA_TRAEFIK.md"
    "TRAEFIK_VS_NGINX.md"
    
    # Scripts de teste antigos
    "test-quick.sh"
    "test-services.sh"
    
    # Traefik duplicado (já está em app-server/)
    "traefik/docker-compose.traefik.yml"
)

# Contadores
REMOVED=0
NOT_FOUND=0

echo -e "${BLUE}📋 Arquivos a serem removidos:${NC}"
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        echo "  - $file"
    fi
done
echo ""

read -p "Deseja continuar? (s/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operação cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🗑️  Removendo arquivos...${NC}"

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        rm -rf "$file"
        echo -e "${GREEN}  ✅ Removido: $file${NC}"
        ((REMOVED++))
    else
        echo -e "${YELLOW}  ⚠️  Não encontrado: $file${NC}"
        ((NOT_FOUND++))
    fi
done

# Remover diretório traefik se estiver vazio
if [ -d "traefik" ] && [ -z "$(ls -A traefik)" ]; then
    rmdir traefik
    echo -e "${GREEN}  ✅ Diretório vazio removido: traefik/${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Limpeza concluída!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📊 Estatísticas:${NC}"
echo "  Removidos: ${REMOVED}"
echo "  Não encontrados: ${NOT_FOUND}"
echo ""
echo -e "${BLUE}📁 Arquivos essenciais mantidos:${NC}"
echo "  ✅ create-servers.sh"
echo "  ✅ destroy-all.sh"
echo "  ✅ configurar-hcloud.sh"
echo "  ✅ app-server/docker-compose.traefik.yml"
echo "  ✅ scripts/setup-app-server-traefik.sh"
echo "  ✅ scripts/setup-db-server.sh"
echo "  ✅ README.md"
echo "  ✅ RECRIAR_COM_TRAEFIK.md"
echo "  ✅ INICIO_RAPIDO_TRAEFIK.md"
echo ""
