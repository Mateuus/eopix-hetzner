# 🔐 Acessar Servidor via SSH

## ✅ Comando Correto

```bash
# Acessar servidor APP
ssh -i ~/.ssh/eopix_kubernetes root@5.161.223.50

# Ou usar o script helper
./ssh-app.sh
```

## ⚠️ Se Pedir Confirmação de Fingerprint

Se aparecer:
```
The authenticity of host '5.161.223.50' can't be established.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Digite: `yes`

## 🔧 Adicionar ao known_hosts Automaticamente

```bash
# Adicionar ao known_hosts sem perguntar
ssh-keyscan -H 5.161.223.50 >> ~/.ssh/known_hosts 2>/dev/null

# Depois acessar normalmente
ssh -i ~/.ssh/eopix_kubernetes root@5.161.223.50
```

## 📝 Scripts Helper

### Servidor APP

```bash
# Usar script helper
./ssh-app.sh

# Ou manualmente
ssh -i ~/.ssh/eopix_kubernetes root@<IP_APP_SERVER>
```

### Servidor DB

```bash
# Usar script helper
./ssh-db.sh

# Ou manualmente
ssh -i ~/.ssh/eopix_kubernetes root@<IP_DB_SERVER>
```

## 🔍 Descobrir IPs dos Servidores

```bash
# Ver IP do servidor APP
hcloud server describe eopix-app -o format='{{.PublicNet.IPv4.IP}}'

# Ver IP do servidor DB
hcloud server describe eopix-db -o format='{{.PublicNet.IPv4.IP}}'

# Listar todos
hcloud server list
```

## ✅ Verificar Chave SSH

```bash
# Verificar se a chave existe
ls -la ~/.ssh/eopix_kubernetes

# Verificar permissões (deve ser 600)
chmod 600 ~/.ssh/eopix_kubernetes

# Testar conexão
ssh -i ~/.ssh/eopix_kubernetes -o ConnectTimeout=5 root@5.161.223.50 "echo 'Conectado!'"
```

## 🐛 Troubleshooting

### Erro: "Permission denied (publickey)"

```bash
# Verificar se a chave está no Hetzner
hcloud ssh-key list | grep eopix-key

# Se não estiver, adicionar:
hcloud ssh-key create --name eopix-key --public-key-from-file ~/.ssh/eopix_kubernetes.pub
```

### Erro: "Host key verification failed"

```bash
# Remover do known_hosts
ssh-keygen -R 5.161.223.50

# Ou limpar todo known_hosts (cuidado!)
# rm ~/.ssh/known_hosts
```

### Usar ssh-agent

```bash
# Adicionar chave ao ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/eopix_kubernetes

# Agora pode acessar sem -i
ssh root@5.161.223.50
```
