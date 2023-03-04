# Use the official Ruby 3.2.0 Alpine image as the base image
FROM ruby:3.2.0-alpine

# Set the working directory to /mrsk
WORKDIR /mrsk

# Copy the Gemfile, Gemfile.lock into the container
COPY Gemfile Gemfile.lock mrsk.gemspec ./

# Required in mrsk.gemspec
COPY lib/mrsk/version.rb /mrsk/lib/mrsk/version.rb

# Install system dependencies
RUN apk add --no-cache --update build-base git docker openrc \
    && rc-update add docker boot \
    && gem install bundler --version=2.4.3 \
    && mkdir -p /mrsk \
    && bundle install

# Copy the rest of our application code into the container.
# We do this after bundle install, to avoid having to run bundle
# everytime we do small fixes in the source code.
COPY . .

# Install the gem locally from the project folder
RUN gem build mrsk.gemspec && \
    gem install ./mrsk-*.gem --no-document

# Set the working directory to /workdir
WORKDIR /workdir

# Set the entrypoint to run the installed binary in /workdir
# Example:  docker run -it -v "$PWD:/workdir" mrsk init
ENTRYPOINT ["mrsk"]
