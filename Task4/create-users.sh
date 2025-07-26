#!/bin/bash

# Скрипт для создания пользователей Kubernetes для PropDevelopment
# Создает сертификаты и kubeconfig файлы для каждого пользователя

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Создание пользователей Kubernetes для PropDevelopment ===${NC}"

# Создаем директорию для сертификатов
mkdir -p certs
cd certs

# Функция для создания пользователя
create_user() {
    local username=$1
    local group=$2
    
    echo -e "${YELLOW}Создание пользователя: $username (группа: $group)${NC}"
    
    # 1. Создание приватного ключа
    openssl genrsa -out ${username}.key 2048
    
    # 2. Создание запроса на сертификат (CSR)
    openssl req -new -key ${username}.key -out ${username}.csr -subj "/CN=${username}/O=${group}"
    
    # 3. Подписание сертификата через Kubernetes CA
    # Получаем CA сертификат из кластера
    kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d > ca.crt
    
    # Для Minikube получаем CA key из директории .minikube
    MINIKUBE_CA_KEY="$HOME/.minikube/ca.key"
    if [ -f "$MINIKUBE_CA_KEY" ]; then
        cp "$MINIKUBE_CA_KEY" ca.key
    else
        # Альтернативный способ для других кластеров
        echo -e "${YELLOW}Предупреждение: CA key не найден в ~/.minikube/ca.key${NC}"
        echo "Для продакшн кластера необходимо использовать CSR API:"
        echo "kubectl certificate approve ${username}-csr"
        
        # Создаем CSR объект для Kubernetes
        cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${username}-csr
spec:
  request: $(cat ${username}.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
        
        # Одобряем CSR (требует admin права)
        kubectl certificate approve ${username}-csr
        
        # Получаем подписанный сертификат
        kubectl get csr ${username}-csr -o jsonpath='{.status.certificate}' | base64 -d > ${username}.crt
        
        # Пропускаем openssl подписание
        echo -e "${GREEN}Сертификат получен через Kubernetes CSR API${NC}"
        return
    fi
    
    # Подписываем сертификат (только для Minikube)
    openssl x509 -req -in ${username}.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${username}.crt -days 365
    
    # 4. Создание kubeconfig файла для пользователя
    kubectl config set-cluster minikube --certificate-authority=ca.crt --embed-certs=true --server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') --kubeconfig=${username}-kubeconfig
    kubectl config set-credentials ${username} --client-certificate=${username}.crt --client-key=${username}.key --embed-certs=true --kubeconfig=${username}-kubeconfig
    kubectl config set-context ${username}-context --cluster=minikube --user=${username} --kubeconfig=${username}-kubeconfig
    kubectl config use-context ${username}-context --kubeconfig=${username}-kubeconfig
    
    echo -e "${GREEN}Пользователь $username создан успешно${NC}"
}

# Проверяем подключение к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Ошибка: Нет подключения к Kubernetes кластеру${NC}"
    echo "Убедитесь что minikube запущен: minikube start"
    exit 1
fi

echo "Кластер найден, создаем пользователей..."

# Создание пользователей для PropDevelopment

# 1. Системный администратор
create_user "admin-system" "system:masters"

# 2. Лид команды Sales
create_user "sales-lead" "namespace-admins"

# 3. Разработчик Housing команды  
create_user "housing-developer" "developers"

# 4. Аналитик данных
create_user "data-analyst" "viewers"

# 5. DevOps инженер
create_user "devops-engineer" "devops"

# 6. Лид команды Finance
create_user "finance-lead" "namespace-admins"

cd ..

echo -e "${GREEN}=== Все пользователи созданы успешно! ===${NC}"
echo -e "${YELLOW}Файлы созданы в директории certs/:${NC}"
ls -la certs/

echo -e "${YELLOW}Для использования kubeconfig файла:${NC}"
echo "export KUBECONFIG=certs/username-kubeconfig"
echo "kubectl get pods"

echo -e "${GREEN}Следующий шаг: запустите ./create-roles.sh${NC}" 