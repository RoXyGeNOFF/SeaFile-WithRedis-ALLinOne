#!/usr/bin/env bash
set -e

echo "=== Seafile CE One-Click Installer ==="

# Проверка зависимостей
check_dep() {
  if ! command -v $1 &>/dev/null; then
    echo "❌ Требуется $1, но он не найден в PATH."
    echo "Пожалуйста, установите $1 и перезапустите скрипт."
    exit 1
  fi
}

check_dep docker
check_dep docker compose
check_dep make

# Запуск
echo "✅ Все зависимости найдены."
echo "⏳ Скачиваем образы и запускаем..."
make up

echo ""
echo "🎉 Готово! Seafile будет доступен через минуту по адресу:"
echo "   http://localhost/"
echo ""
echo "Логин администратора и пароль смотрите в файле .env (INIT_SEAFILE_ADMIN_EMAIL / INIT_SEAFILE_ADMIN_PASSWORD)."
