# 📥 Baixar Configurações do Git

Os scripts agora suportam **baixar arquivos de configuração diretamente do repositório Git** em vez de copiar via SCP.

## 🚀 Como Funciona

### Opção 1: Usar Git (Recomendado)

1. **Configure no `.env`:**

```bash
# No arquivo .env
GIT_REPO=https://github.com/Mateuus/eopix-hetzner.git
GIT_BRANCH=main
```

2. **Execute o script:**

```bash
./create-servers.sh
```

O script vai:
- ✅ Clonar o repositório no servidor
- ✅ Baixar os arquivos de `app-server/` e `db-server/`
- ✅ Copiar para `/opt/eopix/app-server` e `/opt/eopix/db-server`

### Opção 2: Usar SCP (Fallback)

Se `GIT_REPO` não estiver definido no `.env`, o script usa o método antigo:
- ✅ Copia arquivos locais via SCP
- ✅ Funciona mesmo sem Git configurado

## 📋 Vantagens do Git

- ✅ **Sempre atualizado**: Puxa a versão mais recente do repositório
- ✅ **Versionamento**: Fácil rastrear mudanças
- ✅ **Colaboração**: Múltiplos desenvolvedores podem atualizar
- ✅ **Sem SCP**: Não precisa ter arquivos locais sincronizados

## 🔄 Atualizar Configurações

Se você atualizar arquivos no Git e quiser atualizar nos servidores:

```bash
# Conectar no servidor APP
./ssh-app.sh

# O script já faz git pull automaticamente na próxima execução
# Ou manualmente:
cd /tmp/eopix-hetzner-git
git pull origin main
cp -r app-server/* /opt/eopix/app-server/
cd /opt/eopix/app-server
docker-compose restart
```

## ⚙️ Configuração

### No `.env.example`:

```bash
# Repositório Git (opcional - se definido, os arquivos serão baixados do Git)
# Se não definido, os arquivos serão copiados via SCP
GIT_REPO=https://github.com/Mateuus/eopix-hetzner.git
GIT_BRANCH=main
```

### O que é baixado:

- ✅ `app-server/docker-compose.traefik.yml`
- ✅ `app-server/.env.example`
- ✅ `db-server/docker-compose.yml`
- ✅ `db-server/my.cnf`
- ✅ `db-server/backup.sh`
- ✅ Todos os arquivos de configuração necessários

## 🔒 Segurança

- ✅ `.env` **não** é commitado (está no `.gitignore`)
- ✅ Certificados SSL **não** são commitados
- ✅ Apenas arquivos de configuração são baixados
- ✅ Cada servidor cria seu próprio `.env` a partir do `.env.example`

## 📝 Fluxo Completo

1. **Desenvolvedor atualiza** `docker-compose.traefik.yml` no Git
2. **Faz commit e push:**
   ```bash
   git add app-server/docker-compose.traefik.yml
   git commit -m "feat: atualizar configuração Traefik"
   git push origin main
   ```
3. **No servidor**, na próxima execução do `create-servers.sh`:
   - Script clona/atualiza do Git
   - Copia arquivos atualizados
   - Reinicia serviços se necessário

## 🐛 Troubleshooting

### Erro: "Falha ao clonar Git"

O script automaticamente usa SCP como fallback. Verifique:
- ✅ Repositório é público ou servidor tem acesso
- ✅ URL do Git está correta
- ✅ Branch existe

### Erro: "Arquivos não encontrados"

Se usar Git, verifique:
- ✅ Estrutura de diretórios no Git está correta
- ✅ `app-server/` e `db-server/` existem no repositório

## ✅ Resumo

- **Com Git**: Configure `GIT_REPO` e `GIT_BRANCH` no `.env`
- **Sem Git**: Deixe vazio, script usa SCP automaticamente
- **Sempre funciona**: Fallback automático se Git falhar
