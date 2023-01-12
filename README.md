# MRSK

MRSK ships zero-downtime deploys of Rails apps packed as containers to any host. It uses the dynamic reverse-proxy Traefik to hold requests while the new application container is started and the old one is wound down. It works seamlessly across multiple hosts, using SSHKit to execute commands.

## Installation

Add the gem with `bundle add mrsk`, then run `rake mrsk:init`, and then edit the new file in `config/deploy.yml`. It could look as simple as this:

```yaml
service: hey
image: 37s/hey
servers:
  - 192.168.0.1
  - 192.168.0.2
registry:
  username: <%= Rails.application.credentials.registry["username"] %>
  password: <%= Rails.application.credentials.registry["password"] %>
```

Then ensure your encrypted credentials have the registry username + password by editing them with `rails credentials:edit`:

```
registry:
  username: real-user-name
  password: real-registry-password-or-token
```

Now you're ready to deploy a multi-arch image to the servers:

```
rake mrsk:deploy
```

This will:

1. Log into the registry both locally and remotely
2. Build the image using the standard Dockerfile in the root of the application.
3. Push the image to the registry.
4. Pull the image from the registry on the servers.
5. Ensure Traefik is running and accepting traffic on port 80.
6. Stop any containers running a previous versions of the app.
7. Start a new container with the version of the app that matches the current git version hash.
8. Prune unused images and stopped containers to ensure servers don't fill up.

Voila! All the servers are now serving the app on port 80. If you're just running a single server, you're ready to go. If you're running multiple servers, you need to put a load balancer in front of them.

## Configuration

### Using another registry than Docker Hub

The default registry for Docker is Docker Hub. If you'd like to use a different one, just configure the server, like so:

```yaml
registry:
  server: registry.digitalocean.com
  username: <%= Rails.application.credentials.registry["username"] %>
  password: <%= Rails.application.credentials.registry["password"] %>
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

## Commands

### Remote execution

If you need to execute commands inside the Rails containers, you can use `rake mrsk:app:exec`, `rake mrsk:app:exec:once`, `rake mrsk:app:exec:rails`, and `rake mrsk:app:exec:once:rails`. Examples:

```bash
# Runs command on all servers
rake mrsk:app:exec CMD='ruby -v'
App Host: xxx.xxx.xxx.xxx
ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]

App Host: xxx.xxx.xxx.xxx
ruby 3.1.3p185 (2022-11-24 revision 1a6b16756e) [x86_64-linux]

# Runs command on first server
rake mrsk:app:exec:once CMD='cat .ruby-version'
3.1.3

# Runs Rails command on all servers
rake mrsk:app:exec:rails CMD=about
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

# Runs Rails command on first server
rake mrsk:app:exec:once:rails CMD='db:version'
database: storage/production.sqlite3
Current version: 20221231233303
```

### Running a Rails console on the primary host

If you need to interact with the production console for the app, you can use `rake mrsk:app:console`, which will start a Rails console session on the primary host. Be mindful that this is a live wire! Any changes made to the production database will take effect immeditately.

### Inspecting

You can see the state of your servers by running `rake mrsk:info`. It'll show something like this:

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

You can also see just info for app containers with `rake mrsk:app:info` or just for Traefik with `rake mrsk:traefik:info`.

### Rollback

If you've discovered a bad deploy, you can quickly rollback by reactivating the old, paused container image. You can see what old containers are available for rollback by running `rake mrsk:app:containers`. It'll give you a presentation similar to `rake mrsk:app:info`, but include all the old containers as well. Showing something like this:

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

From the example above, we can see that `e5d9d7c2b898289dfbc5f7f1334140d984eedae4` was the last version, so it's available as a rollback target. We can perform this rollback by running `rake mrsk:rollback VERSION=e5d9d7c2b898289dfbc5f7f1334140d984eedae4`. That'll stop `6ef8a6a84c525b123c5245345a8483f86d05a123` and then start `e5d9d7c2b898289dfbc5f7f1334140d984eedae4`. Because the old container is still available, this is very quick. Nothing to download from the registry.

Note that by default old containers are pruned after 3 days when you run `rake mrsk:deploy`.

### Removing

If you wish to remove the entire application, including Traefik, containers, images, and registry session, you can run `rake mrsk:remove`. This will leave the servers clean.

## Stage of development

This is alpha software. Lots of stuff is missing. Here are some of the areas we seek to improve:

- Adapterize commands to work with Podman and other container runners
- Possibly switching to a bin/mrsk command rather than raw rake
- Integrate with cloud CI pipelines

## License

MRSK is released under the [MIT License](https://opensource.org/licenses/MIT).
