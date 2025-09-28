FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY ./static-html.html /usr/share/nginx/html/index.html
EXPOSE 80