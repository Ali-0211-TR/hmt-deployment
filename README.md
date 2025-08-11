# HMT Deployment Repository

Центральный репозиторий для деплоя микросервисной архитектуры HMT.

## Структура

```
hmt-deployment/
├── .env.example              # Пример переменных окружения
├── .env.production          # Production конфигурация
├── docker-compose.yml       # Основной compose файл
├── docker-compose.dev.yml   # Development окружение
├── docker-compose.staging.yml # Staging окружение
├── scripts/                 # Скрипты автоматизации
├── docs/                    # Документация
├── configs/                 # Конфигурационные файлы
├── ssl/                     # SSL сертификаты
├── monitoring/              # Мониторинг и логирование
├── backup/                  # Скрипты бэкапа
├── services/                # Сабмодули сервисов
│   ├── hmt-apigateway/     # API Gateway
│   └── hmt-email-service/  # Email Service
└── ci-cd/                  # CI/CD конфигурации
```

## Быстрый старт

1. Клонирование репозитория с сабмодулями:
```bash
git clone --recursive https://github.com/your-org/hmt-deployment.git
cd hmt-deployment
```

2. Инициализация окружения:
```bash
chmod +x scripts/*.sh
./scripts/init.sh
```

3. Настройка конфигурации:
```bash
cp .env.example .env
# Отредактируйте .env файл
```

4. Запуск в development режиме:
```bash
./scripts/dev-start.sh
```

5. Запуск в production режиме:
```bash
./scripts/prod-start.sh
```

## Работа с сабмодулями

### Добавление нового сервиса
```bash
git submodule add https://github.com/your-org/new-service.git services/new-service
```

### Обновление всех сабмодулей
```bash
./scripts/update-submodules.sh
```

### Обновление конкретного сабмодуля
```bash
git submodule update --remote services/hmt-email-service
```

## Деплой

### Development
```bash
./scripts/dev-deploy.sh
```

### Staging
```bash
./scripts/staging-deploy.sh
```

### Production
```bash
./scripts/prod-deploy.sh
```

## Мониторинг

- Health checks: `./scripts/health-check.sh`
- Логи: `./scripts/logs.sh`
- Метрики: `./scripts/metrics.sh`

## Безопасность

- SSL сертификаты в папке `ssl/`
- Переменные окружения в `.env` файлах
- Секреты в Docker secrets или Kubernetes secrets

## CI/CD

Настроена интеграция с:
- GitHub Actions
- GitLab CI
- Jenkins

## Документация

- [Архитектура](docs/ARCHITECTURE.md)
- [Деплой](docs/DEPLOYMENT.md)
- [Мониторинг](docs/MONITORING.md)
- [Безопасность](docs/SECURITY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
