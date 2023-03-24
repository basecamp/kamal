# MRSK

MRSK deploys web apps anywhere from bare metal to cloud VMs using Docker with zero downtime. It uses the dynamic reverse-proxy Traefik to hold requests while the new application container is started and the old one is stopped. It works seamlessly across multiple hosts, using SSHKit to execute commands. It was built for Rails applications, but works with any type of web app that can be containerized with Docker.

Watch the screencast: https://www.youtube.com/watch?v=LL1cV2FXZ5I

Join us on Discord: https://discord.gg/YgHVT7GCXS

## Installation

If you have a Ruby environment available, you can install MRSK globally with:

```sh
gem install mrsk
```

...otherwise, you can run a dockerized version via an alias (add this to your ${SHELL}rc to simplify re-use):

```sh
alias mrsk='docker run --rm -it -v $HOME/.ssh:/root/.ssh -v /var/run/docker.sock:/var/run/docker.sock -v ${PWD}/:/workdir  ghcr.io/mrsked/mrsk'
```

Then, inside your app directory, run `mrsk init` (or `mrsk init --bundle` within Rails apps where you want a bin/mrsk binstub). Now edit the new file `config/deploy.yml`. It could look as simple as this:

```yaml
service: hey
image: 37s/hey
servers:
  - 192.168.0.1
  - 192.168.0.2
registry:
  username: registry-user-name
  password:
    - MRSK_REGISTRY_PASSWORD
env:
  secret:
    - RAILS_MASTER_KEY
```

Then edit your `.env` file to add your registry password as `MRSK_REGISTRY_PASSWORD` (and your `RAILS_MASTER_KEY` for production with a Rails app).

Now you're ready to deploy to the servers:

```
mrsk deploy
```

This will:

1. Connect to the servers over SSH (using root by default, authenticated by your ssh key)
2. Install Docker on any server that might be missing it (using apt-get): root access is needed via ssh for this.
3. Log into the registry both locally and remotely
4. Build the image using the standard Dockerfile in the root of the application.
5. Push the image to the registry.
6. Pull the image from the registry onto the servers.
7. Ensure Traefik is running and accepting traffic on port 80.
8. Ensure your app responds with `200 OK` to `GET /up`.
9. Start a new container with the version of the app that matches the current git version hash.
10. Stop the old container running the previous version of the app.
11. Prune unused images and stopped containers to ensure servers don't fill up.

Voila! All the servers are now serving the app on port 80. If you're just running a single server, you're ready to go. If you're running multiple servers, you need to put a load balancer in front of them.

## Vision

In the past decade+, there's been an explosion in commercial offerings that make deploying web apps easier. Heroku kicked it off with an incredible offering that stayed ahead of the competition seemingly forever. These days we have excellent alternatives like Fly.io and Render. And hosted Kubernetes is making things easier too on AWS, GCP, Digital Ocean, and elsewhere. But these are all offerings that have you renting computers in the cloud at a premium. If you want to run on your own hardware, or even just have a clear migration path to do so in the future, you need to carefully consider how locked in you get to these commercial platforms. Preferably before the bills swallow your business whole!

MRSK seeks to bring the advance in ergonomics pioneered by these commercial offerings to deploying web apps anywhere. Whether that's low-cost cloud options without the managed-service markup from the likes of Digital Ocean, Hetzner, OVH, etc, or it's your own colocated bare metal. To MRSK, it's all the same. Feed the config file a list of IP addresses with vanilla Ubuntu servers that have seen no prep beyond an added SSH key, and you'll be running in literally minutes.

This approach gives you enormous portability. You can have your web app deployed on several clouds at ease like this. Or you can buy the baseline with your own hardware, then deploy to a cloud before a big seasonal spike to get more capacity. When you're not locked into a single provider from a tooling perspective, there are a lot of compelling options available.

Ultimately, MRSK is meant to compress the complexity of going to production using open source tooling that isn't tied to any commercial offering. Not to zero, mind you. You're probably still better off with a fully managed service if basic Linux or Docker is still difficult, but as soon as those concepts are familiar, you'll be ready to go with MRSK.

## Why not just run Capistrano, Kubernetes or Docker Swarm?

