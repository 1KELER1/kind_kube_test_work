FROM nginx:alpine
RUN apk add --no-cache curl
COPY ./static-html.html /usr/share/nginx/html/index.html

RUN cat > /etc/nginx/nginx.conf << 'EOF'
events { worker_connections 50; }
http {
    include /etc/nginx/mime.types;
    
    # 5 RPS с возможностью пакетных запросов
    limit_req_zone $binary_remote_addr zone=api5rps:10m rate=5r/s;
    
    server {
        listen 80;
        
        # Разрешаем до 5 запросов в "пакете", остальные в очередь
        limit_req zone=api5rps burst=5 nodelay;
        limit_req_status 503;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    
    server {
        listen 8080;
        location /nginx_status { stub_status on; }
    }
}
EOF
