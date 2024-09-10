FROM ubuntu:22.04

WORKDIR /work

RUN apt-get update --fix-missing && apt-get -y install openssh-client openssl

RUN mkdir ssh && \
  ssh-keygen -t rsa -f ssh/id_rsa -N ""

COPY registry-dns.conf .
COPY boot.sh .

RUN mkdir certs && openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key   -x509 -days 365 -out certs/domain.crt   -subj '/CN=registry' -extensions EXT -config registry-dns.conf

HEALTHCHECK --interval=1s CMD pgrep sleep

CMD ["./boot.sh"]
