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
  password: <%= ENV["MRSK_REGISTRY_PASSWORD"] %>
```

Now you're ready to deploy a multi-arch image to the servers:

```
export MRSK_REGISTRY_PASSWORD="<your-real-registry-pwassword>"
mrsk deploy
```

This will:

1. Install Docker on any server that might be missing it (using apt-get)
2. Log into the registry both locally and remotely
3. Build the image using the standard Dockerfile in the root of the application.
4. Push the image to the registry.
5. Pull the image from the registry on the servers.
6. Ensure Traefik is running and accepting traffic on port 80.
7. Stop any containers running a previous versions of the app.
8. Start a new container with the version of the app that matches the current git version hash.
9. Prune unused images and stopped containers to ensure servers don't fill up.

Voila! All the servers are now serving the app on port 80. If you're just running a single server, you're ready to go. If you're running multiple servers, you need to put a load balancer in front of them.

## Why not just run Capistrano or Kubernetes?

MRSK basically is Capistrano for Containers, which allow us to use vanilla servers as the hosts. No need to ensure that the servers have just the right version of Ruby or other dependencies you need. That all lives in the Docker image now. You can boot a brand new Ubuntu (or whatever) server, add it to the deploy servers of MRSK, and it'll be auto-provisioned with Docker, and run right away. Docker's layer caching also allows for quicker deployments with less mucking about on the server. And the images built for MRSK can be used for CI or later introspection.

Kubernetes is a beast. Running it yourself on your own hardware is not for the faint of heart. It's a fine option if you want to run on someone else's platform, like Render or Fly, but if you'd like the freedom to move between cloud and your own hardware, or even mix the two, MRSK is much simpler. You can see everything that's going on, it's just basic Docker commands being called.

## Configuration

### Using another registry than Docker Hub

The default registry for Docker is Docker Hub. If you'd like to use a different one, just configure the server, like so:

```yaml
registry:
  server: registry.digitalocean.com
  username: registry-user-name
  password: <%= ENV["MRSK_REGISTRY_PASSWORD"] %>
```

### Using a different SSH user than root

The default SSH user is root, but you can change it using `ssh_user`:

```yaml
ssh_user: app
```

### Adding custom env variables

You can inject custom env variables into the app containers using `env`:

```yaml
env:
  DATABASE_URL: mysql2://db1/hey_production/
  REDIS_URL: redis://redis1:6379/1
```

### Adding secret custom env variables

If you have custom env variables that are secret, you can divide the `env` block into `clear` and `secret`:

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


### Splitting servers into different roles

If your application uses separate hosts for running jobs or other roles beyond the default web running, you can specify these hosts and their custom entrypoint command like so:

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

Traefik will only be installed and run on the servers in the `web` role (and on all servers if no roles are defined).

### Adding custom container labels

You can specialize the default Traefik rules by setting custom labels on the containers that are being started:

```
labels:
  traefik.http.routers.hey.rule: '''Host(`app.hey.com`)'''
```

(Note: The extra quotes are needed to ensure the rule is passed in correctly!)

This allows you to run multiple applications on the same server sharing the same Traefik instance and port.
See https://doc.traefik.io/traefik/routing/routers/#rule for a full list of available routing rules.

The labels can even be applied on a per-role basis:

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
      my-custom-label: "50"
```

### Configuring remote builder for native multi-arch

If you're developing on ARM64 (like Apple Silicon), but you want to deploy on AMD64 (x86 64-bit), you have to use multi-archecture images. By default, MRSK will setup a local buildx configuration that allows for this through QEMU emulation. This can be slow, especially on the first build.

If you want to speed up this process by using a remote AMD64 host to natively build the AMD64 part of the image, while natively building the ARM64 part locally, you can do so using builder options like follows:

```yaml
builder:
  local:
    arch: arm64
    host: unix:///Users/dhh/.docker/run/docker.sock
  remote:
    arch: amd64
    host: ssh://root@192.168.0.1
```

Note: You must have Docker running on the remote host being used as a builder.

With that configuration in place, you can setup the local/remote configuration using `mrsk build create`. If you wish to remove the contexts and buildx instances again, you can run `mrsk build remove`. If you had already built using the standard emulation setup, run `mrsk build remove` before doing `mrsk build remote`.

### Configuring native builder when multi-arch isn't needed

If you're developing on the same architecture as the one you're deploying on, you can speed up the build a lot by forgoing a multi-arch image. This can be done by configuring the builder like so:

```yaml
builder:
  multiarch: false
```

### Configuring build secrets for new images

Some images need a secret passed in during build time, like a GITHUB_TOKEN to give access to private gem repositories. This can be done by having the secret in ENV, then referencing it like so in the configuration:

```yaml
builder:
  secrets:
    - GITHUB_TOKEN
```

