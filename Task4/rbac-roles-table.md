# RBAC роли для PropDevelopment Kubernetes кластера

## Анализ организационной структуры

Исходя из архитектуры PropDevelopment (4 домена: Sales, Housing, Finance, Data + API Gateway & Security) определены следующие группы пользователей и их потребности в доступе к Kubernetes кластеру.

## Детализированная таблица ролей

| Роль | apiGroups | Resources | Verbs | Группы пользователей |
| --- | --- | --- | --- | --- |
| **cluster-admin-role** | `["*"]` | `["*"]` | `["*"]` | Системные администраторы, SRE команда |
| **namespace-admin-role** | `[""]` | `["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` | Лиды команд разработки |
|  | `["apps"]` | `["deployments", "replicasets", "daemonsets", "statefulsets"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` |  |
|  | `["networking.k8s.io"]` | `["ingresses"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` |  |
|  | `[""]` | `["events"]` | `["get", "list", "watch"]` |  |
| **developer-role** | `[""]` | `["pods", "services", "configmaps", "persistentvolumeclaims"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` | Разработчики доменов |
|  | `[""]` | `["pods/log", "pods/exec"]` | `["get", "list", "watch", "create"]` |  |
|  | `["apps"]` | `["deployments", "replicasets"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` |  |
|  | `[""]` | `["events"]` | `["get", "list", "watch"]` |  |
|  | `[""]` | `["secrets"]` | `[]` *(НЕТ ДОСТУПА)* |  |
| **viewer-role** | `[""]` | `["pods", "services", "configmaps", "persistentvolumeclaims", "namespaces"]` | `["get", "list", "watch"]` | Аналитики данных, менеджеры |
|  | `[""]` | `["pods/log"]` | `["get", "list", "watch"]` |  |
|  | `["apps"]` | `["deployments", "replicasets", "daemonsets", "statefulsets"]` | `["get", "list", "watch"]` |  |
|  | `["networking.k8s.io"]` | `["ingresses"]` | `["get", "list", "watch"]` |  |
|  | `[""]` | `["events"]` | `["get", "list", "watch"]` |  |
|  | `["metrics.k8s.io"]` | `["pods", "nodes"]` | `["get", "list"]` |  |
|  | `[""]` | `["secrets"]` | `[]` *(НЕТ ДОСТУПА)* |  |
| **devops-role** | `[""]` | `["pods", "services", "configmaps", "persistentvolumeclaims"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` | DevOps инженеры |
|  | `["apps"]` | `["deployments", "replicasets", "daemonsets"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` |  |
|  | `["networking.k8s.io"]` | `["ingresses"]` | `["get", "list", "watch", "create", "update", "patch", "delete"]` |  |
|  | `[""]` | `["nodes", "events"]` | `["get", "list", "watch"]` |  |
|  | `["metrics.k8s.io"]` | `["nodes", "pods"]` | `["get", "list"]` |  |
|  | `[""]` | `["secrets"]` | `[]` *(НЕТ ДОСТУПА к application secrets)* |  |

## Mapping пользователей на namespace

| Группа пользователей | Назначенные namespace |
| --- | --- |
| Sales команда | `sales`, `sales-staging` |
| Housing команда | `housing`, `housing-staging` |
| Finance команда | `finance`, `finance-staging` |
| Data команда | `data`, `data-staging` |
| API Gateway команда | `api-gateway`, `gateway-staging` |
| DevOps команда | `ci-cd`, `monitoring`, `kube-system` |
| Системные администраторы | Все namespace |
| Аналитики и менеджеры | Все namespace (только чтение) |

## Принципы безопасности

1. **Principle of Least Privilege** - минимальные необходимые права
2. **Namespace изоляция** - команды работают только в своих namespace
3. **Секреты защищены** - доступ к secrets только у namespace-admin и cluster-admin
4. **Аудит действий** - все действия логируются
5. **Ротация доступов** - регулярная проверка и обновление прав доступа 

## Матрица доступов по ресурсам

| Ресурс/Действие | cluster-admin | namespace-admin | developer | viewer | devops |
| --- | --- | --- | --- | --- | --- |
| **Pods** | CRUD* | CRUD | CRUD | RO | CRUD |
| **Services** | CRUD | CRUD | CRUD | RO | CRUD |
| **Deployments** | CRUD | CRUD | CRUD | RO | CRUD |
| **Secrets** | CRUD | CRUD | ❌ | ❌ | ❌** |
| **ConfigMaps** | CRUD | CRUD | CRUD | RO | CRUD |
| **Ingresses** | CRUD | CRUD | ❌ | RO | CRUD |
| **Nodes** | CRUD | ❌ | ❌ | RO | RO |
| **RBAC** | CRUD | ❌ | ❌ | ❌ | ❌ |

*CRUD = Create, Read, Update, Delete  
**DevOps имеет доступ только к CI/CD secrets, не к application secrets 