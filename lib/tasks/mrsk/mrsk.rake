require_relative "setup"

namespace :mrsk do
  desc "Deploy app for the first time to a fresh server"
  task fresh: %w[ server:bootstrap registry:login app:deliver traefik:run app:stop app:run ]

  desc "Push the latest version of the app, ensure Traefik is running, then restart app"
  task deploy: %w[ registry:login app:deliver traefik:run app:stop app:run prune ]

  desc "Rollback to VERSION=x that was already run as a container on servers"
  task rollback: %w[ app:restart ]

  desc "Display information about Traefik and app containers"
  task info: %w[ traefik:info app:info ]

  desc "Create config stub in config/deploy.yml"
  task :init do
    require "fileutils"

    if (deploy_file = Rails.root.join("config/deploy.yml")).exist?
      puts "Config file already exists in config/deploy.yml (remove first to create a new one)"
    else
      FileUtils.cp_r Pathname.new(File.expand_path("templates/deploy.yml", __dir__)), deploy_file
      puts "Created configuration file in config/deploy.yml"
    end

    if (binstub = Rails.root.join("bin/mrsk")).exist?
      puts "Binstub already exists in bin/mrsk (remove first to create a new one)"
    else
      FileUtils.cp_r Pathname.new(File.expand_path("templates/mrsk", __dir__)), binstub
      puts "Created binstub file in bin/mrsk"
    end
  end

  desc "Remove Traefik, app, and registry session from servers"
  task remove: %w[ traefik:remove app:remove registry:logout ]
end
