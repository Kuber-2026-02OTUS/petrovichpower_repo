#!/usr/bin/env bash

set -e

# Цветной вывод для красоты
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   🚀 Automation Deployer          ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# -----------------------------------------------------------------------------
# 0. Проверка наличии необходимых CLI утилит
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 0/4] Проверка окружения...${NC}"
for tool in terraform ansible-playbook git curl; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}❌ Ошибка: Утилита '$tool' не установлена!${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Все необходимые утилиты найдены.${NC}"

# -----------------------------------------------------------------------------
# 1. Поднятие инфраструктуры в Yandex Cloud (Terraform)
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 1/4] Запуск Terraform (Yandex Cloud)...${NC}"
cd terraform

if [ ! -d ".terraform" ]; then
    echo "Инициализация Terraform..."
    terraform init
fi

echo "Применение конфигурации Terraform..."
terraform apply -auto-approve

# Возвращаемся в корень проекта
cd ..

# -----------------------------------------------------------------------------
# 2. Ожидание готовности SSH на созданных виртуальных машинах
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 2/4] Ожидание инициализации ВМ и доступности SSH (30 сек)...${NC}"
sleep 30

# -----------------------------------------------------------------------------
# 3. Конфигурирование кластера и установка сервисов (Ansible)
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[Step 3/4] Запуск Ansible Playbook...${NC}"
cd ansible

# Проверяем, сгенерировался ли inventory файл из Terraform
if [ ! -f "inventory.ini" ]; then
    echo -e "${RED}❌ Ошибка: Файл ansible/inventory.ini не найден! Проверьте Terraform outputs.${NC}"
    exit 1
fi

# Отключаем проверку SSH StrictHostKeyChecking для автоматического первичного подключения
export ANSIBLE_HOST_KEY_CHECKING=False

echo "Запуск развертывания площадки..."
ansible-playbook -i inventory.ini site.yml

cd ..

# -----------------------------------------------------------------------------
# 4. Финал и вывод ссылок
# -----------------------------------------------------------------------------
echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}🎉 Развертывание успешно завершено!                  ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "Доступы к вашим сервисам (HTTPS):"
echo -e "  • ${BLUE}GitLab:${NC}      https://gitlab.petrovich-power.site"
echo -e "  • ${BLUE}Nexus:${NC}       https://nexus.petrovich-power.site"
echo -e "  • ${BLUE}Argo CD:${NC}     https://argocd.petrovich-power.site"
echo -e "  • ${BLUE}Grafana:${NC}     https://grafana.petrovich-power.site"
echo -e "  • ${BLUE}Prometheus:${NC}  https://prometheus.petrovich-power.site"
echo -e "  • ${BLUE}Приложение:${NC}  https://quotes.petrovich-power.site"
echo -e "=====================================================\n"