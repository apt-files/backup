#!/bin/bash

BACKUP_DIR="/backup"
GLPI_DB_NAME="glpi"
GLPI_DB_USER="glpi"
GLPI_DB_PASS='glpiDB$ecret'
MAX_BACKUPS=3
LOG_FILE="/var/log/backup_glpi.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

get_file_timestamp() {
    local filename=$(basename "$1")
    if [[ $filename =~ glpi_([0-9]{8})_([0-9]{6})\.sql\.gz ]]; then
        local date_part="${BASH_REMATCH[1]}"
        local time_part="${BASH_REMATCH[2]}" 

        date -d "${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +%s 2>/dev/null
    else
        echo "0"
    fi
}

do_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/glpi_${timestamp}.sql.gz"

    log "Начинаем создание бэкапа GLPI"

    if mysqldump -u "$GLPI_DB_USER" -p"$GLPI_DB_PASS" "$GLPI_DB_NAME" | gzip > "$backup_file"; then
        log "Бэкап успешно создан: $backup_file"
        ls -1 "${BACKUP_DIR}"/glpi_*.sql.gz 2>/dev/null | sort | head -n -${MAX_BACKUPS} | xargs -r rm -f
        log "Старые бэкапы очищены (оставлено не более $MAX_BACKUPS)"
    else
        log "ОШИБКА: не удалось создать бэкап"
        return 1
    fi
}

check_and_backup() {
    local now=$(date +%s)
    local two_days_ago=$((now - 2*86400))
    local recent_found=0
    local latest_file=""

    # Ищем все файлы бэкапов
    for f in "${BACKUP_DIR}"/glpi_*.sql.gz; do
        [ -e "$f" ] || continue
        local f_ts=$(get_file_timestamp "$f")
        if [ "$f_ts" -gt "$two_days_ago" ]; then
            recent_found=1
            latest_file="$f"
            break
        fi
    done

    if [ $recent_found -eq 1 ]; then
        log "При загрузке: найден свежий бэкап ($latest_file) младше 2 дней, пропускаем."
        exit 0
    else
        log "При загрузке: свежий бэкап не найден, создаём новый."
        do_backup
    fi
}

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
