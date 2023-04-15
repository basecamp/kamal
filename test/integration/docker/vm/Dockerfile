FROM ubuntu:22.10

WORKDIR /work

RUN apt-get update && apt-get -y install openssh-client openssh-server docker.io

RUN mkdir /root/.ssh && ln -s /shared/ssh/id_rsa.pub /root/.ssh/authorized_keys
RUN mkdir -p /etc/docker/certs.d/registry:4443 && ln -s /shared/certs/domain.crt /etc/docker/certs.d/registry:4443/ca.crt

COPY boot.sh .

CMD ["./boot.sh"]
