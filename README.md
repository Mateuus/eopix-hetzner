# eopix-hetzner

# 🚀 EoPix - Deploy Hetzner (Docker + Traefik + Node.js)

Guia completo e executável para deploy em produção na Hetzner Cloud com **Traefik** (SSL automático).

## 📋 Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│           Hetzner Load Balancer (TCP 443)              │
│              api-prod.eopix.me                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  CPX31 (APP Server) - Ubuntu 22.04                     │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Traefik (Reverse Proxy + SSL Automático)        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │  │
│  │  │Backend 1 │  │Backend 2 │  │Backend 3 │      │  │
│  │  │ :4000    │  │ :4000    │  │ :4000    │      │  │
│  │  └──────────┘  └──────────┘  └──────────┘      │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │ (Rede Privada)
                     ▼
┌─────────────────────────────────────────────────────────┐
│  CPX21 (DB Server) - Ubuntu 22.04                     │
│  ┌──────────────┐  ┌──────────────┐                  │
│  │  MySQL 8     │  │  Valkey      │                  │
│  │  (Master)    │  │  (Redis)     │                  │
│  │  :3306       │  │  :6379       │                  │
│  └──────────────┘  └──────────────┘                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Backup Automático (mysqldump + gzip)           │  │
│  │  Retenção: 14 dias                              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## ✨ Características

- ✅ **Traefik** com SSL automático (Let's Encrypt)
- ✅ **Service Discovery** automático
- ✅ **Dashboard Traefik** para monitoramento
- ✅ **3 instâncias** do backend Node.js
- ✅ **MySQL 8** com binlog habilitado
- ✅ **Valkey/Redis** para cache
- ✅ **Backup automático** do MySQL
- ✅ **Rede privada** entre servidores
- ✅ **Load Balancer** Hetzner

## 🎯 Pré-requisitos

1. **Conta Hetzner Cloud** com API Token
2. **Hetzner CLI (hcloud)** instalado e autenticado
3. **SSH Key** configurada no Hetzner Cloud
4. **Domínio** `api-prod.eopix.me` (ou configurar no `.env`)

## 🚀 Quick Start

### 1. Configurar

```bash
# Copiar .env.example
cp .env.example .env

# Editar .env
nano .env
# Configure: HCLOUD_TOKEN, SSH_KEY_NAME, DOMAIN, etc.
```

### 2. Criar Infraestrutura

```bash
# Criar tudo automaticamente
./create-servers.sh
```

### 3. Configurar Aplicação

```bash
# Conectar no servidor APP
./ssh-app.sh

# Editar .env
cd /opt/eopix/app-server
nano .env
# Configure: DB_HOST, REDIS_HOST, R2_PUBLIC_URL, etc.

# Iniciar serviços
docker-compose up -d

# Ver logs
docker-compose logs -f traefik
```

### 4. Verificar

```bash
# HTTPS (SSL automático via Traefik)
curl https://api-prod.eopix.me/health

# Dashboard Traefik
# http://<IP_SERVIDOR>:8080
```

## 📁 Estrutura de Arquivos

```
eopix_hetzner/
├── create-servers.sh          # Script principal (cria tudo)
├── destroy-all.sh             # Destrói toda infraestrutura
├── configurar-hcloud.sh       # Configura autenticação hcloud
├── .env.example               # Template de configurações
│
├── app-server/
│   ├── docker-compose.traefik.yml  # Docker Compose com Traefik
│   └── .env.example
│
├── db-server/
│   ├── docker-compose.yml
│   ├── my.cnf
│   ├── backup.sh
│   └── .env.example
│
├── scripts/
│   ├── setup-app-server-traefik.sh  # Setup servidor APP
│   ├── setup-db-server.sh          # Setup servidor DB
│   └── validate-deployment.sh      # Validação
│
└── README.md                  # Este arquivo
```

## 🔒 SSL/TLS Automático

O **Traefik** obtém e renova certificados Let's Encrypt automaticamente:
- ✅ Não precisa de certbot
- ✅ Não precisa de scripts manuais
- ✅ Renovação automática
- ✅ HTTP → HTTPS redirect automático

## 📚 Documentação

- **`RECRIAR_COM_TRAEFIK.md`** - Guia completo passo a passo
- **`INICIO_RAPIDO_TRAEFIK.md`** - Comandos rápidos
- **`ACESSAR_SERVIDOR.md`** - Como acessar via SSH

## 🧹 Limpar Arquivos Desnecessários

```bash
# Remover arquivos antigos do Nginx
./limpar-arquivos.sh
```

## 🔧 Comandos Úteis

```bash
# Destruir tudo
./destroy-all.sh

# Recriar tudo
./create-servers.sh

# Acessar servidor APP
./ssh-app.sh

# Acessar servidor DB
./ssh-db.sh

# Configurar autenticação hcloud
./configurar-hcloud.sh
```

## 📝 Variáveis de Ambiente Importantes

No `.env`:
- `HCLOUD_TOKEN` - Token da API Hetzner
- `SSH_KEY_NAME` - Nome da chave SSH no Hetzner
- `LOCATION` - Localização (ash, hil, nbg1, etc.)
- `DOMAIN` - Domínio da API (api-prod.eopix.me)

No `app-server/.env`:
- `DB_HOST` - IP privado do servidor DB
- `REDIS_HOST` - IP privado do servidor DB
- `R2_PUBLIC_URL` - URL do R2
- `SESSION_SECRET` - Secret para sessões

## ✅ Checklist de Deploy

- [ ] `.env` configurado
- [ ] `hcloud` autenticado
- [ ] Infraestrutura criada (`./create-servers.sh`)
- [ ] `app-server/.env` configurado
- [ ] Serviços iniciados (`docker-compose up -d`)
- [ ] SSL funcionando (Traefik automático)
- [ ] HTTPS acessível
- [ ] Backends respondendo

## 🆘 Troubleshooting

Ver documentação em:
- `RECRIAR_COM_TRAEFIK.md`
- `INICIO_RAPIDO_TRAEFIK.md`
- `ACESSAR_SERVIDOR.md`

## 📄 Licença

Uso interno - EoPix
