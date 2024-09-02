FROM ubuntu:22.04

WORKDIR /work

RUN apt-get update --fix-missing && apt-get -y install openssh-client openssl

RUN mkdir ssh && \
  ssh-keygen -t rsa -f ssh/id_rsa -N ""

COPY registry-dns.conf .
COPY boot.sh .

HEALTHCHECK --interval=1s CMD pgrep sleep

CMD ["./boot.sh"]
