class Mrsk::Commands::Registry
  def login
    if (user = ENV["DOCKER_USER"]).present? && (password = ENV["DOCKER_PASSWORD"]).present?
      # FIXME: Find a way to hide PW so it's not shown on terminal
      "docker login -u #{user} -p #{password}"
    else
      raise ArgumentError, "Missing DOCKER_USER or DOCKER_PASSWORD in ENV"
    end
  end
end
