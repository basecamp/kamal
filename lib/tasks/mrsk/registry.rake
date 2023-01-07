require_relative "setup"

registry = Mrsk::Commands::Registry.new

namespace :mrsk do
  namespace :registry do
    desc "Login to the registry using ENV['DOCKER_USER'] and ENV['DOCKER_PASSWORD']"
    task :login do
      if ENV["DOCKER_USER"].present? && ENV["DOCKER_PASSWORD"].present?
        run_locally             { execute registry.login }
        on(MRSK_CONFIG.servers) { execute registry.login }
      else
        puts "Skipping login due to missing ENV['DOCKER_USER'] and ENV['DOCKER_PASSWORD']"
      end
    end
  end
end
