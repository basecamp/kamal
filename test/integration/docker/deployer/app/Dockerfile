FROM registry:4443/nginx:1-alpine-slim

COPY default.conf /etc/nginx/conf.d/default.conf

ARG COMMIT_SHA
RUN echo $COMMIT_SHA > /usr/share/nginx/html/version

