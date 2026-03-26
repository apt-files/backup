#!/bin/bash
# /usr/local/bin/backup_services.sh

BACKUP_DIR="/backup"
GLPI_DB_NAME="glpi"
GLPI_DB_USER="glpi"
GLPI_DB_PASS="your_password"          # Замените на реальный пароль или используйте файл .my.cnf
WG_CONFIG_DIR="/opt/wg-dashboard"     # Путь к конфигурации WG Dashboard (хостовые файлы)
MAX_BACKUPS=3
LOG_FILE="/var/log/backup.log"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Создание бэкапа
do_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="glpi_${timestamp}"
    local temp_dir=$(mktemp -d)

    log "Начинаем создание бэкапа $backup_name"

    # Дамп базы GLPI
    if mysqldump -u "$GLPI_DB_USER" -p"$GLPI_DB_PASS" "$GLPI_DB_NAME" > "$temp_dir/glpi_db.sql"; then
        log "Дамп базы данных GLPI создан"
    else
        log "ОШИБКА: не удалось создать дамп базы GLPI"
        rm -rf "$temp_dir"
        return 1
    fi

    # Копирование конфигурации WG Dashboard
    if [ -d "$WG_CONFIG_DIR" ]; then
        cp -r "$WG_CONFIG_DIR" "$temp_dir/wg-dashboard_config"
        log "Конфигурация WG Dashboard скопирована"
    else
        log "ПРЕДУПРЕЖДЕНИЕ: директория конфигурации WG Dashboard не найдена"
    fi

    # Упаковка в tar.gz
    tar -czf "${BACKUP_DIR}/${backup_name}.tar.gz" -C "$temp_dir" .
    local result=$?
    rm -rf "$temp_dir"

    if [ $result -eq 0 ]; then
        log "Бэкап успешно создан: ${BACKUP_DIR}/${backup_name}.tar.gz"
        # Удаляем старые бэкапы, оставляя MAX_BACKUPS последних
        ls -1t "${BACKUP_DIR}"/glpi_*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS+1)) | xargs -r rm -f
        log "Старые бэкапы очищены (оставлено не более $MAX_BACKUPS)"
    else
        log "ОШИБКА: не удалось создать архив"
        return 1
    fi
}

# Проверка необходимости бэкапа при загрузке
check_and_backup() {
    # Находим самый свежий бэкап, который не старше 2 дней
    recent_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name "glpi_*.tar.gz" -mtime -2 | sort | tail -n1)
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