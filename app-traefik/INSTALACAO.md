# 🚀 Guia de Instalação - Traefik no Servidor

Este guia explica como instalar e configurar o Traefik no servidor usando o `docker-compose.yml` fornecido.

## 📋 Pré-requisitos

- Servidor Ubuntu 22.04 (ou similar)
- Acesso root ou sudo
- Docker e Docker Compose instalados
- Domínio configurado apontando para o IP do servidor (ex: `traefik.eopix.me`)
- Portas 80 e 443 liberadas no firewall

## 🔧 Passo 1: Preparar o Ambiente

### 1.1 Atualizar o Sistema

```bash
apt-get update
apt-get upgrade -y
```

### 1.2 Instalar Docker (se não estiver instalado)

```bash
# Adicionar repositório Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 1.3 Configurar Firewall

```bash
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
```

## 📁 Passo 2: Preparar Diretórios e Arquivos

### 2.1 Criar Estrutura de Diretórios

```bash
# Criar diretório para o Traefik
mkdir -p /opt/eopix/traefik
cd /opt/eopix/traefik

# Criar diretório para certificados Let's Encrypt
mkdir -p letsencrypt
chmod 600 letsencrypt
```

### 2.2 Copiar docker-compose.yml

Copie o arquivo `docker-compose.yml` para o servidor:

```bash
# Via SCP (do seu computador local)
scp -i ~/.ssh/sua_chave docker-compose.yml root@<IP_SERVIDOR>:/opt/eopix/traefik/

# Ou via Git (se o repositório estiver disponível)
git clone <seu-repositorio> /tmp/eopix-hetzner
cp /tmp/eopix-hetzner/app-traefik/docker-compose.yml /opt/eopix/traefik/
```

## ⚙️ Passo 3: Configurar docker-compose.yml

### 3.1 Editar Configurações

Edite o arquivo `docker-compose.yml` para ajustar:

1. **Email do Let's Encrypt** (linha 27):
   ```yaml
   - "--certificatesresolvers.le.acme.email=noreplay@eopix.me"
   ```
   ⚠️ **IMPORTANTE**: Altere para um email válido para receber notificações de renovação.

2. **Domínio do Dashboard** (linha 45):
   ```yaml
   - "traefik.http.routers.traefik.rule=Host(`traefik.eopix.me`)"
   ```
   Altere `traefik.eopix.me` para seu domínio.

3. **Senha do BasicAuth** (linha 55):
   ```yaml
   - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$2y$$05$$..."
   ```
   ⚠️ **IMPORTANTE**: Gere uma nova senha hash para o BasicAuth.

### 3.2 Gerar Hash de Senha para BasicAuth

```bash
# Instalar htpasswd (se não tiver)
apt-get install -y apache2-utils

# Gerar hash da senha
htpasswd -nb admin sua_senha_segura
# Exemplo de saída: admin:$2y$05$I1vgHhXkylLQHTJVgBrm1.8RU6W.orRv1ULa.1lG3yk4lI85RCzNi

# No docker-compose.yml, use $$ no lugar de $ (escapar para Docker)
# admin:$$2y$$05$$I1vgHhXkylLQHTJVgBrm1.8RU6W.orRv1ULa.1lG3yk4lI85RCzNi
```

## 🚀 Passo 4: Iniciar o Traefik

### 4.1 Iniciar Container

```bash
cd /opt/eopix/traefik
docker compose up -d
```

### 4.2 Verificar Status

```bash
# Verificar se o container está rodando
docker compose ps

# Ver logs
docker compose logs -f traefik
```

### 4.3 Aguardar Inicialização

Aguarde alguns segundos para o Traefik inicializar completamente:

```bash
# Verificar se está respondendo
curl http://localhost:8080/ping
```

## ✅ Passo 5: Verificar Instalação

### 5.1 Verificar Portas

```bash
# Verificar se as portas estão abertas
netstat -tlnp | grep -E ':(80|443)'
```

### 5.2 Testar Dashboard (via IP)

```bash
# Acessar dashboard via IP (porta 8080 - apenas para teste)
curl -u admin:sua_senha http://<IP_SERVIDOR>:8080/api/rawdata
```

### 5.3 Verificar Certificado SSL

Aguarde alguns minutos para o Let's Encrypt gerar o certificado:

```bash
# Verificar certificado
openssl s_client -connect traefik.eopix.me:443 -servername traefik.eopix.me < /dev/null 2>/dev/null | grep -i "subject\|issuer"
```

## 🌐 Passo 6: Configurar DNS

Certifique-se de que o domínio está apontando para o IP do servidor:

```bash
# Verificar DNS
dig traefik.eopix.me +short
# Deve retornar o IP do servidor
```

## 🔒 Passo 7: Acessar Dashboard

Após o certificado SSL ser gerado (pode levar 1-2 minutos), acesse:

```
https://traefik.eopix.me
```

Use as credenciais configuradas no BasicAuth:
- **Usuário**: `admin`
- **Senha**: A senha que você configurou

## 📊 Comandos Úteis

### Ver Logs

```bash
cd /opt/eopix/traefik
docker compose logs -f traefik
```

### Reiniciar Traefik

```bash
cd /opt/eopix/traefik
docker compose restart traefik
```

### Parar Traefik

```bash
cd /opt/eopix/traefik
docker compose down
```

### Atualizar Traefik

```bash
cd /opt/eopix/traefik
docker compose pull traefik
docker compose up -d
```

### Ver Certificados

```bash
# Listar certificados armazenados
ls -la letsencrypt/
cat letsencrypt/acme.json  # (formato JSON)
```

## 🐛 Troubleshooting

### Traefik não inicia

```bash
# Verificar logs detalhados
docker compose logs traefik

# Verificar se o docker.sock está acessível
ls -la /var/run/docker.sock
```

### Certificado SSL não é gerado

1. Verifique se o DNS está apontando corretamente:
   ```bash
   dig traefik.eopix.me +short
   ```

2. Verifique se a porta 80 está acessível:
   ```bash
   curl -I http://traefik.eopix.me
   ```

3. Verifique os logs do Traefik:
   ```bash
   docker compose logs traefik | grep -i acme
   ```

### Dashboard não acessível

1. Verifique se o BasicAuth está configurado corretamente
2. Verifique se o domínio está correto no `docker-compose.yml`
3. Verifique os logs:
   ```bash
   docker compose logs traefik | grep -i router
   ```

## 📝 Próximos Passos

Após instalar o Traefik, você pode:

1. **Adicionar serviços** adicionando labels nos containers Docker
2. **Configurar middlewares** para rate limiting, autenticação, etc.
3. **Monitorar métricas** através do dashboard
4. **Configurar outros domínios** adicionando novos routers

## 🔗 Exemplo: Adicionar um Serviço Backend

Para adicionar um serviço backend que será roteado pelo Traefik, adicione estas labels no `docker-compose.yml` do seu serviço:

```yaml
services:
  backend:
    image: seu-backend:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(`api.eopix.me`)"
      - "traefik.http.routers.backend.entrypoints=websecure"
      - "traefik.http.routers.backend.tls.certresolver=le"
      - "traefik.http.services.backend.loadbalancer.server.port=4000"
```

## 📚 Referências

- [Documentação Traefik](https://doc.traefik.io/traefik/)
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [Let's Encrypt com Traefik](https://doc.traefik.io/traefik/https/acme/)

