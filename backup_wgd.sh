#!/bin/bash

BACKUP_DIR="/backup/wgd"
CONTAINER_NAME="wgdashboard"
DB_DIR_IN_CONTAINER="/opt/wgdashboard/src/db"
MAX_BACKUPS=3
DAYS_THRESHOLD=2

mkdir -p "$BACKUP_DIR"

clean_old_backups() {
    ls -1t ${BACKUP_DIR}/wgd_backup_*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS+1)) | xargs -r rm -f
}

do_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="wgd_backup_${timestamp}"
    local temp_dir="/tmp/${backup_name}"
    mkdir -p "$temp_dir"

    docker cp "${CONTAINER_NAME}:${DB_DIR_IN_CONTAINER}" "$temp_dir/db" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Ошибка: не удалось скопировать папку db из контейнера" >&2
        rm -rf "$temp_dir"
        exit 1
    fi

    tar -czf "${BACKUP_DIR}/${backup_name}.tar.gz" -C "$temp_dir" db
    rm -rf "$temp_dir"

    clean_old_backups
    echo "Бэкап создан: ${BACKUP_DIR}/${backup_name}.tar.gz"
}

if [ "$1" == "boot" ]; then
    if find "$BACKUP_DIR" -maxdepth 1 -name "wgd_backup_*.tar.gz" -mtime -${DAYS_THRESHOLD} | grep -q .; then
        echo "Последний бэкап WG Dashboard создан менее ${DAYS_THRESHOLD} дней назад, пропускаем."
        exit 0
    else
        echo "Свежего бэкапа нет, создаём новый..."
        do_backup
    fi
elif [ "$1" == "scheduled" ]; then
    do_backup
else
    echo "Использование: $0 {boot|scheduled}" >&2
    exit 1
fi
