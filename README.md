# MRSK

MRSK deploys Rails apps in containers to servers running Docker with zero downtime. It uses the dynamic reverse-proxy Traefik to hold requests while the new application container is started and the old one is stopped. It works seamlessly across multiple hosts, using SSHKit to execute commands.

## Installation

Install MRSK globally with `gem install mrsk`. Then, inside your app directory, run `mrsk install`. Now edit the new file `config/deploy.yml`. It could look as simple as this:

```yaml
service: hey
image: 37s/hey
servers:
  - 192.168.0.1
  - 192.168.0.2
registry:
  username: registry-user-name
  password: <%= ENV.fetch("MRSK_REGISTRY_PASSWORD") %>
```

Now you're ready to deploy a multi-arch image to the servers:

```
MRSK_REGISTRY_PASSWORD=pw mrsk deploy
```

This will:

1. Connect to the servers over SSH (using root by default, authenticated by your loaded ssh key)
2. Install Docker on any server that might be missing it (using apt-get)
3. Log into the registry both locally and remotely
4. Build the image using the standard Dockerfile in the root of the application.
5. Push the image to the registry.
6. Pull the image from the registry on the servers.
7. Ensure Traefik is running and accepting traffic on port 80.
8. Stop any containers running a previous versions of the app.
9. Start a new container with the version of the app that matches the current git version hash.
10. Prune unused images and stopped containers to ensure servers don't fill up.

Voila! All the servers are now serving the app on port 80. If you're just running a single server, you're ready to go. If you're running multiple servers, you need to put a load balancer in front of them.

## Why not just run Capistrano or Kubernetes?

MRSK basically is Capistrano for Containers, which allow us to use vanilla servers as the hosts. No need to ensure that the servers have just the right version of Ruby or other dependencies you need. That all lives in the Docker image now. You can boot a brand new Ubuntu (or whatever) server, add it to the deploy servers of MRSK, and it'll be auto-provisioned with Docker, and run right away. Docker's layer caching also allows for quicker deployments with less mucking about on the server. And the images built for MRSK can be used for CI or later introspection.

Kubernetes is a beast. Running it yourself on your own hardware is not for the faint of heart. It's a fine option if you want to run on someone else's platform, like Render or Fly, but if you'd like the freedom to move between cloud and your own hardware, or even mix the two, MRSK is much simpler. You can see everything that's going on, it's just basic Docker commands being called.

## Configuration

### Using .env file to load required environment variables

MRSK uses [dotenv](https://github.com/bkeepers/dotenv) to automatically load environment variables set in the `.env` file present in the application root. This file can be used to set variables like `MRSK_REGISTRY_PASSWORD` or database passwords. But for this reason you must ensure that .env files are not checked into Git or included in your Dockerfile! The format is just key-value like:

```bash
MRSK_REGISTRY_PASSWORD=pw
DB_PASSWORD=secret123
```

### Using another registry than Docker Hub

The default registry is Docker Hub, but you can change it using `registry/server`:

```yaml
registry:
  server: registry.digitalocean.com
  username: registry-user-name
  password: <%= ENV.fetch("MRSK_REGISTRY_PASSWORD") %>
```

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

```
labels:
  traefik.http.routers.hey.rule: '''Host(`app.hey.com`)'''
```

Note: The extra quotes are needed to ensure the rule is passed in correctly!

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

### Using remote builder for native multi-arch

If you're developing on ARM64 (like Apple Silicon), but you want to deploy on AMD64 (x86 64-bit), you can use multi-archecture images. By default, MRSK will setup a local buildx configuration that does this through QEMU emulation. But this can be quite slow, especially on the first build.

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

### Using build secrets for new images

Some images need a secret passed in during build time, like a GITHUB_TOKEN to give access to private gem repositories. This can be done by having the secret in ENV, then referencing it in the builder configuration:

```yaml
builder:
  secrets:
    - GITHUB_TOKEN
```

This build secret can then be referenced in the Dockerfile:

```
# Copy Gemfiles
COPY Gemfile Gemfile.lock ./

# Install dependencies, including private repositories via access token
RUN --mount=type=secret,id=GITHUB_TOKEN \
  BUNDLE_GITHUB__COM=x-access-token:$(cat /run/secrets/GITHUB_TOKEN) \
  bundle install
```

### Using command arguments for Traefik

You can customize the traefik command line:

```yaml
traefik:
  accesslog: true
  accesslog.format: json
  metrics.prometheus: true
  metrics.prometheus.buckets: 0.1,0.3,1.2,5.0
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
# Private repositories need an access token during the build
ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION-slim as base
```

### Using without RAILS_MASTER_KEY

If you're using MRSK with older Rails apps that predate RAILS_MASTER_KEY, or with a non-Rails app, you can skip the default usage and reference:

```yaml
skip_master_key: true
```

### Using accessories for database, cache, search services

You can manage your accessory services via MRSK as well. The services will build off public images, and will not be automatically updated when you deploy:

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
```

Now run `mrsk accessory start mysql` to start the MySQL server on 1.1.1.3. See `mrsk accessory` for all the commands possible.

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


### Running details to see state of containers

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

This is alpha software. Lots of stuff is missing. Lots of stuff will keep moving around for a while.

## License

MRSK is released under the [MIT License](https://opensource.org/licenses/MIT).
