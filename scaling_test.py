from locust import HttpUser, task, between
import logging

logger = logging.getLogger(__name__)

class ScalingTestUser(HttpUser):
    wait_time = between(0.05, 0.1)  # Быстрые запросы для нагрузки

    @task
    def load_test(self):
        """Создаем нагрузку выше 5 RPS чтобы поды масштабировались"""
        with self.client.get("/", headers={"Connection": "close"}, catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"HTTP {response.status_code}")

                
# Команды для запуска:
# 
# 1. Начни с малой нагрузки (должен быть 1 под)
# locust -f scaling_test.py --host=http://localhost:31693 --users=5 --spawn-rate=1 --headless
#
# 2. Увеличь до 15 RPS (должно создаться 3 пода)  
# locust -f scaling_test.py --host=http://localhost:31693 --users=15 --spawn-rate=5 --headless
#
# 3. Увеличь до 30 RPS (должно создаться 6 подов)
# locust -f scaling_test.py --host=http://localhost:31693 --users=30 --spawn-rate=10 --headless

# Параллельно смотрим:
# watch -n 2 'kubectl get pods,hpa'