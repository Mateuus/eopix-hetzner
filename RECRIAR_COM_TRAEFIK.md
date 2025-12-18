# 🔄 Recriar Infraestrutura com Traefik

## 📋 Passo a Passo Completo

### Passo 1: Destruir Infraestrutura Atual

```bash
# Do seu computador local
cd /home/mateuus/projects/eopix/eopix_hetzner

# Executar script de destruição
./destroy-all.sh
```

**⚠️ ATENÇÃO:** Isso vai deletar TUDO! Você precisa digitar `DESTRUIR` para confirmar.

### Passo 2: Verificar que Tudo Foi Deletado

```bash
# Verificar servidores
hcloud server list | grep eopix

# Verificar Load Balancer
hcloud load-balancer list | grep eopix

# Verificar Firewalls
hcloud firewall list | grep eopix

# Verificar Redes
hcloud network list | grep eopix
```

**Todos devem estar vazios!**

### Passo 3: Recriar com Traefik

```bash
# Executar script de criação (agora com Traefik)
./create-servers.sh
```

O script agora vai:
- ✅ Criar servidores APP e DB
- ✅ Criar Load Balancer
- ✅ Criar Firewalls
- ✅ Criar Rede Privada
- ✅ Configurar servidor APP com **Traefik** (não Nginx)
- ✅ Configurar SSL automático via Traefik

### Passo 4: Configurar .env no Servidor APP

```bash
# Conectar no servidor APP
ssh -i ~/.ssh/eopix_kubernetes root@<IP_APP_SERVER>

# Editar .env
cd /opt/eopix/app-server
nano .env

# Configurar:
# - DB_HOST (IP privado do servidor DB)
# - REDIS_HOST (IP privado do servidor DB)
# - R2_PUBLIC_URL
# - SESSION_SECRET
# - CORS_ORIGIN
# - APP_URL
# - API_BASE_URL
# - DOMAIN=api-prod.eopix.me (já deve estar)
```

### Passo 5: Iniciar Serviços

```bash
# No servidor APP
cd /opt/eopix/app-server

# Iniciar tudo
docker-compose up -d

# Ver logs do Traefik
docker-compose logs -f traefik
```

### Passo 6: Verificar SSL Automático

O Traefik vai obter certificados Let's Encrypt automaticamente!

```bash
# Aguardar alguns minutos para o certificado ser obtido
# Ver logs do Traefik
docker-compose logs traefik | grep -i acme

# Testar HTTPS
curl -k https://api-prod.eopix.me/health
```

### Passo 7: Acessar Dashboard Traefik

```bash
# Dashboard está na porta 8080
# Acesse: http://<IP_SERVIDOR>:8080
# Ou configure DNS para: traefik.api-prod.eopix.me
```

## ✅ Vantagens do Traefik

1. ✅ **SSL Automático** - Não precisa de certbot ou scripts
2. ✅ **Service Discovery** - Detecta containers automaticamente
3. ✅ **Dashboard** - Visualização de rotas e serviços
4. ✅ **HTTP → HTTPS Redirect** - Automático
5. ✅ **Renovação de Certificados** - Automática

## 🔧 Configurações Importantes

### Dashboard Traefik

O dashboard está **sem autenticação** por padrão. Em produção, configure:

```yaml
# No docker-compose.yml, adicione labels:
- "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$..."
```

### Porta 8080

A porta 8080 está aberta no firewall. Em produção, considere:
- Fechar no firewall público
- Ou adicionar autenticação
- Ou usar VPN para acessar

## 📝 Checklist

- [ ] Infraestrutura antiga destruída
- [ ] Script create-servers.sh executado
- [ ] Servidores criados
- [ ] .env configurado no servidor APP
- [ ] Serviços iniciados (`docker-compose up -d`)
- [ ] Traefik obtendo certificados (ver logs)
- [ ] HTTPS funcionando
- [ ] Dashboard acessível
- [ ] Backends respondendo

## 🧪 Testar

```bash
# HTTP (deve redirecionar para HTTPS)
curl -I http://api-prod.eopix.me/health

# HTTPS
curl https://api-prod.eopix.me/health

# Dashboard
curl http://<IP_SERVIDOR>:8080
```

## ❌ Se Algo Der Errado

### Voltar para Nginx

Se quiser voltar para Nginx:

```bash
# No servidor APP
cd /opt/eopix/app-server

# Parar Traefik
docker-compose down

# Usar docker-compose antigo (se tiver backup)
# Ou recriar com Nginx
```

### Ver Logs

```bash
# Logs do Traefik
docker-compose logs traefik

# Logs dos backends
docker-compose logs backend1 backend2 backend3

# Status dos containers
docker-compose ps
```

## 📚 Documentação

- Traefik Docs: https://doc.traefik.io/traefik/
- Let's Encrypt com Traefik: https://doc.traefik.io/traefik/https/acme/
