class Mrsk::Commands::Registry < Mrsk::Commands::Base
  def login
    "docker login #{config.registry["server"]} -u #{config.registry["username"]} -p #{config.registry["password"]}"
  end

  def logout
    "docker logout #{config.registry["server"]}"
  end
end
