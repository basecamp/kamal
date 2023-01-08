# MRSK

MRSK ships zero-downtime deploys of Rails apps packed as containers to any host. It uses the dynamic reverse-proxy Traefik to hold requests while the new application container is started and the old one is wound down. It works across multiple hosts at the same time, using SSHKit to execute commands.

## Installation

Create a configuration file for MRSK in `config/deploy.yml` that looks like this:

```yaml
service: my-app
image: name/my-app
servers:
  - xxx.xxx.xxx.xxx
  - xxx.xxx.xxx.xxx
env:
  DATABASE_URL: mysql2://localhost/my-app_production/
  REDIS_URL: redis://host:6379/1
registry:
  # No server definition needed if using Docker Hub
  server: registry.digitalocean.com
  username: <%= Rails.application.credentials.registry["username"] %>
  password: <%= Rails.application.credentials.registry["password"] %>
```

Then ensure your encrypted credentials have the registry username + password by editing them with `rails credentials:edit`:

```
registry:
  username: real-user-name
  password: real-password
```

Now you're ready to deploy a multi-arch image (FIXME: currently you need to manually run `docker buildx create --use` once first):

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

## Stage of development

This is alpha software. Lots of stuff is missing. Here are some of the areas we seek to improve:

- Adapterize commands to work with Podman and other container runners
- Possibly switching to a bin/mrsk command rather than raw rake
- Integrate with cloud CI pipelines

## License

Mrsk is released under the [MIT License](https://opensource.org/licenses/MIT).
