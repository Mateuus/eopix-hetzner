# 📤 Preparar para GitHub

## ✅ Checklist Antes de Subir

- [x] Arquivos desnecessários removidos
- [x] `.gitignore` configurado
- [x] README.md atualizado
- [x] Configurações sensíveis no `.gitignore`

## 🚀 Comandos para Subir

```bash
cd /home/mateuus/projects/eopix/eopix_hetzner

# Inicializar Git (se ainda não foi feito)
git init

# Adicionar tudo
git add .

# Verificar o que será commitado (importante!)
git status

# Commit inicial
git commit -m "feat: Infraestrutura Hetzner com Traefik e SSL automático"

# Renomear branch para main
git branch -M main

# Adicionar remote
git remote add origin https://github.com/Mateuus/eopix-hetzner.git

# Push
git push -u origin main
```

## ⚠️ Verificar Antes de Commit

```bash
# Ver o que será commitado
git status

# Verificar se .env não está incluído
git status | grep -i "\.env$"

# Se .env aparecer, adicionar ao .gitignore
echo ".env" >> .gitignore
git add .gitignore
```

## 📋 Arquivos que Serão Commitados

### ✅ Serão Commitados (Seguros)
- Scripts de criação e setup
- Docker Compose files
- Configurações de exemplo (.env.example)
- Documentação
- Scripts helper

### ❌ NÃO Serão Commitados (.gitignore)
- `.env` (com tokens e senhas)
- `letsencrypt/` (certificados)
- `*.log` (logs)
- `backups/` (backups do MySQL)
- Arquivos temporários

## 🔒 Segurança

Certifique-se de que:
- ✅ `.env` está no `.gitignore`
- ✅ Nenhum token/senha está hardcoded
- ✅ Apenas `.env.example` será commitado
- ✅ Certificados SSL não serão commitados

## 📝 Após Subir

Outros desenvolvedores podem:

```bash
# Clonar
git clone https://github.com/Mateuus/eopix-hetzner.git
cd eopix-hetzner

# Configurar
cp .env.example .env
nano .env

# Usar
./create-servers.sh
```
