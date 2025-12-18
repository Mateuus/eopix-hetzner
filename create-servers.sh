#!/bin/bash
# ============================================
# Script de Criação Automática de Servidores
# Hetzner Cloud via CLI
# ============================================

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Carregar HCLOUD_TOKEN do .env se existir
if [ -f .env ]; then
    source .env 2>/dev/null || true
    if [ -n "$HCLOUD_TOKEN" ]; then
        export HCLOUD_TOKEN="$HCLOUD_TOKEN"
    fi
fi

# Carregar .env de forma segura
load_env() {
    # Desabilitar exit on error temporariamente dentro da função
    set +e
    
    if [ ! -f .env ]; then
        echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
        echo "Copie .env.example para .env e configure:"
        echo "  cp .env.example .env"
        echo "  nano .env"
        set -e
        exit 1
    fi

    echo -e "${BLUE}📄 Carregando configurações de .env${NC}"
    
    local line_num=0
    local errors=0
    local loaded=0
    
    # Carregar apenas linhas válidas (VAR=valor)
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        
        # Ignorar linhas vazias e comentários
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        # Verificar se é uma linha válida VAR=valor
        if [[ "$line" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*= ]]; then
            # Remover espaços no início
            line=$(echo "$line" | sed 's/^[[:space:]]*//')
            
            # Separar nome da variável e valor
            var_name="${line%%=*}"
            var_value="${line#*=}"
            
            # Remover comentários inline (tudo após # que não está entre aspas)
            if [[ "$var_value" =~ '#' ]] && [[ ! "$var_value" =~ ^\" ]] && [[ ! "$var_value" =~ ^\' ]]; then
                var_value="${var_value%%#*}"
                # Remover espaços no final
                var_value="${var_value%"${var_value##*[![:space:]]}"}"
            fi
            
            # Exportar variável de forma segura
            # Tentar export direto primeiro (mais simples)
            if export "${var_name}"="${var_value}" 2>/dev/null; then
                ((loaded++))
            else
                # Se falhar, tentar com printf %q para escapar
                if printf -v escaped_value '%q' "$var_value" 2>/dev/null; then
                    if eval "export ${var_name}=${escaped_value}" 2>/dev/null; then
                        ((loaded++))
                    else
                        echo -e "${YELLOW}⚠️  Aviso: Linha ${line_num} não pôde ser carregada: ${var_name}=...${NC}" >&2
                        ((errors++))
                    fi
                else
                    echo -e "${YELLOW}⚠️  Aviso: Linha ${line_num} não pôde ser carregada: ${var_name}=...${NC}" >&2
                    ((errors++))
                fi
            fi
        else
            # Linha que não é comentário nem variável válida
            if [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                # Não mostrar aviso para linhas que claramente não são variáveis
                :
            fi
        fi
    done < .env
    
    # Reabilitar exit on error
    set -e
    
    if [ $errors -gt 0 ]; then
        echo -e "${YELLOW}⚠️  ${errors} linha(s) com problema, ${loaded} variável(is) carregada(s)${NC}" >&2
    else
        echo -e "${GREEN}✅ ${loaded} variável(is) carregada(s)${NC}"
    fi
}

load_env

# Verificar Hetzner CLI
if ! command -v hcloud &> /dev/null; then
    echo -e "${YELLOW}⚠️  hcloud CLI não encontrado. Instalando...${NC}"
    curl -sSLO https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
    sudo tar -C /usr/local/bin --no-same-owner -xzf hcloud-linux-amd64.tar.gz hcloud
    rm hcloud-linux-amd64.tar.gz
    echo -e "${GREEN}✅ hcloud CLI instalado${NC}"
fi

# Verificar token
if [ -z "$HCLOUD_TOKEN" ] || [ "$HCLOUD_TOKEN" == "your-hetzner-api-token-here" ]; then
    echo -e "${RED}❌ HCLOUD_TOKEN não configurado no .env${NC}"
    exit 1
fi

# Configurar contexto
export HCLOUD_TOKEN
hcloud context use eopix 2>/dev/null || hcloud context create eopix

# Verificar SSH Key
if [ -z "$SSH_KEY_NAME" ]; then
    echo -e "${RED}❌ SSH_KEY_NAME não configurado no .env${NC}"
    exit 1
fi

# Obter caminho da chave SSH privada
SSH_KEY_PATHS=(
    "$HOME/.ssh/eopix_kubernetes"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_ecdsa"
)

SSH_PRIVATE_KEY=""
for key_path in "${SSH_KEY_PATHS[@]}"; do
    if [ -f "$key_path" ]; then
        # Verificar se a chave pública correspondente existe
        pub_key_path="${key_path}.pub"
        if [ -f "$pub_key_path" ]; then
            SSH_PRIVATE_KEY="$key_path"
            echo -e "${GREEN}✅ Chave SSH encontrada: ${key_path}${NC}"
            break
        fi
    fi
done

if [ -z "$SSH_PRIVATE_KEY" ]; then
    echo -e "${YELLOW}⚠️  Chave SSH privada não encontrada. Tentando usar padrão do SSH...${NC}"
    SSH_PRIVATE_KEY=""
fi

SSH_KEY_EXISTS=$(hcloud ssh-key list -o columns=name | grep -c "^${SSH_KEY_NAME}$" || true)
if [ "$SSH_KEY_EXISTS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  SSH Key '${SSH_KEY_NAME}' não encontrada${NC}"
    echo ""
    
    # Tentar encontrar chaves SSH locais
    SSH_KEY_PATHS=(
        "$HOME/.ssh/id_rsa.pub"
        "$HOME/.ssh/id_ed25519.pub"
        "$HOME/.ssh/id_ecdsa.pub"
        "$HOME/.ssh/eopix_kubernetes.pub"
    )
    
    SSH_PUB_KEY=""
    for key_path in "${SSH_KEY_PATHS[@]}"; do
        if [ -f "$key_path" ]; then
            SSH_PUB_KEY="$key_path"
            echo -e "${GREEN}✅ Encontrada chave SSH local: ${key_path}${NC}"
            break
        fi
    done
    
    if [ -n "$SSH_PUB_KEY" ]; then
        echo ""
        read -p "Deseja criar a SSH Key '${SSH_KEY_NAME}' no Hetzner usando ${SSH_PUB_KEY}? (s/n): " CREATE_KEY
        if [[ "$CREATE_KEY" =~ ^[Ss]$ ]]; then
            echo -e "${BLUE}📤 Criando SSH Key no Hetzner...${NC}"
            if hcloud ssh-key create --name "${SSH_KEY_NAME}" --public-key-from-file "${SSH_PUB_KEY}"; then
                echo -e "${GREEN}✅ SSH Key '${SSH_KEY_NAME}' criada com sucesso!${NC}"
            else
                echo -e "${RED}❌ Erro ao criar SSH Key${NC}"
                exit 1
            fi
        else
            echo ""
            echo "Para criar manualmente, execute:"
            echo "  hcloud ssh-key create --name ${SSH_KEY_NAME} --public-key-from-file ~/.ssh/id_rsa.pub"
            echo ""
            echo "Ou adicione via Hetzner Cloud Console:"
            echo "  https://console.hetzner.cloud/projects"
            exit 1
        fi
    else
        echo ""
        echo "Nenhuma chave SSH pública encontrada localmente."
        echo ""
        echo "Opções:"
        echo "  1. Criar uma nova chave SSH:"
        echo "     ssh-keygen -t ed25519 -C 'eopix-hetzner' -f ~/.ssh/eopix_kubernetes"
        echo ""
        echo "  2. Adicionar chave existente via CLI:"
        echo "     hcloud ssh-key create --name ${SSH_KEY_NAME} --public-key-from-file ~/.ssh/id_rsa.pub"
        echo ""
        echo "  3. Adicionar via Hetzner Cloud Console:"
        echo "     https://console.hetzner.cloud/projects"
        exit 1
    fi
else
    echo -e "${GREEN}✅ SSH Key '${SSH_KEY_NAME}' encontrada${NC}"
fi

# ============================================
# Criar Rede Privada
# ============================================
echo ""
echo -e "${BLUE}🌐 Criando rede privada...${NC}"

# Verificar se rede existe (tentar descrever primeiro)
if hcloud network describe "${PRIVATE_NETWORK_NAME}" >/dev/null 2>&1; then
    NETWORK_EXISTS=1
else
    NETWORK_EXISTS=0
fi

if [ "$NETWORK_EXISTS" -eq 0 ]; then
    hcloud network create \
        --name "${PRIVATE_NETWORK_NAME}" \
        --ip-range "${PRIVATE_NETWORK_SUBNET}"
    echo -e "${GREEN}✅ Rede privada '${PRIVATE_NETWORK_NAME}' criada${NC}"
    
    # Criar subnet e anexar à network zone (obrigatório no Hetzner)
    echo -e "${BLUE}📡 Criando subnet...${NC}"
    
    # Determinar network zone baseado no location
    NETWORK_ZONE="eu-central"  # Padrão
    case "${LOCATION}" in
        ash|hil)
            # Ashburn (ash) e Hillsboro (hil) são US East
            NETWORK_ZONE="us-east"
            ;;
        nbg1|fsn1|hel1|fsn3)
            # Nuremberg, Falkenstein, Helsinki são EU Central
            NETWORK_ZONE="eu-central"
            ;;
        *)
            # Tentar detectar automaticamente
            if echo "${LOCATION}" | grep -qi "ash\|hil\|us"; then
                NETWORK_ZONE="us-east"
            else
                NETWORK_ZONE="eu-central"
            fi
            ;;
    esac
    
    echo -e "${BLUE}  Network Zone: ${NETWORK_ZONE}${NC}"
    hcloud network add-subnet "${PRIVATE_NETWORK_NAME}" \
        --type cloud \
        --network-zone "${NETWORK_ZONE}" \
        --ip-range "${PRIVATE_NETWORK_SUBNET}"
    echo -e "${GREEN}✅ Subnet criada e anexada à network zone '${NETWORK_ZONE}'${NC}"
    
    # Aguardar rede estar disponível
    echo "⏳ Aguardando rede estar disponível..."
    sleep 5
else
    echo -e "${YELLOW}⚠️  Rede privada '${PRIVATE_NETWORK_NAME}' já existe${NC}"
    # Verificar se tem subnet
    SUBNET_COUNT=$(hcloud network describe "${PRIVATE_NETWORK_NAME}" -o json 2>/dev/null | jq -r '.subnets | length' 2>/dev/null || echo "0")
    if [ "$SUBNET_COUNT" = "0" ] || [ -z "$SUBNET_COUNT" ]; then
        echo -e "${YELLOW}⚠️  Rede existe mas não tem subnet. Criando subnet...${NC}"
        
        # Determinar network zone baseado no location
        NETWORK_ZONE="eu-central"  # Padrão
        case "${LOCATION}" in
            ash|hil)
                # Ashburn (ash) e Hillsboro (hil) são US East
                NETWORK_ZONE="us-east"
                ;;
            nbg1|fsn1|hel1|fsn3)
                # Nuremberg, Falkenstein, Helsinki são EU Central
                NETWORK_ZONE="eu-central"
                ;;
            *)
                # Tentar detectar automaticamente
                if echo "${LOCATION}" | grep -qi "ash\|hil\|us"; then
                    NETWORK_ZONE="us-east"
                else
                    NETWORK_ZONE="eu-central"
                fi
                ;;
        esac
        
        echo -e "${BLUE}  Network Zone: ${NETWORK_ZONE}${NC}"
        hcloud network add-subnet "${PRIVATE_NETWORK_NAME}" \
            --type cloud \
            --network-zone "${NETWORK_ZONE}" \
            --ip-range "${PRIVATE_NETWORK_SUBNET}" 2>/dev/null && {
            echo -e "${GREEN}✅ Subnet criada${NC}"
        } || {
            echo -e "${YELLOW}⚠️  Erro ao criar subnet (pode já existir ou conflito de IP)${NC}"
        }
    else
        echo -e "${GREEN}✅ Rede já tem subnet(s) configurada(s)${NC}"
    fi
    # Verificar se a rede está realmente acessível
    if ! hcloud network describe "${PRIVATE_NETWORK_NAME}" >/dev/null 2>&1; then
        echo -e "${RED}❌ Erro: Rede existe mas não está acessível. Pode ser problema de autenticação.${NC}"
        echo "Verifique: hcloud network list"
        exit 1
    fi