MRSK basically is Capistrano for Containers, without the need to carefully prepare servers in advance. No need to ensure that the servers have just the right version of Ruby or other dependencies you need. That all lives in the Docker image now. You can boot a brand new Ubuntu (or whatever) server, add it to the list of servers in MRSK, and it'll be auto-provisioned with Docker, and run right away. Docker's layer caching also speeds up deployments with less mucking about on the server. And the images built for MRSK can be used for CI or later introspection.

Kubernetes is a beast. Running it yourself on your own hardware is not for the faint of heart. It's a fine option if you want to run on someone else's platform, either transparently [like Render](https://thenewstack.io/render-cloud-deployment-with-less-engineering/) or explicitly on AWS/GCP, but if you'd like the freedom to move between cloud and your own hardware, or even mix the two, MRSK is much simpler. You can see everything that's going on, it's just basic Docker commands being called.

Docker Swarm is much simpler than Kubernetes, but it's still built on the same declarative model that uses state reconciliation. MRSK is intentionally designed around imperative commands, like Capistrano.

Ultimately, there are a myriad of ways to deploy web apps, but this is the toolkit we're using at [37signals](https://37signals.com) to bring [HEY](https://www.hey.com) [home from the cloud](https://world.hey.com/dhh/why-we-re-leaving-the-cloud-654b47e0) without losing the advantages of modern containerization tooling.

## Running MRSK from Docker

MRSK is packaged up in a Docker container similarly to [rails/docked](https://github.com/rails/docked). This will allow you to run MRSK (from your application directory) without having to install any dependencies other than Docker. Add the following alias to your profile configuration to make working with the container more convenient:

```bash
alias mrsk="docker run -it --rm -v '${PWD}:/workdir' -v '${SSH_AUTH_SOCK}:/ssh-agent' -v /var/run/docker.sock:/var/run/docker.sock -e 'SSH_AUTH_SOCK=/ssh-agent' ghcr.io/mrsked/mrsk:latest"
```

Since MRSK uses SSH to establish a remote connection, it will need access to your SSH agent. The above command uses a volume mount to make it available inside the container and configures the SSH agent inside the container to make use of it.

## Configuration

### Using .env file to load required environment variables

MRSK uses [dotenv](https://github.com/bkeepers/dotenv) to automatically load environment variables set in the `.env` file present in the application root. This file can be used to set variables like `MRSK_REGISTRY_PASSWORD` or database passwords. But for this reason you must ensure that .env files are not checked into Git or included in your Dockerfile! The format is just key-value like:

```bash
MRSK_REGISTRY_PASSWORD=pw
DB_PASSWORD=secret123
```

### Using a generated .env file

#### 1Password as a secret store

If you're using a centralized secret store, like 1Password, you can create `.env.erb` as a template which looks up the secrets. Example of a .env.erb file:

```erb
<% if (session_token = `op signin --account my-one-password-account --raw`.strip) != "" %># Generated by mrsk envify
GITHUB_TOKEN=<%= `gh config get -h github.com oauth_token`.strip %>
MRSK_REGISTRY_PASSWORD=<%= `op read "op://Vault/Docker Hub/password" -n --session  #{session_token}` %>
RAILS_MASTER_KEY=<%= `op read "op://Vault/My App/RAILS_MASTER_SECRET" -n --session #{session_token}` %>
MYSQL_ROOT_PASSWORD=<%= `op read "op://Vault/My App/MYSQL_ROOT_PASSWORD" -n --session #{session_token}` %>
<% else raise ArgumentError, "Session token missing" end %>
```

This template can safely be checked into git. Then everyone deploying the app can run `mrsk envify` when they setup the app for the first time or passwords change to get the correct `.env` file.

If you need separate env variables for different destinations, you can set them with `.env.destination.erb` for the template, which will generate `.env.staging` when run with `mrsk envify -d staging`.

#### Bitwarden as a secret store

If you are using open source secret store like bitwarden, you can create `.env.erb` as a template which looks up the secrets.

You can store `SOME_SECRET` in a secure note in bitwarden vault.

```
$ bw list items --search SOME_SECRET | jq
? Master password: [hidden]

[
  {
    "object": "item",
    "id": "123123123-1232-4224-222f-234234234234",
    "organizationId": null,
    "folderId": null,
    "type": 2,
    "reprompt": 0,
    "name": "SOME_SECRET",
    "notes": "yyy",
    "favorite": false,
    "secureNote": {
      "type": 0
    },
    "collectionIds": [],
    "revisionDate": "2023-02-28T23:54:47.868Z",
    "creationDate": "2022-11-07T03:16:05.828Z",
    "deletedDate": null
  }
]
```

and extract the `id` of `SOME_SECRET` from the `json` above and use in the `erb` below.


Example `.env.erb` file:

```erb
<% if (session_token=`bw unlock --raw`.strip) != "" %># Generated by mrsk envify
SOME_SECRET=<%= `bw get notes 123123123-1232-4224-222f-234234234234 --session #{session_token}` %>
<% else raise ArgumentError, "session_token token missing" end %>
```

Then everyone deploying the app can run `mrsk envify` and mrsk will generate `.env`


### Using another registry than Docker Hub

The default registry is Docker Hub, but you can change it using `registry/server`:

```yaml
registry:
  server: registry.digitalocean.com
  username:
    - DOCKER_REGISTRY_TOKEN
  password:
    - DOCKER_REGISTRY_TOKEN
```

A reference to secret `DOCKER_REGISTRY_TOKEN` will look for `ENV["DOCKER_REGISTRY_TOKEN"]` on the machine running MRSK.

### Using a different SSH user than root

The default SSH user is root, but you can change it using `ssh/user`:

```yaml
ssh:
  user: app
```

### Using a proxy SSH host

If you need to connect to server through a proxy host, you can use `ssh/proxy`:

```yaml
ssh:
  proxy: "192.168.0.1" # defaults to root as the user
```

Or with specific user:

```yaml
ssh:
  proxy: "app@192.168.0.1"
```

### Using env variables

You can inject env variables into the app containers using `env`:

```yaml
env:
  DATABASE_URL: mysql2://db1/hey_production/
  REDIS_URL: redis://redis1:6379/1
```

### Using secret env variables

If you have env variables that are secret, you can divide the `env` block into `clear` and `secret`:

```yaml
env:
  clear:
    DATABASE_URL: mysql2://db1/hey_production/
    REDIS_URL: redis://redis1:6379/1
  secret:
    - DATABASE_PASSWORD
    - REDIS_PASSWORD
```

The list of secret env variables will be expanded at run time from your local machine. So a reference to a secret `DATABASE_PASSWORD` will look for `ENV["DATABASE_PASSWORD"]` on the machine running MRSK. Just like with build secrets.

If the referenced secret ENVs are missing, the configuration will be halted with a `KeyError` exception.

Note: Marking an ENV as secret currently only redacts its value in the output for MRSK. The ENV is still injected in the clear into the container at runtime.

### Using volumes

You can add custom volumes into the app containers using `volumes`:

```yaml
volumes:
  - "/local/path:/container/path"
```

### MRSK env variables

The following env variables are set when your container runs:

`MRSK_CONTAINER_NAME` : this contains the current container name and version

### Using different roles for servers

If your application uses separate hosts for running jobs or other roles beyond the default web running, you can specify these hosts in a dedicated role with a new entrypoint command like so:

```yaml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2
  job:
    hosts:
      - 192.168.0.3
      - 192.168.0.4
    cmd: bin/jobs
```

Note: Traefik will only by default be installed and run on the servers in the `web` role (and on all servers if no roles are defined). If you need Traefik on hosts in other roles than `web`, add `traefik: true`:

```yaml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2
  web2:
    traefik: true
    hosts:
      - 192.168.0.3
      - 192.168.0.4
```

### Using container labels

You can specialize the default Traefik rules by setting labels on the containers that are being started:

```yaml
labels:
  traefik.http.routers.hey.rule: Host(`app.hey.com`)
```

Note: The backticks are needed to ensure the rule is passed in correctly and not treated as command substitution by Bash!

This allows you to run multiple applications on the same server sharing the same Traefik instance and port.
See https://doc.traefik.io/traefik/routing/routers/#rule for a full list of available routing rules.

The labels can also be applied on a per-role basis:

```yaml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2
  job:
    hosts:
      - 192.168.0.3
      - 192.168.0.4
    cmd: bin/jobs
    labels:
      my-label: "50"
```

### Using container options

You can specialize the options used to start containers using the `options` definitions:

```yaml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2
  job:
    hosts:
      - 192.168.0.3
      - 192.168.0.4
    cmd: bin/jobs
    options:
      cap-add: true
      cpu-count: 4
```

That'll start the job containers with `docker run ... --cap-add --cpu-count 4 ...`.

### Using a different stop wait time

On a new deploy, each old running container is gracefully shut down with a `SIGTERM`, and after a grace period of `10` seconds a `SIGKILL` is sent.
You can configure this value via the `stop_wait_time` option:

```yaml
stop_wait_time: 30
```

### Using remote builder for native multi-arch

If you're developing on ARM64 (like Apple Silicon), but you want to deploy on AMD64 (x86 64-bit), you can use multi-architecture images. By default, MRSK will setup a local buildx configuration that does this through QEMU emulation. But this can be quite slow, especially on the first build.

If you want to speed up this process by using a remote AMD64 host to natively build the AMD64 part of the image, while natively building the ARM64 part locally, you can do so using builder options:

```yaml
builder:
  local:
    arch: arm64
    host: unix:///Users/<%= `whoami`.strip %>/.docker/run/docker.sock
  remote:
    arch: amd64
    host: ssh://root@192.168.0.1
```

Note: You must have Docker running on the remote host being used as a builder. This instance should only be shared for builds using the same registry and credentials.

### Using remote builder for single-arch

If you're developing on ARM64 (like Apple Silicon), want to deploy on AMD64 (x86 64-bit), but don't need to run the image locally (or on other ARM64 hosts), you can configure a remote builder that just targets AMD64. This is a bit faster than building with multi-arch, as there's nothing to build locally.

```yaml
builder:
  remote:
    arch: amd64
    host: ssh://root@192.168.0.1
```

### Using native builder when multi-arch isn't needed

If you're developing on the same architecture as the one you're deploying on, you can speed up the build by forgoing both multi-arch and remote building:

```yaml
builder:
  multiarch: false
```

This is also a good option if you're running MRSK from a CI server that shares architecture with the deployment servers.

### Using a different Dockerfile or context when building

If you need to pass a different Dockerfile or context to the build command (e.g. if you're using a monorepo or you have
different Dockerfiles), you can do so in the builder options:

```yaml
# Use a different Dockerfile
builder:
  dockerfile: Dockerfile.xyz

# Set context
builder:
  context: ".."

# Set Dockerfile and context
builder:
  dockerfile: "../Dockerfile.xyz"
  context: ".."
```

### Using build secrets for new images

Some images need a secret passed in during build time, like a GITHUB_TOKEN, to give access to private gem repositories. This can be done by having the secret in ENV, then referencing it in the builder configuration:

```yaml
builder:
  secrets:
    - GITHUB_TOKEN
```

This build secret can then be referenced in the Dockerfile:

```dockerfile
# Copy Gemfiles
COPY Gemfile Gemfile.lock ./

# Install dependencies, including private repositories via access token (then remove bundle cache with exposed GITHUB_TOKEN)
RUN --mount=type=secret,id=GITHUB_TOKEN \
  BUNDLE_GITHUB__COM=x-access-token:$(cat /run/secrets/GITHUB_TOKEN) \
  bundle install && \
  rm -rf /usr/local/bundle/cache
```

### Using command arguments for Traefik

You can customize the traefik command line:

```yaml
traefik:
  args:
    accesslog: true
    accesslog.format: json
```

This will start the traefik container with `--accesslog=true accesslog.format=json`.

### Traefik's host port binding

By default Traefik binds to port 80 of the host machine, it can be configured to use an alternative port:

```yaml
traefik:
  host_port: 8080
```

### Configure docker options for traefik

We allow users to pass additional docker options to the trafik container like 

```yaml
traefik:
  options: 
    publish:
    - 8080:8080
    volumes:
    - /tmp/example.json:/tmp/example.json
    memory: 512m
```

This will start the traefik container with a command like: `docker run ... --volume /tmp/example.json:/tmp/example.json --publish 8080:8080 `


### Configure alternate entrypoints for traefik

You can configure multiple entrypoints for traefik like so:

```yaml
service: myservice

labels:
  traefik.tcp.routers.other.rule: 'HostSNI(`*`)'
  traefik.tcp.routers.other.entrypoints: otherentrypoint
  traefik.tcp.services.other.loadbalancer.server.port: 9000
  traefik.http.routers.myservice.entrypoints: web
  traefik.http.services.myservice.loadbalancer.server.port: 8080

traefik:
  options:
    publish:
      - 9000:9000
  args:
    entrypoints.web.address: ':80'
    entrypoints.otherentrypoint.address: ':9000'
```

### Configuring build args for new images

Build arguments that aren't secret can also be configured:

```yaml
builder:
  args:
    RUBY_VERSION: 3.2.0
```

This build argument can then be used in the Dockerfile:

```
ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION-slim as base
```

### Using accessories for database, cache, search services

You can manage your accessory services via MRSK as well. Accessories are long-lived services that your app depends on. They are not updated when you deploy.

```yaml
accessories:
  mysql:
    image: mysql:5.7
    host: 1.1.1.3
    port: 3306
    env:
      clear:
        MYSQL_ROOT_HOST: '%'
      secret:
        - MYSQL_ROOT_PASSWORD
    volumes:
      - /var/lib/mysql:/var/lib/mysql
  redis:
    image: redis:latest
    host: 1.1.1.4
    port: "36379:6379"
    volumes:
      - /var/lib/redis:/data
  internal-example:
    image: registry.digitalocean.com/user/otherservice:latest
    host: 1.1.1.5
    port: 44444
```

Now run `mrsk accessory start mysql` to start the MySQL server on 1.1.1.3. See `mrsk accessory` for all the commands possible.

Accessory images must be public or tagged in your private registry.

### Using Cron

You can use a specific container to run your Cron jobs:

```yaml
servers:
  cron:
    hosts:
      - 192.168.0.1
    cmd:
      bash -c "cat config/crontab | crontab - && cron -f"
```

This assumes the Cron settings are stored in `config/crontab`.

### Using audit broadcasts

If you'd like to broadcast audits of deploys, rollbacks, etc to a chatroom or elsewhere, you can configure the `audit_broadcast_cmd` setting with the path to a bin file that will be passed the audit line as the first argument:

```yaml
audit_broadcast_cmd:
  bin/audit_broadcast
```

The broadcast command could look something like:

```bash
#!/usr/bin/env bash
curl -q -d content="[My App] ${1}" https://3.basecamp.com/XXXXX/integrations/XXXXX/buckets/XXXXX/chats/XXXXX/lines
```

That'll post a line like follows to a preconfigured chatbot in Basecamp:

```
[My App] [dhh] Rolled back to version d264c4e92470ad1bd18590f04466787262f605de
```

### Using custom healthcheck path or port

MRSK defaults to checking the health of your application again `/up` on port 3000. You can tailor both with the `healthcheck` setting:

```yaml
healthcheck:
  path: /healthz
  port: 4000
```

This will ensure your application is configured with a traefik label for the healthcheck against `/healthz` and that the pre-deploy healthcheck that MRSK performs is done against the same path on port 4000.

## Commands

### Running commands on servers

You can execute one-off commands on the servers:

```bash
# Runs command on all servers
mrsk app exec 'ruby -v'
App Host: 192.168.0.1
ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]

App Host: 192.168.0.2
ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]

# Runs command on primary server
mrsk app exec --primary 'cat .ruby-version'
App Host: 192.168.0.1
3.1.3

# Runs Rails command on all servers
mrsk app exec 'bin/rails about'
App Host: 192.168.0.1
About your application's environment
Rails version             7.1.0.alpha
Ruby version              ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]
RubyGems version          3.3.26
Rack version              2.2.5
Middleware                ActionDispatch::HostAuthorization, Rack::Sendfile, ActionDispatch::Static, ActionDispatch::Executor, Rack::Runtime, Rack::MethodOverride, ActionDispatch::RequestId, ActionDispatch::RemoteIp, Rails::Rack::Logger, ActionDispatch::ShowExceptions, ActionDispatch::DebugExceptions, ActionDispatch::Callbacks, ActionDispatch::Cookies, ActionDispatch::Session::CookieStore, ActionDispatch::Flash, ActionDispatch::ContentSecurityPolicy::Middleware, ActionDispatch::PermissionsPolicy::Middleware, Rack::Head, Rack::ConditionalGet, Rack::ETag, Rack::TempfileReaper
Application root          /rails
Environment               production
Database adapter          sqlite3
Database schema version   20221231233303

