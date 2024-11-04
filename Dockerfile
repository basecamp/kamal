FROM ruby:3.3-alpine

# Install docker/buildx-bin
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx

# Set the working directory to /kamal
WORKDIR /kamal

# Copy the Gemfile, Gemfile.lock into the container
COPY Gemfile Gemfile.lock kamal.gemspec ./

# Required in kamal.gemspec
COPY lib/kamal/version.rb /kamal/lib/kamal/version.rb

# Install system dependencies
RUN apk add --no-cache build-base git docker openrc openssh-client-default \
    && rc-update add docker boot \
    && gem install bundler --version=2.4.3 \
    && bundle install

# Copy the rest of our application code into the container.
# We do this after bundle install, to avoid having to run bundle
# every time we do small fixes in the source code.
COPY . .

# Install the gem locally from the project folder
RUN gem build kamal.gemspec && \
    gem install ./kamal-*.gem --no-document

# Set the working directory to /workdir
WORKDIR /workdir

# Tell git it's safe to access /workdir/.git even if
# the directory is owned by a different user
RUN git config --global --add safe.directory '*'

# Set the entrypoint to run the installed binary in /workdir
# Example:  docker run -it -v "$PWD:/workdir" kamal init
ENTRYPOINT ["kamal"]
