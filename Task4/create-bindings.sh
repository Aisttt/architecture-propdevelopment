#!/bin/bash

# Скрипт для связывания пользователей с ролями в Kubernetes (RBAC)
# Создает RoleBinding и ClusterRoleBinding для пользователей PropDevelopment

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Связывание пользователей с ролями RBAC ===${NC}"

# Проверяем подключение к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Ошибка: Нет подключения к Kubernetes кластеру${NC}"
    echo "Убедитесь что minikube запущен: minikube start"
    exit 1
fi

echo -e "${YELLOW}Создание RoleBindings и ClusterRoleBindings...${NC}"

# 1. CLUSTER ADMIN - системный администратор (полный доступ ко всему кластеру)
echo "1. Привязка admin-system к cluster-admin-role"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-system-binding
subjects:
- kind: User
  name: admin-system
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 2. NAMESPACE ADMINS - лиды команд (админы в своих namespace)

# Sales Lead - админ в sales namespace
echo "2. Привязка sales-lead к namespace-admin-role в sales"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: sales
  name: sales-lead-binding
subjects:
- kind: User
  name: sales-lead
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-admin-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Finance Lead - админ в finance namespace
echo "3. Привязка finance-lead к namespace-admin-role в finance"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: finance
  name: finance-lead-binding
subjects:
- kind: User
  name: finance-lead
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-admin-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 3. DEVELOPERS - разработчики в своих namespace (без доступа к secrets)

# Housing Developer - разработчик в housing namespace
echo "4. Привязка housing-developer к developer-role в housing"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: housing
  name: housing-developer-binding
subjects:
- kind: User
  name: housing-developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 4. VIEWERS - аналитики и менеджеры (только чтение всех ресурсов)

# Data Analyst - чтение всех ресурсов кластера
echo "5. Привязка data-analyst к viewer-role (весь кластер)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: data-analyst-binding
subjects:
- kind: User
  name: data-analyst
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewer-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 5. DEVOPS - DevOps инженеры (настройка кластера, управление CI/CD)

# DevOps Engineer - управление инфраструктурой кластера
echo "6. Привязка devops-engineer к devops-role (кластер)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devops-engineer-binding
subjects:
- kind: User
  name: devops-engineer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: devops-role
  apiGroup: rbac.authorization.k8s.io
EOF

# DevOps Engineer - дополнительные права в ci-cd namespace
echo "7. Привязка devops-engineer к cicd-admin-role в ci-cd"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ci-cd
  name: devops-engineer-cicd-binding
subjects:
- kind: User
  name: devops-engineer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: cicd-admin-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 6. ДОПОЛНИТЕЛЬНЫЕ ПРИВЯЗКИ ДЛЯ ГРУПП

# Создаем привязки для групп пользователей (для будущего расширения)
echo -e "${BLUE}Создание привязок для групп пользователей...${NC}"

# Группа namespace-admins - для всех лидов команд
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: data
  name: namespace-admins-group-binding
subjects:
- kind: Group
  name: namespace-admins
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-admin-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Группа developers - для всех разработчиков
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: api-gateway
  name: developers-group-binding
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Группа viewers - для аналитиков и менеджеров
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-group-binding
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewer-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo -e "${GREEN}=== Все привязки созданы успешно! ===${NC}"

echo -e "${YELLOW}Созданные привязки:${NC}"
echo "ClusterRoleBindings:"
kubectl get clusterrolebindings | grep -E "(admin-system|data-analyst|devops-engineer|viewers-group)"

echo -e "\nRoleBindings по namespace:"
for ns in sales housing finance data api-gateway ci-cd; do
    echo "Namespace: $ns"
    kubectl get rolebindings -n $ns 2>/dev/null | grep -v "NAME" || echo "  (нет привязок)"
done

echo -e "${GREEN}RBAC настройка завершена!${NC}"
echo -e "${YELLOW}Тестирование доступа:${NC}"
echo "1. Переключение на пользователя: export KUBECONFIG=certs/username-kubeconfig"
echo "2. Проверка доступа: kubectl auth can-i get pods"
echo "3. Проверка доступа к secrets: kubectl auth can-i get secrets"

echo -e "${BLUE}Матрица доступов:${NC}"
cat <<EOF

Пользователь              | Кластер | Namespace | Secrets | Описание
-------------------------|---------|-----------|---------|-------------------
admin-system             | ✓       | ✓         | ✓       | Полный доступ
sales-lead               | ✗       | sales     | ✓       | Админ sales
finance-lead             | ✗       | finance   | ✓       | Админ finance  
housing-developer        | ✗       | housing   | ✗       | Разработка housing
data-analyst             | ✓ (RO)  | ✓ (RO)    | ✗       | Только чтение
devops-engineer          | ✓ (WO)  | ci-cd     | ✓       | Настройка + CI/CD

✓ = полный доступ, ✓ (RO) = только чтение, ✓ (WO) = без secrets, ✗ = нет доступа
EOF 