App Host: 192.168.0.2
About your application's environment
Rails version             7.1.0.alpha
Ruby version              ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]
RubyGems version          3.3.26
Rack version              2.2.5
Middleware                ActionDispatch::HostAuthorization, Rack::Sendfile, ActionDispatch::Static, ActionDispatch::Executor, Rack::Runtime, Rack::MethodOverride, ActionDispatch::RequestId, ActionDispatch::RemoteIp, Rails::Rack::Logger, ActionDispatch::ShowExceptions, ActionDispatch::DebugExceptions, ActionDispatch::Callbacks, ActionDispatch::Cookies, ActionDispatch::Session::CookieStore, ActionDispatch::Flash, ActionDispatch::ContentSecurityPolicy::Middleware, ActionDispatch::PermissionsPolicy::Middleware, Rack::Head, Rack::ConditionalGet, Rack::ETag, Rack::TempfileReaper
Application root          /rails
Environment               production
Database adapter          sqlite3
Database schema version   20221231233303

# Run Rails runner on primary server
mrsk app exec -p 'bin/rails runner "puts Rails.application.config.time_zone"'
UTC
```

### Running interactive commands over SSH

You can run interactive commands, like a Rails console or a bash session, on a server (default is primary, use `--hosts` to connect to another):

```bash
# Starts a bash session in a new container made from the most recent app image
mrsk app exec -i bash

