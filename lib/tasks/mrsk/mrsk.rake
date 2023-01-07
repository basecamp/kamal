namespace :mrsk do
  desc "Push the latest version of the app, ensure Traefik is running, then restart app"
  task deploy: [ "app:push", "traefik:start", "app:restart" ]

  desc "Display information about Traefik and app containers"
  task info: [ "traefik:info", "app:info" ]

  desc "Create config stub"
  task :init do
    Rails.root.join("config/deploy.yml")
  end
end
