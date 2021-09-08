FROM nginx:stable-alpine

MAINTAINER Etienne Dauvergne <contact@ekyna.com>

COPY index.html /etc/nginx/html/default/index.html
COPY nginx.conf /etc/nginx/nginx.conf
COPY gencert.sh /root/gencert.sh

RUN apk add --no-cache openssl shadow bash

WORKDIR /root
