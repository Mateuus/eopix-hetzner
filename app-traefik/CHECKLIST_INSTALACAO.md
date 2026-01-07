# ✅ Checklist de Instalação - Traefik

## Pré-requisitos
- [ ] Servidor Ubuntu 22.04 configurado
- [ ] Acesso root/sudo
- [ ] Docker instalado
- [ ] Docker Compose instalado
- [ ] Domínio configurado (ex: `traefik.eopix.me`)
- [ ] Portas 80 e 443 liberadas no firewall

## Instalação

### 1. Preparar Ambiente
- [ ] Atualizar sistema: `apt-get update && apt-get upgrade -y`
- [ ] Instalar Docker (se necessário)
- [ ] Configurar firewall: `ufw allow 80/tcp && ufw allow 443/tcp`

### 2. Preparar Diretórios
- [ ] Criar `/opt/eopix/traefik`
- [ ] Criar `/opt/eopix/traefik/letsencrypt` com permissão 600
- [ ] Copiar `docker-compose.yml` para o servidor

### 3. Configurar docker-compose.yml
- [ ] Alterar email do Let's Encrypt (linha 27)
- [ ] Alterar domínio do dashboard (linha 45)
- [ ] Gerar hash de senha para BasicAuth
- [ ] Atualizar linha 55 com o hash (usar `$$` no lugar de `$`)

### 4. Iniciar Traefik
- [ ] Executar: `cd /opt/eopix/traefik && docker compose up -d`
- [ ] Verificar status: `docker compose ps`
- [ ] Verificar logs: `docker compose logs -f traefik`

### 5. Verificar Instalação
- [ ] Verificar portas 80 e 443 abertas
- [ ] Testar dashboard via IP: `curl -u admin:senha http://<IP>:8080/api/rawdata`
- [ ] Aguardar certificado SSL (1-2 minutos)
- [ ] Verificar certificado: `openssl s_client -connect traefik.eopix.me:443`

### 6. Configurar DNS
- [ ] Verificar DNS: `dig traefik.eopix.me +short`
- [ ] Confirmar que aponta para o IP do servidor

### 7. Acessar Dashboard
- [ ] Acessar: `https://traefik.eopix.me`
- [ ] Fazer login com BasicAuth (admin + senha configurada)
- [ ] Verificar rotas e serviços no dashboard

## Comandos Rápidos

```bash
# Ver logs
cd /opt/eopix/traefik && docker compose logs -f traefik

# Reiniciar
cd /opt/eopix/traefik && docker compose restart traefik

# Parar
cd /opt/eopix/traefik && docker compose down

# Atualizar
cd /opt/eopix/traefik && docker compose pull && docker compose up -d
```

## Gerar Hash de Senha

```bash
# Instalar htpasswd
apt-get install -y apache2-utils

# Gerar hash
htpasswd -nb admin sua_senha_segura

# Usar no docker-compose.yml (substituir $ por $$)
```

## Troubleshooting

- [ ] Traefik não inicia → Verificar logs: `docker compose logs traefik`
- [ ] Certificado não gerado → Verificar DNS e porta 80
- [ ] Dashboard inacessível → Verificar BasicAuth e domínio