fi

# ============================================
# Criar Servidor APP (CPX31)
# ============================================
echo ""
echo -e "${BLUE}🖥️  Criando servidor APP (${APP_SERVER_TYPE})...${NC}"

# Verificar se servidor existe (tentar descrever primeiro)
if hcloud server describe "${APP_SERVER_NAME}" >/dev/null 2>&1; then
    APP_SERVER_EXISTS=1
else
    APP_SERVER_EXISTS=0
fi

if [ "$APP_SERVER_EXISTS" -eq 0 ]; then
    hcloud server create \
        --name "${APP_SERVER_NAME}" \
        --type "${APP_SERVER_TYPE}" \
        --image ubuntu-22.04 \
        --location "${LOCATION}" \
        --ssh-key "${SSH_KEY_NAME}" \
        --network "${PRIVATE_NETWORK_NAME}"
    
    echo -e "${GREEN}✅ Servidor APP criado${NC}"
    
    # Aguardar servidor estar pronto
    echo "⏳ Aguardando servidor estar pronto..."
    sleep 10
    
    # Obter IP
    APP_SERVER_IP=$(hcloud server describe "${APP_SERVER_NAME}" -o format='{{.PublicNet.IPv4.IP}}')
    echo -e "${GREEN}✅ IP do servidor APP: ${APP_SERVER_IP}${NC}"
