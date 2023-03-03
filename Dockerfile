# Use the official Ruby 3.2.0 Alpine image as the base image
FROM ruby:3.2.0-alpine

# Install system dependencies
RUN apk add --no-cache build-base

RUN gem install bundler --version=2.4.3

# Create a directory for your application
RUN mkdir -p /mrsk

# Set the working directory to /mrsk
WORKDIR /mrsk

# Copy the Gemfile, Gemfile.lock into the container
COPY Gemfile Gemfile.lock mrsk.gemspec ./

# Required in mrsk.gemspec
COPY lib/mrsk/version.rb /mrsk/lib/mrsk/version.rb

# Install gems
RUN bundle install

# Copy the rest of your application code into the container
COPY . .

# Install the gem locally from the project folder
RUN gem build mrsk.gemspec && \
    gem install ./mrsk-*.gem --no-document

# Set the entrypoint to run the installed binary
ENTRYPOINT ["mrsk"]