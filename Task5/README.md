# Task5 - Управление трафиком внутри кластера Kubernetes

## Цель

Разграничить трафик между сервисами в Kubernetes кластере с помощью сетевых политик. Обеспечить изоляцию между пользовательскими и административными сервисами.

## Архитектура

Система состоит из 4 сервисов с разрешенными соединениями:

```
Пользователская часть:
┌─────────────────┐    HTTP/80    ┌─────────────────┐
│   front-end     │◄─────────────►│  back-end-api   │
│ (role=front-end)│               │(role=back-end-  │
└─────────────────┘               │    api)         │
                                  └─────────────────┘

Административная часть:
┌─────────────────┐    HTTP/80    ┌─────────────────┐
│ admin-front-end │◄─────────────►│admin-back-end-  │
│(role=admin-     │               │     api         │
│ front-end)      │               │(role=admin-back-│
└─────────────────┘               │ end-api)        │
                                  └─────────────────┘

ИЗОЛЯЦИЯ: Пользовательская и административная части НЕ могут общаться
```

## Реализация

### Файл сетевых политик

**`non-admin-api-allow.yaml`** - содержит 6 политик для реализации требуемой изоляции:

1. **allow-front-end-to-back-end-api** - разрешает `front-end → back-end-api`
2. **allow-back-end-api-to-front-end** - разрешает `back-end-api → front-end`
3. **allow-admin-front-end-to-admin-back-end-api** - разрешает `admin-front-end → admin-back-end-api`
4. **allow-admin-back-end-api-to-admin-front-end** - разрешает `admin-back-end-api → admin-front-end`
5. **default-deny-all-ingress** - запрещает весь входящий трафик по умолчанию
6. **default-deny-all-egress** - запрещает весь исходящий трафик по умолчанию

### Матрица доступов

| Источник | Цель | Статус |
|----------|------|---------|
| front-end | back-end-api | ✅ **РАЗРЕШЕНО** |
| back-end-api | front-end | ✅ **РАЗРЕШЕНО** |
| admin-front-end | admin-back-end-api | ✅ **РАЗРЕШЕНО** |
| admin-back-end-api | admin-front-end | ✅ **РАЗРЕШЕНО** |
| front-end | admin-* | ❌ **ЗАПРЕЩЕНО** |
| back-end-api | admin-* | ❌ **ЗАПРЕЩЕНО** |
| admin-front-end | front-end/back-end-api | ❌ **ЗАПРЕЩЕНО** |
| admin-back-end-api | front-end/back-end-api | ❌ **ЗАПРЕЩЕНО** |

## Использование

### 1. Развертывание сервисов

```bash
# Создание namespace
kubectl create namespace propdevelopment-services

# Развертывание сервисов с метками
kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80 --namespace=propdevelopment-services
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80 --namespace=propdevelopment-services
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80 --namespace=propdevelopment-services
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80 --namespace=propdevelopment-services
```

### 2. Применение сетевых политик

```bash
# Применение политик
kubectl apply -f non-admin-api-allow.yaml

# Проверка политик
kubectl get networkpolicies -n propdevelopment-services
```

### 3. Тестирование

Тестирование разрешенного соединения:
```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --namespace=propdevelopment-services -- sh
/ # wget -qO- --timeout=2 http://back-end-api-app
```

Тестирование запрещенного соединения:
```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --namespace=propdevelopment-services -- sh
/ # wget -qO- --timeout=2 http://admin-back-end-api-app
```

## Ожидаемые результаты

### Успешные соединения ✅
- `front-end ↔ back-end-api`
- `admin-front-end ↔ admin-back-end-api`

### Заблокированные соединения ❌
- Все остальные соединения между сервисами
- Изоляция пользовательской и административной частей

## Принципы безопасности

1. **Zero Trust** - запрещено все по умолчанию
2. **Микросегментация** - изоляция каждого сервиса
3. **Принцип минимальных привилегий** - только необходимые соединения

---

## Соответствие заданию

✅ **Развернуты 4 сервиса** с образом Nginx и соответствующими метками  
✅ **Созданы сетевые политики** в файле `non-admin-api-allow.yaml`  
✅ **Настроена изоляция трафика** между парами сервисов  
✅ **Заблокированы остальные соединения** между сервисами 