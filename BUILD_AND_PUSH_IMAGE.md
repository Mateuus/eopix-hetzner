# 🐳 Build e Push da Imagem Docker do Backend

A imagem Docker do backend precisa ser construída e enviada para um registry antes de usar no servidor.

## 📋 Opções

### Opção 1: Build e Push para Docker Hub (Recomendado)

#### 1.1. Fazer Login no Docker Hub

```bash
docker login
```

#### 1.2. Build da Imagem

No diretório do backend:

```bash
cd /home/mateuus/projects/eopix/eopix_backend

# Build da imagem de produção
docker build -t seu-usuario/eopix-backend:latest -f Dockerfile --target production .

# Ou com tag específica
docker build -t seu-usuario/eopix-backend:v1.0.0 -f Dockerfile --target production .
```

#### 1.3. Push para Docker Hub

```bash
docker push seu-usuario/eopix-backend:latest
```

#### 1.4. Configurar no Servidor

No servidor APP, edite o `.env`:

```bash
BACKEND_IMAGE=seu-usuario/eopix-backend:latest
```

### Opção 2: Build e Push para GitHub Container Registry

#### 2.1. Fazer Login no GitHub Container Registry

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u seu-usuario --password-stdin
```

#### 2.2. Build e Push

```bash
cd /home/mateuus/projects/eopix/eopix_backend

# Build
docker build -t ghcr.io/seu-usuario/eopix-backend:latest -f Dockerfile --target production .

# Push
docker push ghcr.io/seu-usuario/eopix-backend:latest
```

#### 2.3. Configurar no Servidor

```bash
BACKEND_IMAGE=ghcr.io/seu-usuario/eopix-backend:latest
```

### Opção 3: Build Direto no Servidor (Alternativa)

Se você não quiser usar um registry, pode fazer build diretamente no servidor:

#### 3.1. No Servidor APP

```bash
# Instalar git (se não tiver)
apt-get update && apt-get install -y git

# Clonar ou fazer upload do código
cd /opt
git clone seu-repositorio.git eopix-backend
# OU fazer upload via scp/rsync

# Build da imagem
cd /opt/eopix-backend
docker build -t eopix-backend:latest -f Dockerfile --target production .

# Atualizar docker-compose.yml para usar build ao invés de image
```

#### 3.2. Modificar docker-compose.yml

No servidor, edite `/opt/eopix/app-server/docker-compose.yml`:

```yaml
backend1:
  build:
    context: /opt/eopix-backend
    dockerfile: Dockerfile
    target: production
  # Remover a linha: image: ${BACKEND_IMAGE:-mateuus27/eopix-backend:latest}
```

## 🚀 Script Automatizado

Crie um script para facilitar:

```bash
cat > /home/mateuus/projects/eopix/eopix_hetzner/build-and-push.sh << 'EOF'
#!/bin/bash
# Script para build e push da imagem Docker

set -e

REGISTRY="${1:-docker.io}"  # docker.io ou ghcr.io
USERNAME="${2:-seu-usuario}"
IMAGE_NAME="${3:-eopix-backend}"
TAG="${4:-latest}"

cd /home/mateuus/projects/eopix/eopix_backend

echo "🔨 Building image..."
docker build -t ${USERNAME}/${IMAGE_NAME}:${TAG} -f Dockerfile --target production .

echo "📤 Pushing to ${REGISTRY}/${USERNAME}/${IMAGE_NAME}:${TAG}..."
docker push ${USERNAME}/${IMAGE_NAME}:${TAG}

echo "✅ Done! Use this in .env:"
echo "BACKEND_IMAGE=${USERNAME}/${IMAGE_NAME}:${TAG}"
EOF

chmod +x build-and-push.sh
```

Uso:

```bash
# Docker Hub
./build-and-push.sh docker.io seu-usuario eopix-backend latest

# GitHub Container Registry
./build-and-push.sh ghcr.io seu-usuario eopix-backend latest
```

## 📝 Checklist

- [ ] Docker instalado e funcionando
- [ ] Login no registry (Docker Hub ou GHCR)
- [ ] Build da imagem de produção
- [ ] Push da imagem para o registry
- [ ] `.env` no servidor configurado com `BACKEND_IMAGE` correto
- [ ] `docker-compose pull` no servidor para baixar a imagem
- [ ] `docker-compose up -d` para iniciar

## 🔍 Verificar Imagem

```bash
# Ver imagens locais
docker images | grep eopix

# Testar imagem localmente
docker run --rm -p 4000:4000 seu-usuario/eopix-backend:latest
```
