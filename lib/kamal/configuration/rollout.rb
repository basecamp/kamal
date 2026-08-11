class Kamal::Configuration::Rollout
  include Kamal::Configuration::Validation

  ON_DEPLOY = [ "keep", "ask", "stop" ]
  ON_BOOT = [ "reset", "keep" ]

  attr_reader :rollout_config

  def initialize(config:)
    @rollout_config = config.raw_config.rollout || {}
    validate! rollout_config

    ensure_valid_max_percent
    ensure_valid_on_deploy
    ensure_valid_on_boot
  end

  def max_percent
    rollout_config.fetch("max_percent", 100)
  end

  def on_deploy
    rollout_config.fetch("on_deploy", "keep").to_s.inquiry
  end

  def on_boot
    rollout_config.fetch("on_boot", "reset").to_s.inquiry
  end

  private
    def ensure_valid_max_percent
      unless max_percent.is_a?(Integer) && max_percent.between?(0, 100)
        raise Kamal::ConfigurationError, "rollout/max_percent: should be an integer between 0 and 100"
      end
    end

    def ensure_valid_on_deploy
      unless ON_DEPLOY.include?(on_deploy)
        raise Kamal::ConfigurationError, "rollout/on_deploy: should be #{ON_DEPLOY.join(", ")}"
      end
    end

    def ensure_valid_on_boot
      unless ON_BOOT.include?(on_boot)
        raise Kamal::ConfigurationError, "rollout/on_boot: should be #{ON_BOOT.join(", ")}"
      end
    end
end