else
    echo -e "${YELLOW}⚠️  Servidor APP '${APP_SERVER_NAME}' já existe${NC}"
    APP_SERVER_IP=$(hcloud server describe "${APP_SERVER_NAME}" -o format='{{.PublicNet.IPv4.IP}}')
    echo -e "${GREEN}✅ IP do servidor APP: ${APP_SERVER_IP}${NC}"
fi

# ============================================
# Criar Servidor DB (CPX21)
# ============================================
echo ""
echo -e "${BLUE}🗄️  Criando servidor DB (${DB_SERVER_TYPE})...${NC}"

# Verificar se servidor existe (tentar descrever primeiro)
if hcloud server describe "${DB_SERVER_NAME}" >/dev/null 2>&1; then
    DB_SERVER_EXISTS=1
else
    DB_SERVER_EXISTS=0
fi

if [ "$DB_SERVER_EXISTS" -eq 0 ]; then
    hcloud server create \
        --name "${DB_SERVER_NAME}" \
        --type "${DB_SERVER_TYPE}" \
        --image ubuntu-22.04 \
        --location "${LOCATION}" \
        --ssh-key "${SSH_KEY_NAME}" \
        --network "${PRIVATE_NETWORK_NAME}"
    
    echo -e "${GREEN}✅ Servidor DB criado${NC}"
    
    # Aguardar servidor estar pronto
    echo "⏳ Aguardando servidor estar pronto..."
    sleep 10
    
    # Obter IPs
    DB_SERVER_IP=$(hcloud server describe "${DB_SERVER_NAME}" -o format='{{.PublicNet.IPv4.IP}}')
    # Obter IP privado - extrair da saída do describe
    DB_SERVER_PRIVATE_IP=$(hcloud server describe "${DB_SERVER_NAME}" | grep -A 5 "Private Networks:" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    if [ -z "$DB_SERVER_PRIVATE_IP" ]; then
        # Fallback: tentar via JSON
        DB_SERVER_PRIVATE_IP=$(hcloud server describe "${DB_SERVER_NAME}" -o json 2>/dev/null | grep -oE '"ip":\s*"([0-9]{1,3}\.){3}[0-9]{1,3}"' | head -n 1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "")
    fi
    echo -e "${GREEN}✅ IP público do servidor DB: ${DB_SERVER_IP}${NC}"
    if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
        echo -e "${GREEN}✅ IP privado do servidor DB: ${DB_SERVER_PRIVATE_IP}${NC}"
    else
        echo -e "${YELLOW}⚠️  Não foi possível obter IP privado automaticamente${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Servidor DB '${DB_SERVER_NAME}' já existe${NC}"
    DB_SERVER_IP=$(hcloud server describe "${DB_SERVER_NAME}" -o format='{{.PublicNet.IPv4.IP}}')
    # Obter IP privado - extrair da saída do describe
    DB_SERVER_PRIVATE_IP=$(hcloud server describe "${DB_SERVER_NAME}" | grep -A 5 "Private Networks:" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    if [ -z "$DB_SERVER_PRIVATE_IP" ]; then
        # Fallback: tentar via JSON
        DB_SERVER_PRIVATE_IP=$(hcloud server describe "${DB_SERVER_NAME}" -o json 2>/dev/null | grep -oE '"ip":\s*"([0-9]{1,3}\.){3}[0-9]{1,3}"' | head -n 1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "")
    fi
    echo -e "${GREEN}✅ IP público do servidor DB: ${DB_SERVER_IP}${NC}"
    if [ -n "$DB_SERVER_PRIVATE_IP" ]; then
        echo -e "${GREEN}✅ IP privado do servidor DB: ${DB_SERVER_PRIVATE_IP}${NC}"
    else
        echo -e "${YELLOW}⚠️  Não foi possível obter IP privado automaticamente${NC}"
    fi
fi

# ============================================
# Configurar Firewall
# ============================================
echo ""
echo -e "${BLUE}🔥 Configurando firewall...${NC}"

# Firewall para APP Server (abrir 22, 80, 443)
FW_APP_NAME="eopix-app-firewall"
# Verificar se firewall existe (tentar descrever primeiro)
if hcloud firewall describe "${FW_APP_NAME}" >/dev/null 2>&1; then
    FW_APP_EXISTS=1
else
    FW_APP_EXISTS=0
fi

if [ "$FW_APP_EXISTS" -eq 0 ]; then
    hcloud firewall create --name "${FW_APP_NAME}"
    
    # SSH
    hcloud firewall add-rule "${FW_APP_NAME}" \
        --direction in \
        --protocol tcp \
        --port 22 \
        --source-ips 0.0.0.0/0
    
    # HTTP
    hcloud firewall add-rule "${FW_APP_NAME}" \
        --direction in \
        --protocol tcp \
        --port 80 \
        --source-ips 0.0.0.0/0
    
    # HTTPS
    hcloud firewall add-rule "${FW_APP_NAME}" \
        --direction in \
        --protocol tcp \
        --port 443 \
        --source-ips 0.0.0.0/0
    
    hcloud firewall apply-to-resource "${FW_APP_NAME}" --type server --server "${APP_SERVER_NAME}"
    echo -e "${GREEN}✅ Firewall APP configurado${NC}"
else
    echo -e "${YELLOW}⚠️  Firewall APP já existe${NC}"
    # Garantir que está aplicado ao servidor
    hcloud firewall apply-to-resource "${FW_APP_NAME}" --type server --server "${APP_SERVER_NAME}" 2>/dev/null || true
fi

# Firewall para DB Server (apenas SSH e portas internas)
FW_DB_NAME="eopix-db-firewall"
# Verificar se firewall existe (tentar descrever primeiro)
if hcloud firewall describe "${FW_DB_NAME}" >/dev/null 2>&1; then
    FW_DB_EXISTS=1
else
    FW_DB_EXISTS=0
fi

if [ "$FW_DB_EXISTS" -eq 0 ]; then
    hcloud firewall create --name "${FW_DB_NAME}"
    
    # SSH
    hcloud firewall add-rule "${FW_DB_NAME}" \
        --direction in \
        --protocol tcp \
        --port 22 \
        --source-ips 0.0.0.0/0
    
    # MySQL (apenas rede privada)
    hcloud firewall add-rule "${FW_DB_NAME}" \
        --direction in \
        --protocol tcp \
        --port 3306 \
        --source-ips "${PRIVATE_NETWORK_SUBNET}"
    
    # Valkey/Redis (apenas rede privada)
    hcloud firewall add-rule "${FW_DB_NAME}" \
        --direction in \
        --protocol tcp \
        --port 6379 \
        --source-ips "${PRIVATE_NETWORK_SUBNET}"
    
    hcloud firewall apply-to-resource "${FW_DB_NAME}" --type server --server "${DB_SERVER_NAME}"
    echo -e "${GREEN}✅ Firewall DB configurado${NC}"
else
    echo -e "${YELLOW}⚠️  Firewall DB já existe${NC}"
    # Garantir que está aplicado ao servidor
    hcloud firewall apply-to-resource "${FW_DB_NAME}" --type server --server "${DB_SERVER_NAME}" 2>/dev/null || true
fi

# ============================================
# Criar Load Balancer
# ============================================
echo ""
echo -e "${BLUE}⚖️  Criando Load Balancer...${NC}"

LB_NAME="eopix-lb"
# Verificar se Load Balancer existe (tentar descrever primeiro)
if hcloud load-balancer describe "${LB_NAME}" >/dev/null 2>&1; then
    LB_EXISTS=1
else
    LB_EXISTS=0
fi

if [ "$LB_EXISTS" -eq 0 ]; then
    # Criar Load Balancer
    hcloud load-balancer create \
        --name "${LB_NAME}" \
        --type lb11 \
        --location "${LOCATION}" \
        --algorithm-type round_robin
    
    echo -e "${GREEN}✅ Load Balancer criado${NC}"
    
    # Aguardar Load Balancer estar pronto
    echo "⏳ Aguardando Load Balancer estar pronto..."
    sleep 5
    
    # Anexar Load Balancer à rede privada
    echo -e "${BLUE}🔗 Anexando Load Balancer à rede privada...${NC}"
    hcloud load-balancer attach-to-network "${LB_NAME}" \
        --network "${PRIVATE_NETWORK_NAME}"
    
    echo -e "${GREEN}✅ Load Balancer anexado à rede privada${NC}"
    
    # Adicionar targets (servidores APP e DB) usando IP privado
    echo -e "${BLUE}📤 Adicionando targets ao Load Balancer...${NC}"
    
    # Adicionar servidor APP
    hcloud load-balancer add-target "${LB_NAME}" --server "${APP_SERVER_NAME}" --use-private-ip
    echo -e "${GREEN}✅ Target (servidor APP) adicionado ao Load Balancer${NC}"
    
    # Adicionar servidor DB
    hcloud load-balancer add-target "${LB_NAME}" --server "${DB_SERVER_NAME}" --use-private-ip
    echo -e "${GREEN}✅ Target (servidor DB) adicionado ao Load Balancer${NC}"
    
    # Criar serviço HTTP na porta 80
    echo -e "${BLUE}⚙️  Configurando serviço HTTP...${NC}"
    hcloud load-balancer add-service \
        --protocol http \
        --listen-port 80 \
        --destination-port 80 \
        --health-check-protocol http \
        --health-check-port 80 \
        --health-check-http-status-codes "2??,3??" \
        --health-check-http-path "/health" \
        --health-check-interval 10s \
        --health-check-timeout 5s \
        --health-check-retries 3 \
        "${LB_NAME}"
    
    echo -e "${GREEN}✅ Serviço HTTP configurado com Health Check (/health)${NC}"
    
    # Obter IP do Load Balancer
    LB_IP=$(hcloud load-balancer describe "${LB_NAME}" -o format='{{.PublicNet.IPv4.IP}}')
    echo -e "${GREEN}✅ IP do Load Balancer: ${LB_IP}${NC}"
    echo ""
    echo -e "${YELLOW}📝 IMPORTANTE: Configure seu DNS para apontar ${DOMAIN} para ${LB_IP}${NC}"
else
    echo -e "${YELLOW}⚠️  Load Balancer '${LB_NAME}' já existe${NC}"
    LB_IP=$(hcloud load-balancer describe "${LB_NAME}" -o format='{{.PublicNet.IPv4.IP}}' 2>/dev/null || echo "")
    if [ -n "$LB_IP" ]; then
        echo -e "${GREEN}✅ IP do Load Balancer: ${LB_IP}${NC}"
    else
        echo -e "${YELLOW}⚠️  Não foi possível obter IP do Load Balancer${NC}"
    fi
    
    # Verificar se está anexado à rede privada
    NETWORK_ATTACHED=$(hcloud load-balancer describe "${LB_NAME}" -o json 2>/dev/null | grep -o "\"name\": \"${PRIVATE_NETWORK_NAME}\"" | wc -l | tr -d ' ')
    if [ -z "$NETWORK_ATTACHED" ] || [ "$NETWORK_ATTACHED" = "0" ]; then
        echo -e "${BLUE}🔗 Anexando Load Balancer à rede privada...${NC}"
        if hcloud load-balancer attach-to-network "${LB_NAME}" --network "${PRIVATE_NETWORK_NAME}" 2>/dev/null; then
            echo -e "${GREEN}✅ Load Balancer anexado à rede privada${NC}"
        else
            echo -e "${YELLOW}⚠️  Erro ao anexar à rede (pode já estar anexado)${NC}"
        fi
    else
        echo -e "${GREEN}✅ Load Balancer já está anexado à rede privada${NC}"
    fi
    
    # Verificar targets existentes
    echo -e "${BLUE}📤 Verificando targets do Load Balancer...${NC}"
    TARGETS_JSON=$(hcloud load-balancer describe "${LB_NAME}" -o json 2>/dev/null | grep -A 20 '"targets"' || echo "")
    
    # Verificar se servidor APP está nos targets
    APP_TARGET_EXISTS=$(echo "$TARGETS_JSON" | grep -o "\"name\": \"${APP_SERVER_NAME}\"" | wc -l | tr -d ' ')
    if [ -z "$APP_TARGET_EXISTS" ] || [ "$APP_TARGET_EXISTS" = "0" ]; then
        echo -e "${BLUE}📤 Adicionando target (servidor APP) ao Load Balancer...${NC}"
        if hcloud load-balancer add-target "${LB_NAME}" --server "${APP_SERVER_NAME}" --use-private-ip 2>/dev/null; then
            echo -e "${GREEN}✅ Target (servidor APP) adicionado ao Load Balancer${NC}"
        else
            echo -e "${RED}❌ Erro ao adicionar target (servidor APP)${NC}"
        fi
    else
        echo -e "${GREEN}✅ Target (servidor APP) já está configurado no Load Balancer${NC}"
    fi
    
    # Verificar se servidor DB está nos targets
    DB_TARGET_EXISTS=$(echo "$TARGETS_JSON" | grep -o "\"name\": \"${DB_SERVER_NAME}\"" | wc -l | tr -d ' ')
    if [ -z "$DB_TARGET_EXISTS" ] || [ "$DB_TARGET_EXISTS" = "0" ]; then
        echo -e "${BLUE}📤 Adicionando target (servidor DB) ao Load Balancer...${NC}"
        if hcloud load-balancer add-target "${LB_NAME}" --server "${DB_SERVER_NAME}" --use-private-ip 2>/dev/null; then
            echo -e "${GREEN}✅ Target (servidor DB) adicionado ao Load Balancer${NC}"
        else
            echo -e "${RED}❌ Erro ao adicionar target (servidor DB)${NC}"
        fi
    else
        echo -e "${GREEN}✅ Target (servidor DB) já está configurado no Load Balancer${NC}"
    fi
fi

# ============================================
# Executar Setup Remoto
# ============================================
echo ""
echo -e "${BLUE}🚀 Executando setup remoto nos servidores...${NC}"

# Preparar arquivos para upload
TMP_DIR=$(mktemp -d)
cp -r app-server "$TMP_DIR/"
cp -r db-server "$TMP_DIR/"
cp scripts/setup-app-server-traefik.sh "$TMP_DIR/"
cp scripts/setup-db-server.sh "$TMP_DIR/"

# Criar diretório scripts no db-server e copiar script de configuração do MySQL
mkdir -p "$TMP_DIR/db-server/scripts"
if [ -f scripts/configurar-mysql.sh ]; then
    cp scripts/configurar-mysql.sh "$TMP_DIR/db-server/scripts/"
    chmod +x "$TMP_DIR/db-server/scripts/configurar-mysql.sh"
fi

# Criar arquivo com IPs e configurações Git para os scripts
cat > "$TMP_DIR/server-ips.env" <<EOF
APP_SERVER_IP=${APP_SERVER_IP}
DB_SERVER_IP=${DB_SERVER_IP}
DB_SERVER_PRIVATE_IP=${DB_SERVER_PRIVATE_IP}
GIT_REPO=${GIT_REPO:-}
GIT_BRANCH=${GIT_BRANCH:-main}
EOF

# Função para executar comandos SSH/SCP com a chave correta
ssh_cmd() {
    if [ -n "$SSH_PRIVATE_KEY" ]; then
        ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
    else
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
    fi
}

scp_cmd() {
    if [ -n "$SSH_PRIVATE_KEY" ]; then
        scp -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
    else
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
    fi
}

# Upload e execução no APP Server
echo ""
echo -e "${BLUE}📤 Configurando servidor APP com Traefik...${NC}"

# Sempre fazer upload dos arquivos via SCP (como fallback se Git falhar)
# Se GIT_REPO estiver definido, o script setup-app-server-traefik.sh vai preferir Git
scp_cmd -r "$TMP_DIR/app-server" "$TMP_DIR/setup-app-server-traefik.sh" "$TMP_DIR/server-ips.env" root@"${APP_SERVER_IP}":/tmp/
ssh_cmd root@"${APP_SERVER_IP}" "chmod +x /tmp/setup-app-server-traefik.sh && /tmp/setup-app-server-traefik.sh"

# Upload e execução no DB Server
echo ""
echo -e "${BLUE}📤 Configurando servidor DB...${NC}"

# Sempre fazer upload dos arquivos via SCP (como fallback se Git falhar)
# Se GIT_REPO estiver definido, o script setup-db-server.sh vai preferir Git
scp_cmd -r "$TMP_DIR/db-server" "$TMP_DIR/setup-db-server.sh" "$TMP_DIR/server-ips.env" root@"${DB_SERVER_IP}":/tmp/
ssh_cmd root@"${DB_SERVER_IP}" "chmod +x /tmp/setup-db-server.sh && /tmp/setup-db-server.sh"

# Limpar
rm -rf "$TMP_DIR"

# ============================================
# Resumo Final
# ============================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Deploy concluído com sucesso!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Informações dos Servidores:${NC}"
echo ""
echo -e "  ${YELLOW}APP Server:${NC}"
echo "    Nome: ${APP_SERVER_NAME}"
echo "    IP Público: ${APP_SERVER_IP}"
echo "    SSH: ssh root@${APP_SERVER_IP}"
echo ""
echo -e "  ${YELLOW}DB Server:${NC}"
echo "    Nome: ${DB_SERVER_NAME}"
echo "    IP Público: ${DB_SERVER_IP}"
echo "    IP Privado: ${DB_SERVER_PRIVATE_IP}"
echo "    SSH: ssh root@${DB_SERVER_IP}"
echo ""
echo -e "${BLUE}📝 Próximos Passos:${NC}"
echo ""
echo -e "${YELLOW}📖 Para um guia completo, veja: CONFIGURAR_APP.md${NC}"
echo ""
if [ -n "$LB_IP" ]; then
    echo "  1. Configure DNS:"
    echo "     ${DOMAIN} → ${LB_IP}"
    echo ""
    echo "  2. (Opcional) Configure HTTPS no Load Balancer:"
    echo "     Acesse Hetzner Cloud Console → Load Balancers → ${LB_NAME}"
    echo "     Adicione certificado SSL/TLS"
    echo ""
else
    echo "  1. Configure o Load Balancer no Hetzner Cloud Console:"
    echo "     - Target: ${APP_SERVER_IP} (porta 80/443)"
    echo "     - Health Check: HTTP GET /health"
    echo ""
    echo "  2. Configure DNS:"
    echo "     ${DOMAIN} → IP do Load Balancer"
    echo ""
fi
echo ""
echo -e "${BLUE}📋 Configurar Servidor APP:${NC}"
echo ""
echo "  # Conectar no servidor APP"
echo "  ssh root@${APP_SERVER_IP}"
echo ""
echo "  # Editar variáveis de ambiente"
echo "  cd /opt/eopix/app-server"
echo "  nano .env"
echo ""
echo "  # IMPORTANTE: Configure pelo menos:"
echo "  # - DB_HOST=10.0.0.3  (IP privado do servidor DB)"
echo "  # - DB_PASS=sua-senha-mysql"
echo "  # - REDIS_HOST=10.0.0.3"
echo "  # - R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY"
echo "  # - CORS_ORIGIN, APP_URL, API_BASE_URL"
echo ""
echo "  # Iniciar serviços"
echo "  docker-compose up -d"
echo ""
echo "  # Verificar logs"
echo "  docker-compose logs -f"
echo ""
echo "  # Testar health check"
echo "  curl http://localhost/health"
echo ""
echo -e "${BLUE}📋 Configurar Servidor DB:${NC}"
echo ""
echo "  # Conectar no servidor DB"
echo "  ssh root@${DB_SERVER_IP}"
echo ""
echo "  # Editar senhas (se necessário)"
echo "  cd /opt/eopix/db-server"
echo "  nano .env"
echo ""
echo "  # Iniciar serviços"
echo "  docker-compose up -d"
echo ""
echo "  # Aguardar MySQL inicializar (30-60 segundos)"
echo "  sleep 60"
echo ""
echo "  # Criar banco e usuário"
echo "  docker-compose exec mysql mysql -uroot -p"
echo "  # No MySQL, execute:"
echo "  # CREATE DATABASE eopix;"
echo "  # CREATE USER 'eopix'@'%' IDENTIFIED BY 'sua-senha-aqui';"
echo "  # GRANT ALL PRIVILEGES ON eopix.* TO 'eopix'@'%';"
echo "  # FLUSH PRIVILEGES;"
echo "  # EXIT;"
echo ""
echo -e "${BLUE}✅ Validar Deploy:${NC}"
echo ""
echo "  ./scripts/validate-deployment.sh"
echo ""
echo -e "${GREEN}✨ Tudo pronto!${NC}"
echo ""
echo -e "${YELLOW}💡 Dica: Veja CONFIGURAR_APP.md para guia detalhado passo a passo${NC}"
