namespace :mrsk do
  desc "Deploy app for the first time to a fresh server"
  task fresh: [ "server:bootstrap", "registry:login", "app:deliver", "traefik:start", "app:start" ]

  desc "Push the latest version of the app, ensure Traefik is running, then restart app"
  task deploy: [ "registry:login", "app:push", "traefik:start", "app:restart" ]

  desc "Display information about Traefik and app containers"
  task info: [ "traefik:info", "app:info" ]

  desc "Create config stub"
  task :init do
    Rails.root.join("config/deploy.yml")
  end
end
