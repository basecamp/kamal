FROM nginx:1-alpine-slim

COPY default.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK --interval=1s CMD pgrep nginx
