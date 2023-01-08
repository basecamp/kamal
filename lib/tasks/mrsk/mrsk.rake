require_relative "setup"

namespace :mrsk do
  desc "Deploy app for the first time to a fresh server"
  task fresh: [ "server:bootstrap", "registry:login", "app:deliver", "traefik:start", "app:stop", "app:run" ]

  desc "Push the latest version of the app, ensure Traefik is running, then restart app"
  task deploy: [ "registry:login", "app:deliver", "traefik:start", "app:stop", "app:run", "prune" ]

  desc "Rollback to VERSION=x that was already run as a container on servers"
  task rollback: [ "app:restart" ]

  desc "Display information about Traefik and app containers"
  task info: [ "traefik:info", "app:info" ]

  desc "Create config stub in config/deploy.yml"
  task :init do
    require "fileutils"
    FileUtils.cp_r \
      Pathname.new(File.expand_path("templates/deploy.yml", __dir__)),
      Rails.root.join("config/deploy.yml")
  end
end
