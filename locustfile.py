from locust import HttpUser, task, between
import os

class WebsiteUser(HttpUser):
    # Время ожидания между запросами (для имитации реальных пользователей)
    wait_time = between(0.1, 1.0)
    
    def on_start(self):
        """Выполняется когда пользователь начинает тест"""
        print("🚀 Пользователь начал тестирование")
        
    @task(10)  # Вес 10 - выполняется чаще всего
    def view_homepage(self):
        """Основная нагрузка - просмотр главной страницы"""
        response = self.client.get("/")
        
        # Проверяем успешность запроса
        if response.status_code != 200:
            print(f"❌ Ошибка: {response.status_code}")
        else:
            print("✅ Успешный запрос")
    
    @task(5)   # Вес 5 - выполняется реже
    def quick_reload(self):
        """Быстрая перезагрузка страницы"""
        self.client.get("/")
        
    @task(2)   # Вес 2 - создает пиковую нагрузку
    def stress_burst(self):
        """Создает всплеск нагрузки для триггера автоскейлинга"""
        # Делаем несколько быстрых запросов подряд
        for i in range(5):
            self.client.get("/")
