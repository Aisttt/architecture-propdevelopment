#!/bin/bash

# Скрипт для создания RBAC ролей в Kubernetes для PropDevelopment
# Создает Role и ClusterRole с соответствующими правами

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Создание RBAC ролей для PropDevelopment ===${NC}"

# Проверяем подключение к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Ошибка: Нет подключения к Kubernetes кластеру${NC}"
    echo "Убедитесь что minikube запущен: minikube start"
    exit 1
fi

# Создаем namespace для каждого домена
echo -e "${BLUE}Создание namespace для доменов PropDevelopment...${NC}"
kubectl create namespace sales --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace housing --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace finance --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace api-gateway --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ci-cd --dry-run=client -o yaml | kubectl apply -f -

echo -e "${YELLOW}Создание ролей RBAC...${NC}"

# 1. CLUSTER ADMIN ROLE - полный доступ ко всем ресурсам кластера
echo "1. Создание cluster-admin-role (полный доступ)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
EOF

# 2. NAMESPACE ADMIN ROLE - полный доступ к ресурсам в назначенных namespace
echo "2. Создание namespace-admin-role (админ в namespace)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: sales
  name: namespace-admin-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
EOF

# Копируем роль namespace-admin в другие namespace
for ns in housing finance data api-gateway; do
    kubectl get role namespace-admin-role -n sales -o yaml | \
    sed "s/namespace: sales/namespace: $ns/" | \
    kubectl apply -f -
done

# 3. DEVELOPER ROLE - создание и управление приложениями (без secrets)
echo "3. Создание developer-role (разработчики)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: sales
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# НЕТ доступа к secrets!
EOF

# Копируем developer-role в другие namespace
for ns in housing finance data api-gateway; do
    kubectl get role developer-role -n sales -o yaml | \
    sed "s/namespace: sales/namespace: $ns/" | \
    kubectl apply -f -
done

# 4. VIEWER ROLE - только чтение всех ресурсов (кроме secrets)
echo "4. Создание viewer-role (только чтение)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
# НЕТ доступа к secrets!
EOF

# 5. DEVOPS ROLE - управление CI/CD и настройка кластера
echo "5. Создание devops-role (DevOps инженеры)"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: devops-role
rules:
# Управление основными ресурсами
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Мониторинг и метрики
- apiGroups: [""]
  resources: ["nodes", "events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
# НЕТ доступа к secrets приложений и управлению RBAC
EOF

# Создаем специальную роль для CI/CD namespace с доступом к secrets
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ci-cd
  name: cicd-admin-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF

echo -e "${GREEN}=== Все роли созданы успешно! ===${NC}"

echo -e "${YELLOW}Созданные роли:${NC}"
echo "ClusterRoles:"
kubectl get clusterroles | grep -E "(cluster-admin-role|viewer-role|devops-role)"
echo -e "\nRoles по namespace:"
for ns in sales housing finance data api-gateway ci-cd; do
    echo "Namespace: $ns"
    kubectl get roles -n $ns 2>/dev/null || echo "  (нет ролей)"
done

echo -e "${GREEN}Следующий шаг: запустите ./create-bindings.sh${NC}" 