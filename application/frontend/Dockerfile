FROM docker.io/nginxinc/nginx-unprivileged:1.27-alpine
ENV AUTH_HOST=auth:8080 \
    PRODUCTS_HOST=products:4567 \
    SEARCH_HOST=search:8000
# nginx image runs envsubst on /etc/nginx/templates/*.template at startup
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 8080
