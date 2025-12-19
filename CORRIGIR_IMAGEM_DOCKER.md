# ✅ Correção: Imagem Docker não encontrada

## 🔍 Problema identificado

O script estava falhando com:
```
Error response from daemon: pull access denied for eopix_backend-backend, repository does not exist or may require 'docker login'
```

## 🔍 Causa

A imagem `eopix_backend-backend:latest` não existe no Docker Hub. A imagem correta é `mateuus27/eopix-backend:latest`.

## ✅ Solução implementada

### Arquivos atualizados:

1. **`app-server/docker-compose.traefik.yml`**
   - ✅ Atualizado: `eopix_backend-backend:latest` → `mateuus27/eopix-backend:latest`

2. **`scripts/setup-app-server-traefik.sh`**
   - ✅ Atualizado: `.env` básico agora usa `mateuus27/eopix-backend:latest`

3. **Arquivos `.env*`**
   - ✅ `.env.example`
   - ✅ `.env.prod`
   - ✅ `app-server/.env.prod`
   - ✅ `app-server/.env.example`

4. **Documentação**
   - ✅ `BUILD_AND_PUSH_IMAGE.md` atualizado

## 📋 Mudanças

### Antes:
```yaml
image: ${BACKEND_IMAGE:-eopix_backend-backend:latest}
```

### Agora:
```yaml
image: ${BACKEND_IMAGE:-mateuus27/eopix-backend:latest}
```

## 🚀 Como usar

### Opção 1: Usar imagem do Docker Hub (pública)
```bash
# No .env
BACKEND_IMAGE=mateuus27/eopix-backend:latest
```

### Opção 2: Usar imagem privada (requer login)
```bash
# Fazer login no Docker Hub
docker login

# No .env
BACKEND_IMAGE=mateuus27/eopix-backend:latest
```

### Opção 3: Usar imagem de outro registry
```bash
# No .env
BACKEND_IMAGE=ghcr.io/mateuus27/eopix-backend:latest
# ou
BACKEND_IMAGE=registry.eopix.me/eopix-backend:latest
```

## ✅ Checklist

- [x] `docker-compose.traefik.yml` atualizado
- [x] `setup-app-server-traefik.sh` atualizado
- [x] Todos os arquivos `.env*` atualizados
- [x] Documentação atualizada
- [x] Imagem padrão: `mateuus27/eopix-backend:latest`

## 📝 Nota

**Se a imagem for privada:**
1. Faça login no Docker Hub antes de executar o script:
   ```bash
   docker login
   ```

2. Ou configure no servidor após o setup:
   ```bash
   ssh root@<IP_SERVIDOR>
   docker login
   cd /opt/eopix/app-server
   docker compose pull
   docker compose up -d
   ```

**Se a imagem não existir ainda:**
1. Build e push da imagem primeiro:
   ```bash
   cd eopix_backend
   docker build -t mateuus27/eopix-backend:latest .
   docker push mateuus27/eopix-backend:latest
   ```

Tudo atualizado! 🎉