# Starts a bash session in the currently running container for the app
mrsk app exec -i --reuse bash

# Starts a Rails console in a new container made from the most recent app image
mrsk app exec -i 'bin/rails console'
```


### Running details to show state of containers

You can see the state of your servers by running `mrsk details`:

```
Traefik Host: 192.168.0.1
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                               NAMES
6195b2a28c81   traefik   "/entrypoint.sh --pr…"   30 minutes ago   Up 19 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   traefik

Traefik Host: 192.168.0.2
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                               NAMES
de14a335d152   traefik   "/entrypoint.sh --pr…"   30 minutes ago   Up 19 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   traefik

App Host: 192.168.0.1
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS          PORTS      NAMES
badb1aa51db3   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   13 minutes ago   Up 13 minutes   3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123

App Host: 192.168.0.2
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS          PORTS      NAMES
1d3c91ed1f55   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   13 minutes ago   Up 13 minutes   3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123
```

You can also see just info for app containers with `mrsk app details` or just for Traefik with `mrsk traefik details`.

### Running rollback to fix a bad deploy

If you've discovered a bad deploy, you can quickly rollback by reactivating the old, paused container image. You can see what old containers are available for rollback by running `mrsk app containers`. It'll give you a presentation similar to `mrsk app details`, but include all the old containers as well. Showing something like this:

```
App Host: 192.168.0.1
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS                      PORTS      NAMES
1d3c91ed1f51   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   19 minutes ago   Up 19 minutes               3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123
539f26b28369   registry.digitalocean.com/user/app:e5d9d7c2b898289dfbc5f7f1334140d984eedae4   "/rails/bin/docker-e…"   31 minutes ago   Exited (1) 27 minutes ago              chat-e5d9d7c2b898289dfbc5f7f1334140d984eedae4

