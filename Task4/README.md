# Task4 - Защита доступа к кластеру Kubernetes

## Цель
Настроить ролевой доступ (RBAC) к Kubernetes кластеру для различных групп пользователей PropDevelopment с учетом организационной структуры и принципа минимальных привилегий.

## Анализ требований

### Организационная структура PropDevelopment
Исходя из архитектуры из предыдущих заданий, компания имеет:
- **4 основных домена**: Sales, Housing, Finance, Data
- **Дополнительный домен**: API Gateway & Security
- **Различные роли**: системные администраторы, лиды команд, разработчики, аналитики, DevOps инженеры

### Требования безопасности
1. **Привилегированная группа** - полный доступ к кластеру (системные администраторы)
2. **Группа просмотра** - только чтение ресурсов (аналитики, менеджеры)
3. **Группа настройки** - управление кластером без привилегированных операций (DevOps)
4. **Разграничение по доменам** - изоляция команд по namespace

## Решение RBAC

### Определенные роли

| Роль | Тип | Права | Применение |
|------|-----|-------|-----------|
| **cluster-admin-role** | ClusterRole | Полный доступ ко всем ресурсам | Системные администраторы |
| **namespace-admin-role** | Role | Полный доступ в назначенном namespace | Лиды команд разработки |
| **developer-role** | Role | Управление приложениями без secrets | Разработчики доменов |
| **viewer-role** | ClusterRole | Только чтение всех ресурсов | Аналитики, менеджеры |
| **devops-role** | ClusterRole | Настройка кластера без secrets приложений | DevOps инженеры |

### Пользователи и их роли

| Пользователь | Группа | Роль | Namespace | Описание |
|-------------|--------|------|-----------|----------|
| **admin-system** | system:masters | cluster-admin-role | Все | Системный администратор |
| **sales-lead** | namespace-admins | namespace-admin-role | sales | Лид команды Sales |
| **finance-lead** | namespace-admins | namespace-admin-role | finance | Лид команды Finance |
| **housing-developer** | developers | developer-role | housing | Разработчик Housing |
| **data-analyst** | viewers | viewer-role | Все (RO) | Аналитик данных |
| **devops-engineer** | devops | devops-role + cicd-admin | Кластер + ci-cd | DevOps инженер |

## Структура файлов

| Файл | Описание |
|------|----------|
| **rbac-roles-table.md** | Детализированная таблица ролей с permissions (apiGroups/resources/verbs) |
| **create-users.sh** | Скрипт создания пользователей с сертификатами (исправлен CA key) |
| **create-roles.sh** | Скрипт создания RBAC ролей в кластере |
| **create-bindings.sh** | Скрипт связывания пользователей с ролями |


## Использование

### 1. Подготовка кластера
```bash
# Запуск Minikube
minikube start

# Проверка подключения
kubectl cluster-info
```

### 2. Создание пользователей
```bash
# Создание сертификатов и kubeconfig файлов
./create-users.sh
```

### 3. Создание ролей
```bash
# Создание RBAC ролей и namespace
./create-roles.sh
```

### 4. Связывание пользователей с ролями
```bash
# Создание RoleBinding и ClusterRoleBinding
./create-bindings.sh
```

### 5. Тестирование доступа

#### Проверка прав доступа от лица администратора

Проверка системного администратора (полные права):
```bash
kubectl auth can-i '*' '*' --as=admin-system
kubectl auth can-i get secrets --as=admin-system
```

#### Проверка разработчиков (нет доступа к secrets)

```bash
kubectl auth can-i get pods --as=housing-developer --namespace=housing
kubectl auth can-i get secrets --as=housing-developer --namespace=housing
kubectl auth can-i create deployments --as=housing-developer --namespace=sales
```

#### Проверка аналитика (только чтение)

```bash
kubectl auth can-i get pods --as=data-analyst
kubectl auth can-i create pods --as=data-analyst
kubectl auth can-i get secrets --as=data-analyst
```

#### Переключение на пользователя для детального тестирования
```bash
# Переключение на пользователя
export KUBECONFIG=certs/data-analyst-kubeconfig

# Проверка текущих прав
kubectl auth can-i get pods
kubectl auth can-i get secrets
kubectl auth can-i create deployments

# Проверка доступа к namespace
kubectl get pods -n sales
```

## Принципы безопасности

### 1. Principle of Least Privilege
- Каждый пользователь получает минимальные необходимые права
- Разработчики не имеют доступа к secrets
- Лиды команд ограничены своими namespace

### 2. Namespace изоляция
- Команды работают только в своих namespace
- Предотвращение межтенантных конфликтов
- Четкое разграничение ответственности

### 3. Защита критических ресурсов
- Доступ к secrets только у администраторов namespace и кластера
- Системные ресурсы доступны только cluster-admin
- RBAC конфигурация защищена от изменений обычными пользователями

### 4. Аудит и мониторинг
- Все действия пользователей логируются
- Возможность отслеживания изменений
- Регулярная ротация сертификатов

## Матрица доступов

| Ресурс | admin-system | sales-lead | housing-developer | data-analyst | devops-engineer |
|---------|-------------|-----------|------------------|-------------|----------------|
| **Pods** | ✓ | ✓ (sales) | ✓ (housing) | ✓ (RO) | ✓ |
| **Services** | ✓ | ✓ (sales) | ✓ (housing) | ✓ (RO) | ✓ |
| **Secrets** | ✓ | ✓ (sales) | ✗ | ✗ | ✓ (ci-cd) |
| **Deployments** | ✓ | ✓ (sales) | ✓ (housing) | ✓ (RO) | ✓ |
| **Namespace** | ✓ | ✗ | ✗ | ✓ (RO) | ✗ |
| **RBAC** | ✓ | ✗ | ✗ | ✗ | ✗ |
| **Nodes** | ✓ | ✗ | ✗ | ✓ (RO) | ✓ (RO) |

**Легенда:** ✓ = полный доступ, ✓ (RO) = только чтение, ✓ (ns) = в своем namespace, ✗ = нет доступа

## Namespace структура

```
PropDevelopment Kubernetes Cluster
├── sales (Sales Domain)
├── housing (Housing Domain)  
├── finance (Finance Domain)
├── data (Data Domain)
├── api-gateway (API Gateway & Security)
├── ci-cd (DevOps и CI/CD)
└── default (системный)
```

## Проверка работы

После настройки RBAC можно протестировать права доступа:

```bash
# Как data-analyst (только чтение)
export KUBECONFIG=certs/data-analyst-kubeconfig
kubectl get pods --all-namespaces  # ✓ Работает
kubectl get secrets -n sales       # ✗ Запрещено

# Как housing-developer (разработчик)
export KUBECONFIG=certs/housing-developer-kubeconfig
kubectl create deployment test -n housing --image=nginx  # ✓ Работает
kubectl get secrets -n housing     # ✗ Запрещено
kubectl get pods -n sales          # ✗ Запрещено

# Как sales-lead (админ namespace)
export KUBECONFIG=certs/sales-lead-kubeconfig
kubectl get secrets -n sales       # ✓ Работает
kubectl delete namespace sales     # ✗ Запрещено (ClusterRole)
```

## Безопасность конфигурации

1. **Сертификаты** хранятся в защищенной директории `certs/`
2. **Приватные ключи** доступны только владельцам
3. **Время жизни сертификатов** ограничено (365 дней)
4. **Групповые привязки** упрощают управление доступом
5. **Регулярная ротация** пользователей и сертификатов 