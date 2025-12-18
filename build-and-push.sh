#!/bin/bash
# ============================================
# Script para Build e Push da Imagem Docker
# EoPix Backend
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações padrão
REGISTRY="${1:-docker.io}"  # docker.io ou ghcr.io
USERNAME="${2}"
IMAGE_NAME="${3:-eopix-backend}"
TAG="${4:-latest}"

if [ -z "$USERNAME" ]; then
    echo -e "${RED}❌ Uso: $0 <registry> <username> [image-name] [tag]${NC}"
    echo ""
    echo "Exemplos:"
    echo "  $0 docker.io seu-usuario"
    echo "  $0 ghcr.io seu-usuario eopix-backend v1.0.0"
    echo ""
    echo "Registries suportados:"
    echo "  - docker.io (Docker Hub)"
    echo "  - ghcr.io (GitHub Container Registry)"
    exit 1
fi

FULL_IMAGE_NAME="${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}"

echo -e "${BLUE}🐳 Build e Push da Imagem Docker${NC}"
echo ""
echo "  Registry: ${REGISTRY}"
echo "  Username: ${USERNAME}"
echo "  Image: ${IMAGE_NAME}"
echo "  Tag: ${TAG}"
echo "  Full name: ${FULL_IMAGE_NAME}"
echo ""

# Verificar se está no diretório correto
if [ ! -f "../eopix_backend/Dockerfile" ]; then
    echo -e "${RED}❌ Dockerfile não encontrado!${NC}"
    echo "Execute este script do diretório eopix_hetzner"
    exit 1
fi

cd ../eopix_backend

# Fazer login no registry
echo -e "${BLUE}🔐 Fazendo login no registry...${NC}"
if [ "$REGISTRY" = "ghcr.io" ]; then
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}⚠️  GITHUB_TOKEN não definido${NC}"
        echo "Crie um token em: https://github.com/settings/tokens"
        echo "Permissões: read:packages, write:packages"
        read -p "Cole o token aqui: " GITHUB_TOKEN
    fi
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$USERNAME" --password-stdin
else
    docker login
fi

# Build da imagem
echo ""
echo -e "${BLUE}🔨 Building image...${NC}"
docker build -t "${FULL_IMAGE_NAME}" -f Dockerfile --target production .

# Push da imagem
echo ""
echo -e "${BLUE}📤 Pushing to ${FULL_IMAGE_NAME}...${NC}"
docker push "${FULL_IMAGE_NAME}"

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Imagem buildada e enviada!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📝 Próximos passos:${NC}"
echo ""
echo "1. No servidor APP, edite o .env:"
echo "   BACKEND_IMAGE=${FULL_IMAGE_NAME}"
echo ""
echo "2. No servidor, execute:"
echo "   cd /opt/eopix/app-server"
echo "   docker-compose pull"
echo "   docker-compose up -d"
echo ""
echo -e "${GREEN}✨ Pronto!${NC}"