App Host: 192.168.0.2
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS                      PORTS      NAMES
badb1aa51db4   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   19 minutes ago   Up 19 minutes               3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123
6f170d1172ae   registry.digitalocean.com/user/app:e5d9d7c2b898289dfbc5f7f1334140d984eedae4   "/rails/bin/docker-e…"   31 minutes ago   Exited (1) 27 minutes ago              chat-e5d9d7c2b898289dfbc5f7f1334140d984eedae4
```

From the example above, we can see that `e5d9d7c2b898289dfbc5f7f1334140d984eedae4` was the last version, so it's available as a rollback target. We can perform this rollback by running `mrsk rollback e5d9d7c2b898289dfbc5f7f1334140d984eedae4`. That'll stop `6ef8a6a84c525b123c5245345a8483f86d05a123` and then start `e5d9d7c2b898289dfbc5f7f1334140d984eedae4`. Because the old container is still available, this is very quick. Nothing to download from the registry.

Note that by default old containers are pruned after 3 days when you run `mrsk deploy`.

### Running removal to clean up servers

If you wish to remove the entire application, including Traefik, containers, images, and registry session, you can run `mrsk remove`. This will leave the servers clean.

## Stage of development

This is beta software. Commands may still move around. But we're live in production at [37signals](https://37signals.com).

## License

MRSK is released under the [MIT License](https://opensource.org/licenses/MIT).
