# ✅ Correção: docker-compose: command not found

## 🔍 Problema identificado

O script estava falhando com:
```
/tmp/setup-app-server-traefik.sh: line 327: docker-compose: command not found
```

## 🔍 Causa

O script instala `docker-compose-plugin` (que fornece `docker compose` sem hífen), mas depois tenta usar `docker-compose` (com hífen). Em versões mais recentes do Docker, o comando é `docker compose` (sem hífen), não `docker-compose`.

## ✅ Solução implementada

### 1. Detecção automática do comando correto

**Scripts corrigidos:**
- `setup-app-server-traefik.sh`
- `setup-db-server.sh`

**O que foi feito:**
- ✅ Detecta se `docker compose` (plugin) está disponível
- ✅ Detecta se `docker-compose` (standalone) está disponível
- ✅ Cria função `docker_compose()` que usa o comando correto
- ✅ Todos os usos de `docker-compose` foram substituídos pela função

### 2. Função compatível

```bash
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
```

## 📋 Mudanças

### Antes:
```bash
docker-compose up -d
docker-compose ps
docker-compose logs -f
```

### Agora:
```bash
docker_compose up -d  # Usa o comando correto automaticamente
docker compose ps     # Ou docker-compose, dependendo do que está instalado
docker compose logs -f
```

## 🚀 Resultado

**Antes:**
- ❌ Script falhava se `docker-compose` não estivesse instalado
- ❌ Não funcionava com `docker compose` (plugin)

**Agora:**
- ✅ Funciona com `docker compose` (plugin) - versão moderna
- ✅ Funciona com `docker-compose` (standalone) - versão antiga
- ✅ Detecta automaticamente qual está disponível
- ✅ Instala standalone se nenhum estiver disponível

## ✅ Checklist

- [x] Detecção automática de `docker compose` (plugin)
- [x] Detecção automática de `docker-compose` (standalone)
- [x] Função `docker_compose()` criada
- [x] Todos os usos atualizados
- [x] Scripts APP e DB corrigidos
- [x] Mensagens de ajuda atualizadas

## 📝 Nota

**Docker Compose V2 (plugin):**
- Comando: `docker compose` (sem hífen)
- Instalado via: `docker-compose-plugin`
- Versão mais recente e recomendada

**Docker Compose V1 (standalone):**
- Comando: `docker-compose` (com hífen)
- Instalado via: binário standalone
- Versão antiga, ainda suportada

O script agora funciona com ambas as versões! 🎉
