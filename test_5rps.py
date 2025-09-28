from locust import HttpUser, task, constant
import time, logging

logger = logging.getLogger(__name__)

class SinglePodUser(HttpUser):
    wait_time = constant(0.2)  # 1 запрос каждые 200 мс = 5 RPS

    @task
    def homepage(self):
        self.client.get("/", headers={"Connection": "close"})  # закрываем соединение


# locust -f test_5rps.py --host=http://localhost:31693 --users=1 --spawn-rate=1 --headless
