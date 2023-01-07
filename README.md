# MRSK

MRSK lets you do zero-downtime deploys of Rails apps packed as containers to any host running Docker. It uses the dynamic reverse-proxy Traefik to hold requests while the new application container is started and the old one is wound down. It works across multiple hosts at the same time, using SSHKit to execute commands.

## Installation

Create a configuration file for MRSK in `config/deploy.yml` that looks like this:

```yaml
service: my-app
image: name/my-app
servers:
  - xxx.xxx.xxx.xxx
  - xxx.xxx.xxx.xxx
env:
  DATABASE_URL: mysql2://username@localhost/database_name/
  REDIS_URL: redis://host:6379/1
```

Then first login to the Docker Hub registry on the servers:

```
rake mrsk:registry:login DOCKER_USER=name DOCKER_PASSWORD=pw
```

Now you're ready to deploy a multi-arch image (FIXME: currently you need to manually run `docker buildx create --use` once first):

```
rake mrsk:deploy
```

This will:

1. Build the image using the standard Dockerfile in the root of the application.
2. Push the image to the registry.
3. Pull the image on all the servers.
4. Ensure Traefik is running and accepting traffic on port 80.
5. Stop any containers running a previous versions of the app.
6. Start a new container with the version of the app that matches the current git version hash.

Voila! All the servers are now serving the app on port 80, and you're ready to put them behind a load balancer to serve live traffic.

## Stage of development

This is alpha software. Lots of stuff is missing. Here are some of the areas we seek to improve:

- Use of other registries than Docker Hub
- Adapterize commands to work with Podman and other container runners
- Better flow for secrets and ENV
- Possibly switching to a bin/mrsk command rather than raw rake
- Integrate wirmth cloud CI pipelines

## License

Mrsk is released under the [MIT License](https://opensource.org/licenses/MIT).
