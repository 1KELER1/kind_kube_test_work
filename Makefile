
# Переменные
PROJECT_NAME = kubernetes-autoscaler
CLUSTER_NAME = test1-cluster
NAMESPACE = default
HELM_REPOS = prometheus-community ingress-nginx kedacore
# переменная для флагов по умолчанию
MAKEFLAGS += --no-print-directory

# Настройки
.PHONY: setup deploy help grafana-info grafana
.DEFAULT_GOAL := help

# Установка зависимостей helm
setup:
	@echo "🔧 Настройка окружения..."
	$(foreach repo,$(HELM_REPOS), \
		-helm repo add $(repo) https://$(repo).github.io/helm-charts;)
	helm repo update
	@echo "✅ Настройка завершена"

# Полное развертывание
deploy: setup
	@echo " Развертывание $(PROJECT_NAME)..."
	kind create cluster --name $(CLUSTER_NAME) --config=kind-rps-cluster.yaml
	kubectl config use-context kind-$(CLUSTER_NAME)
	docker build -t my-static-nginx:latest .
	kind load docker-image my-static-nginx:latest --name $(CLUSTER_NAME)

	helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
  
	helm install keda kedacore/keda --namespace keda-system --create-namespace

	kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s
	kubectl wait --for=condition=Ready pods --all -n keda-system --timeout=120s

	helm install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		--set controller.service.type=NodePort \
		--set controller.service.nodePorts.http=30080 \
		--set controller.metrics.enabled=true \
		--set controller.metrics.serviceMonitor.enabled=true \
		--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus"

	kubectl wait --for=condition=Ready pods --all -n ingress-nginx --timeout=180s

	helm install my-static-site my-nginx/ --namespace $(NAMESPACE)
	kubectl apply -f my-nginx/keda-nginx-simple.yaml --namespace $(NAMESPACE)
	kubectl apply -f my-nginx/nginx-ingress-fixed.yaml --namespace $(NAMESPACE)

	@echo "Развертывание завершено"


check:
	@echo " Команда 2: Проверка и тестирование системы..."
	@echo "===  СТАТУС СИСТЕМЫ ==="
	@echo "Кластеры Kind:"
	@kind get clusters
	@echo ""
	@echo "Helm releases:"
	@helm list --all-namespaces
	@echo ""
	@echo "Статус подов приложения:"
	@kubectl get pods -l app=my-static-site
	@echo ""
	@echo "HPA статус:"
	@kubectl get hpa
	@echo ""
	@echo "ScaledObject статус:"
	@kubectl get scaledobject
	@echo ""
	@echo "===  ДОСТУПЫ ==="
	@echo "Приложение: http://localhost:8080"
	@$(MAKE) grafana-info	 
	@echo ""
	@echo "=== НАГРУЗОЧНОЕ ТЕСТИРОВАНИЕ ==="
	@echo "Создаем нагрузку 10 RPS на 2 минуты..."
	@(for i in $$(seq 1 1200); do curl -s http://localhost:8080/ >/dev/null 2>&1 & sleep 0.1; done) & \
	CURL_PID=$$!; \
	echo "Curl тест запущен (PID: $$CURL_PID)"; \
	echo ""; \
	echo "===================================================="; \
	tput sc 2>/dev/null || printf "\033[s"; \
	for i in $$(seq 1 85); do \
		tput rc 2>/dev/null || printf "\033[u"; \
		tput ed 2>/dev/null || printf "\033[J"; \
		echo "МОНИТОРИНГ АВТОСКЕЙЛИНГА - $$(date +%H:%M:%S) ($$i/85)"; \
		echo "===================================================="; \
		kubectl get hpa 2>/dev/null || echo "Нет данных HPA"; \
		echo ""; \
		kubectl get pods -l app=my-static-site 2>/dev/null || echo "Нет данных подов"; \
		sleep 3; \
	done
	@echo ""
	@echo "Для интерактивного Locust: make locust"

# Получить информацию о доступе к Grafana
grafana-info:
	@echo " Информация для доступа к Grafana:"
	@echo "URL: http://localhost:3000"
	@echo "Логин: admin"
	@echo -n "Пароль: "
	@kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo



# Загрузка нужных библиотек для locust
locust_uploading:
	python3 -m venv venv
	source venv/bin/activate
	pip install -r requirements.txt

# locust для нагрзуки
locust: locust_uploading
	@echo "Запуск locust(Ctrl+C для остановки)..."
	@echo "Откройте Web UI Locust: http://localhost:8089"
	@echo "Один users равен 5 RPS"
	locust -f test_5rps.py --host=http://localhost:8080 --users=2 --spawn-rate=1


manifest_update:
	helm upgrade my-static-site my-nginx/ --namespace $(NAMESPACE)
	kubectl apply -f my-nginx/keda-nginx-simple.yaml --namespace $(NAMESPACE)
	kubectl apply -f my-nginx/nginx-ingress-fixed.yaml --namespace $(NAMESPACE)


# Справка
help:
	@echo " Доступные команды:"
	@echo "  setup   - Установка Helm репозиториев"
	@echo "  deploy  - Полное развертывание проекта"
	@echo "  grafana - Получение доступа к графане"
	@echo "  locust  - Доступ к locust для нагрузочного тестирования"
	

# Передача переменных из командной строки
deploy-custom:
	make deploy CLUSTER_NAME=$(name) NAMESPACE=$(ns)
