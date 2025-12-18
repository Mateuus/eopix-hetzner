# 🔧 Corrigir Rede sem Subnet

## ❌ Erro Atual

```
hcloud: invalid input in field 'networks' (invalid_input, ...)
- networks: networks must have at least one subnetwork
```

A rede `eopix-network` foi criada mas **não tem subnet**.

## ✅ Solução

### Opção 1: Adicionar Subnet à Rede Existente

```bash
# Para US East (hil)
hcloud network add-subnet eopix-network \
    --type cloud \
    --network-zone us-east \
    --ip-range 10.0.0.0/16

# Para EU Central (ash, nbg1, fsn1, hel1, fsn3)
# hcloud network add-subnet eopix-network \
#     --type cloud \
#     --network-zone eu-central \
#     --ip-range 10.0.0.0/16
```

**Nota:** Ajuste `--network-zone` conforme seu location:
- `ash` (Ashburn, VA), `hil` (Hillsboro) → `us-east`
- `nbg1`, `fsn1`, `hel1`, `fsn3` → `eu-central`

### Opção 2: Deletar e Recriar

```bash
# Deletar rede existente
hcloud network delete eopix-network

# Executar script novamente (agora ele cria subnet automaticamente)
./create-servers.sh
```

### Opção 3: Verificar e Corrigir

```bash
# Ver detalhes da rede
hcloud network describe eopix-network

# Ver subnets
hcloud network describe eopix-network -o json | jq '.subnets'

# Se não tiver subnet, adicionar:
hcloud network add-subnet eopix-network \
    --type cloud \
    --network-zone eu-central \
    --ip-range 10.0.0.0/16
```

## 🧪 Após Corrigir

```bash
# Verificar que a rede tem subnet
hcloud network describe eopix-network -o json | jq '.subnets'

# Executar script novamente
./create-servers.sh
```

## 📝 Network Zones

| Location | Network Zone |
|----------|--------------|
| ash, nbg1, fsn1, hel1 | eu-central |
| hil | us-east |
| fsn3 | eu-central |
