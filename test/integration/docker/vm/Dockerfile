FROM ubuntu:22.04

WORKDIR /work

RUN apt-get update --fix-missing && apt-get -y install openssh-client openssh-server docker.io

RUN mkdir /root/.ssh && ln -s /shared/ssh/id_rsa.pub /root/.ssh/authorized_keys

RUN echo "HOST_TOKEN=abcd" >> /etc/environment

COPY boot.sh .

HEALTHCHECK --interval=1s CMD pgrep dockerd

CMD ["./boot.sh"]
