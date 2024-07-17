FROM registry:4443/nginx:1-alpine-slim

COPY default.conf /etc/nginx/conf.d/default.conf

ARG COMMIT_SHA
RUN echo $COMMIT_SHA > /usr/share/nginx/html/version
RUN mkdir -p /usr/share/nginx/html/versions && echo "version" > /usr/share/nginx/html/versions/$COMMIT_SHA
RUN mkdir -p /usr/share/nginx/html/versions && echo "hidden" > /usr/share/nginx/html/versions/.hidden
RUN echo "Up!" > /usr/share/nginx/html/up
