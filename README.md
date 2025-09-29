# Kubernetes Deployment Guide

Пошаговая инструкция по развертыванию кластера Kubernetes с мониторингом и автомасштабированием.

---

## 1. Подготовка Python окружения

### Создание виртуального окружения

```bash
python -m venv venv
```

### Активация виртуального окружения

```bash
source venv/bin/activate
```

### Установка зависимостей

```bash
pip install -r requirements.txt
```

---

## 2. Создание кластера Kind

```bash
kind create cluster --name test-cluster --config=kind-rps-cluster.yaml
```

---

## 3. Переключение контекста kubectl

```bash
kubectl config use-context kind-test-cluster
```

---

## 4. Сборка и загрузка Docker-образа

### Сборка образа

```bash
docker build -t my-static-nginx:latest .
```

### Загрузка образа в Kind

```bash
kind load docker-image my-static-nginx:latest --name test-cluster
```

---

## 5. Добавление Helm репозиториев

### Prometheus Community

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

### Ingress Nginx

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

### KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
```

### Обновление репозиториев

```bash
helm repo update
```

---

## 6. Установка Prometheus + Grafana

```bash
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

---

## 7. Установка KEDA

```bash
helm install keda kedacore/keda \
  --namespace keda-system \
  --create-namespace
```

---

## 8. Установка Ingress Nginx

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release="prometheus-stack"
```

---

## 9. Развертывание приложения

### Установка Helm chart

```bash
helm install my-static-site my-nginx/
```

### Применение KEDA ScaledObject

```bash
kubectl apply -f my-nginx/keda-nginx-simple.yaml
```

### Применение Ingress

```bash
kubectl apply -f my-nginx/nginx-ingress-fixed.yaml
```

---

## Проверка развертывания

### Проверка подов

```bash
kubectl get pods -A
```

### Проверка сервисов

```bash
kubectl get svc -A
```

### Проверка Ingress

```bash
kubectl get ingress -A
```

### Проверка KEDA ScaledObject

```bash
kubectl get scaledobject -A
```

---

## Доступ к сервисам

- **Приложение**: http://localhost:30080
- **Grafana**: Получить пароль и настроить port-forward:

### Получение пароля Grafana

```bash
kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Port-forward для Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80
```

Затем открыть: http://localhost:3000 (логин: `admin`)

---

## Удаление ресурсов

### Удаление приложения

```bash
helm uninstall my-static-site
```

### Удаление Ingress Nginx

```bash
helm uninstall ingress-nginx -n ingress-nginx
```

### Удаление KEDA

```bash
helm uninstall keda -n keda-system
```

### Удаление Prometheus Stack

```bash
helm uninstall prometheus-stack -n monitoring
```

### Удаление кластера Kind

```bash
kind delete cluster --name test-cluster
```

---

## Деактивация виртуального окружения Python

```bash
deactivate
```