This build secret can then be used in the Dockerfile:

```
# Install application gems
COPY Gemfile Gemfile.lock ./

# Private repositories need an access token during the build
RUN --mount=type=secret,id=GITHUB_TOKEN \
  BUNDLE_GITHUB__COM=x-access-token:$(cat /run/secrets/GITHUB_TOKEN) \
  bundle install
```

### Configuring build args for new images

Build arguments that aren't secret can be configured like so:

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

## Commands

### Remote execution

If you need to execute commands inside the Rails containers, you can use `mrsk app exec`, `mrsk app exec --once`, `mrsk app runner`, and `mrsk app runner --once`. Examples:

```bash
# Runs command on all servers
mrsk app exec 'ruby -v'
App Host: xxx.xxx.xxx.xxx
ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]

App Host: xxx.xxx.xxx.xxx
ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]

# Runs command on first server
mrsk app exec --once 'cat .ruby-version'
3.1.3

# Runs Rails command on all servers
mrsk app exec 'bin/rails about'
App Host: xxx.xxx.xxx.xxx
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

App Host: xxx.xxx.xxx.xxx
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

# Runs Rails runner on first server
mrsk app runner 'puts Rails.application.config.time_zone'
UTC
```

### Running a Rails console on the primary host

If you need to interact with the production console for the app, you can use `mrsk app console`, which will start a Rails console session on the primary host. You can start the console on a different host using `mrsk app console --host 192.168.0.2`. Be mindful that this is a live wire! Any changes made to the production database will take effect immeditately.

### Inspecting

You can see the state of your servers by running `mrsk details`. It'll show something like this:

```
Traefik Host: xxx.xxx.xxx.xxx
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                               NAMES
6195b2a28c81   traefik   "/entrypoint.sh --pr…"   30 minutes ago   Up 19 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   traefik

Traefik Host: 164.92.105.119
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                               NAMES
de14a335d152   traefik   "/entrypoint.sh --pr…"   30 minutes ago   Up 19 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   traefik

App Host: 164.90.145.60
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS          PORTS      NAMES
badb1aa51db3   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   13 minutes ago   Up 13 minutes   3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123

App Host: 164.92.105.119
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS          PORTS      NAMES
1d3c91ed1f55   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   13 minutes ago   Up 13 minutes   3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123
```

You can also see just info for app containers with `mrsk app details` or just for Traefik with `mrsk traefik details`.

### Rollback

If you've discovered a bad deploy, you can quickly rollback by reactivating the old, paused container image. You can see what old containers are available for rollback by running `mrsk app containers`. It'll give you a presentation similar to `mrsk app details`, but include all the old containers as well. Showing something like this:

```
App Host: 164.92.105.119
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS                      PORTS      NAMES
1d3c91ed1f51   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   19 minutes ago   Up 19 minutes               3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123
539f26b28369   registry.digitalocean.com/user/app:e5d9d7c2b898289dfbc5f7f1334140d984eedae4   "/rails/bin/docker-e…"   31 minutes ago   Exited (1) 27 minutes ago              chat-e5d9d7c2b898289dfbc5f7f1334140d984eedae4

App Host: 164.90.145.60
CONTAINER ID   IMAGE                                                                         COMMAND                  CREATED          STATUS                      PORTS      NAMES
badb1aa51db4   registry.digitalocean.com/user/app:6ef8a6a84c525b123c5245345a8483f86d05a123   "/rails/bin/docker-e…"   19 minutes ago   Up 19 minutes               3000/tcp   chat-6ef8a6a84c525b123c5245345a8483f86d05a123
6f170d1172ae   registry.digitalocean.com/user/app:e5d9d7c2b898289dfbc5f7f1334140d984eedae4   "/rails/bin/docker-e…"   31 minutes ago   Exited (1) 27 minutes ago              chat-e5d9d7c2b898289dfbc5f7f1334140d984eedae4
```

From the example above, we can see that `e5d9d7c2b898289dfbc5f7f1334140d984eedae4` was the last version, so it's available as a rollback target. We can perform this rollback by running `mrsk rollback e5d9d7c2b898289dfbc5f7f1334140d984eedae4`. That'll stop `6ef8a6a84c525b123c5245345a8483f86d05a123` and then start `e5d9d7c2b898289dfbc5f7f1334140d984eedae4`. Because the old container is still available, this is very quick. Nothing to download from the registry.

Note that by default old containers are pruned after 3 days when you run `mrsk deploy`.

### Removing

If you wish to remove the entire application, including Traefik, containers, images, and registry session, you can run `mrsk remove`. This will leave the servers clean.

## Stage of development

This is alpha software. Lots of stuff is missing. Lots of stuff will keep moving around for a while.

## License

MRSK is released under the [MIT License](https://opensource.org/licenses/MIT).
