class Mrsk::Configuration::Ssh
  def initialize(config:)
    @config = config.raw_config.ssh || {}
  end

  def user
    config.fetch("user", "root")
  end

  def proxy
    if (proxy = config["proxy"])
      Net::SSH::Proxy::Jump.new(proxy.include?("@") ? proxy : "root@#{proxy}")
    elsif (proxy_command = config["proxy_command"])
      Net::SSH::Proxy::Command.new(proxy_command)
    end
  end

  def options
    { user: user, proxy: proxy, auth_methods: [ "publickey" ], keepalive: true, keepalive_interval: 30 }.compact
  end

  private
    attr_accessor :config
end
