FROM ruby:3.2

WORKDIR /

ENV VERBOSE=true

RUN apt-get update --fix-missing && apt-get install -y ca-certificates openssh-client curl gnupg docker.io

RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN apt-get update --fix-missing && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

COPY *.sh .
COPY app/ app/
COPY app_with_roles/ app_with_roles/
COPY app_with_traefik/ app_with_traefik/
COPY app_with_proxied_accessory/ app_with_proxied_accessory/

RUN rm -rf /root/.ssh
RUN ln -s /shared/ssh /root/.ssh
RUN mkdir -p /etc/docker/certs.d/registry:4443 && ln -s /shared/certs/domain.crt /etc/docker/certs.d/registry:4443/ca.crt

RUN git config --global user.email "deployer@example.com"
RUN git config --global user.name "Deployer"
RUN cd app && git init && git add . && git commit -am "Initial version"
RUN cd app_with_roles && git init && git add . && git commit -am "Initial version"
RUN cd app_with_traefik && git init && git add . && git commit -am "Initial version"
RUN cd app_with_proxied_accessory && git init && git add . && git commit -am "Initial version"

HEALTHCHECK --interval=1s CMD pgrep sleep

CMD ["./boot.sh"]
