# 🚀 Início Rápido - Recriar com Traefik

## ⚡ Comandos Rápidos

```bash
# 1. Destruir tudo
cd /home/mateuus/projects/eopix/eopix_hetzner
./destroy-all.sh
# Digite: DESTRUIR

# 2. Recriar com Traefik
./create-servers.sh

# 3. Configurar .env no servidor APP
ssh -i ~/.ssh/eopix_kubernetes root@<IP_APP>
cd /opt/eopix/app-server
nano .env
# Configure: DB_HOST, REDIS_HOST, R2_PUBLIC_URL, etc.

# 4. Iniciar serviços
docker-compose up -d

# 5. Ver logs do Traefik
docker-compose logs -f traefik
```

## ✅ O que mudou?

- ❌ **Nginx** → ✅ **Traefik**
- ❌ **Certbot manual** → ✅ **SSL automático**
- ❌ **nginx.conf** → ✅ **Labels Docker**
- ✅ **Dashboard Traefik** na porta 8080
- ✅ **Service Discovery** automático

## 🔒 SSL Automático

O Traefik vai:
1. Detectar o domínio `api-prod.eopix.me`
2. Obter certificado Let's Encrypt automaticamente
3. Renovar automaticamente
4. Redirecionar HTTP → HTTPS

**Não precisa de scripts ou configuração manual!**

## 📊 Dashboard Traefik

Acesse: `http://<IP_SERVIDOR>:8080`

Você verá:
- Rotas configuradas
- Serviços ativos
- Certificados SSL
- Métricas

## 🧪 Testar

```bash
# Aguardar certificado (pode levar 1-2 minutos)
sleep 120

# Testar HTTPS
curl https://api-prod.eopix.me/health

# Ver certificado
openssl s_client -connect api-prod.eopix.me:443 -servername api-prod.eopix.me < /dev/null 2>/dev/null | grep -i "subject\|issuer"
```

## 📝 Checklist

- [ ] Infraestrutura destruída
- [ ] Recriada com Traefik
- [ ] .env configurado
- [ ] Serviços iniciados
- [ ] Traefik obtendo certificados
- [ ] HTTPS funcionando
- [ ] Dashboard acessível
