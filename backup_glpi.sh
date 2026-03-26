#!/bin/bash
# /usr/local/bin/backup_glpi.sh

BACKUP_DIR="/backup"
GLPI_DB_NAME="glpi"
GLPI_DB_USER="glpi"
GLPI_DB_PASS='glpiDB$ecret'          # Замените на реальный пароль
MAX_BACKUPS=3
LOG_FILE="/var/log/backup_glpi.log"

# Логирование
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Создание бэкапа
do_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/glpi_${timestamp}.sql.gz"

    log "Начинаем создание бэкапа GLPI"

    if mysqldump -u "$GLPI_DB_USER" -p"$GLPI_DB_PASS" "$GLPI_DB_NAME" | gzip > "$backup_file"; then
        log "Бэкап успешно создан: $backup_file"
        # Удаляем старые бэкапы, оставляя MAX_BACKUPS последних
        ls -1t "${BACKUP_DIR}"/glpi_*.sql.gz 2>/dev/null | tail -n +$((MAX_BACKUPS+1)) | xargs -r rm -f
        log "Старые бэкапы очищены (оставлено не более $MAX_BACKUPS)"
    else
        log "ОШИБКА: не удалось создать бэкап"
        return 1
    fi
}

# Проверка при загрузке
check_and_backup() {
    # Ищем самый свежий бэкап, созданный не более 2 дней назад
    recent_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name "glpi_*.sql.gz" -mtime -2 | sort | tail -n1)
    if [ -n "$recent_backup" ]; then
        log "При загрузке: найден свежий бэкап ($recent_backup) младше 2 дней, пропускаем."
        exit 0
    else
        log "При загрузке: свежий бэкап не найден, создаём новый."
        do_backup
    fi
}

# Основная логика
case "$1" in
    boot)
        check_and_backup
        ;;
    scheduled)
        log "Плановый запуск: создаём бэкап."
        do_backup
        ;;
    *)
        echo "Использование: $0 {boot|scheduled}" >&2
        exit 1
        ;;
esac

exit 0
