#!/bin/bash
# ============================================
# Script de Backup MySQL
# ============================================
# Executa mysqldump + compressão
# Retenção: 14 dias
# ============================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configurações
BACKUP_DIR="/opt/eopix/db-server/backups/mysql"
RETENTION_DAYS=14
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/${DATE}.sql.gz"
LOG_FILE="/opt/eopix/db-server/backup.log"

# Criar diretório se não existir
mkdir -p "${BACKUP_DIR}"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log "========================================="
log "Iniciando backup MySQL"
log "========================================="

# Verificar se o container MySQL está rodando
if ! docker ps | grep -q eopix-mysql; then
    log "${RED}❌ Container MySQL não está rodando!${NC}"
    exit 1
fi

# Carregar variáveis de ambiente
if [ -f /opt/eopix/db-server/.env ]; then
    source /opt/eopix/db-server/.env
fi

# Verificar se MYSQL_ROOT_PASSWORD está definido
if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
    log "${RED}❌ MYSQL_ROOT_PASSWORD não definido!${NC}"
    exit 1
fi

# Executar backup
log "Executando mysqldump..."
if docker exec eopix-mysql mysqldump \
    -uroot \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --all-databases 2>> "${LOG_FILE}" | gzip > "${BACKUP_FILE}"; then
    
    # Verificar se o arquivo foi criado e tem tamanho > 0
    if [ -f "${BACKUP_FILE}" ] && [ -s "${BACKUP_FILE}" ]; then
        BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
        log "${GREEN}✅ Backup criado com sucesso: ${BACKUP_FILE} (${BACKUP_SIZE})${NC}"
    else
        log "${RED}❌ Erro: Arquivo de backup vazio ou não criado!${NC}"
        exit 1
    fi
else
    log "${RED}❌ Erro ao executar mysqldump!${NC}"
    exit 1
fi

# Limpar backups antigos
log "Limpando backups antigos (retenção: ${RETENTION_DAYS} dias)..."
DELETED=$(find "${BACKUP_DIR}" -name "*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete -print | wc -l)
if [ "${DELETED}" -gt 0 ]; then
    log "${YELLOW}⚠️  ${DELETED} backup(s) antigo(s) removido(s)${NC}"
else
    log "Nenhum backup antigo para remover"
fi

# Listar backups atuais
log "Backups atuais:"
ls -lh "${BACKUP_DIR}"/*.sql.gz 2>/dev/null | tail -5 | while read line; do
    log "  $line"
done

log "========================================="
log "Backup concluído"
log "========================================="

exit 0
