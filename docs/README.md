# Лабораторна 2: масштабування, моніторинг, кеш

## Як працює система

До системи з лаби 1 (ALB → ECS → RDS) додано:

```
k6 ──► ALB ──► ECS, від 1 до 4 задач ──► Redis (кеш списку товарів, 30 с)
                    │                └─► PostgreSQL (RDS)
                    ▼
               CloudWatch: метрики, панель, алерт ──► SNS ──► email
```

- **Автомасштабування** (`terraform/autoscaling.tf`). ECS стежить за середнім CPU задач. Якщо CPU вищий за 60%, додає задачі (до 4), якщо нижчий, прибирає (до 1).
- **Панель** (`terraform/monitoring.tf`). У CloudWatch є панель `pavliuk-tech-dashboard`: кількість задач, CPU, запити, латентність p95, 5xx, CPU бази і влучання в кеш.
- **Сповіщення** (`terraform/monitoring.tf`). Якщо CPU вищий за 70% дві хвилини, приходить лист. Коли все повертається в норму, приходить другий.
- **Кеш** (`app/cache.py`, `terraform/elasticache.tf`). `GET /products` спочатку шукає відповідь у Redis. Якщо там нема, бере з бази і кладе в Redis на 30 с. Заголовок `X-Cache` показує, звідки відповідь: `HIT` (з кешу), `MISS` (з бази) або `OFF` (кеш вимкнено).
- **Розклад** (`terraform/schedule.tf`). Удень мінімум 2 задачі, уночі 1. Вмикається змінною `enable_schedule`.

## Запуск

У `terraform/terraform.tfvars` (його немає в git) має бути пошта для листів:

```hcl
alert_email = "andriipavliuk2006@gmail.com"
```

```bash
cd terraform
terraform apply
```

Після `apply` треба ще дві речі:
1. Підтвердити підписку в листі від AWS, інакше листи-алерти не приходитимуть.
2. Запустити деплой: GitHub → Actions → Deploy → Run workflow. Terraform створює порожній реєстр образів, а збирає образ і запускає застосунок тільки workflow.

Перевірка:

```bash
URL=$(terraform -chdir=terraform output -raw app_url)
curl -si $URL/products | grep -i x-cache   # перший раз MISS
curl -si $URL/products | grep -i x-cache   # другий раз HIT
terraform -chdir=terraform output dashboard_url   # адреса панелі
```

## Тест навантаження

Потрібен [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/). Запуск з кореня репозиторію:

```bash
./loadtest/run.sh 40
```

Число 40 тут означає N, кількість віртуальних користувачів. Результат зберігається в `loadtest/results/`.

## Порівняння з кешем і без

Обидва прогони робляться на 1 задачі, щоб автомасштабування не впливало на результат.

```bash
# 1. Зафіксувати 1 задачу
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --resource-id service/pavliuk-tech-cluster/pavliuk-tech-service \
  --scalable-dimension ecs:service:DesiredCount --min-capacity 1 --max-capacity 1

# 2. Без кешу
terraform -chdir=terraform apply -var cache_enabled=false
#    потім Run workflow; curl має показати X-Cache: OFF
./loadtest/run.sh 20 nocache-1task

# 3. З кешем
terraform -chdir=terraform apply
#    потім Run workflow; curl має показати MISS, потім HIT
./loadtest/run.sh 20 cache-1task

# 4. Повернути автомасштабування 1–4
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --resource-id service/pavliuk-tech-cluster/pavliuk-tech-service \
  --scalable-dimension ecs:service:DesiredCount --min-capacity 1 --max-capacity 4
```

Після зміни `cache_enabled` теж треба запускати Run workflow. Terraform лише реєструє нову версію задачі, а сервіс на неї переводить workflow.

Ліміт 1–4 потрібно повертати командою з кроку 4. `terraform apply` сам його не поверне, бо в `autoscaling.tf` стоїть `ignore_changes` для `min_capacity` і `max_capacity` (так зроблено, щоб розклад міг змінювати мінімум).

## Видалення

```bash
cd terraform
terraform destroy
```

## Звіти

- [AUTOSCALING.md](AUTOSCALING.md): автомасштабування і панель
- [LOADTEST.md](LOADTEST.md): тест навантаження
- [ALERTS.md](ALERTS.md): сповіщення
- [CACHE.md](CACHE.md): кеш
- [SCHEDULE.md](SCHEDULE.md): розклад

Час на графіках CloudWatch вказано в UTC, київський час на 2 години більший.
