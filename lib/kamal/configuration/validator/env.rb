class Kamal::Configuration::Validator::Env < Kamal::Configuration::Validator
  SPECIAL_KEYS = [ "clear", "secret", "tags" ]

  def validate!
    if known_keys.any?
      validate_complex_env!
    else
      validate_simple_env!
    end
  end

  private
    def validate_simple_env!
      validate_hash_of!(config, String)
    end

    def validate_complex_env!
      unknown_keys_error unknown_keys if unknown_keys.any?

      with_context("clear") { validate_hash_of!(config["clear"], String) } if config.key?("clear")
      with_context("secret") { validate_array_of!(config["secret"], String) } if config.key?("secret")
      validate_tags! if config.key?("tags")
    end

    def known_keys
      @known_keys ||= config.keys & SPECIAL_KEYS
    end

    def unknown_keys
      @unknown_keys ||= config.keys - SPECIAL_KEYS
    end

    def validate_tags!
      if context == "env"
        with_context("tags") do
          validate_type! config["tags"], Hash

          config["tags"].each do |tag, value|
            with_context(tag) do
              validate_type! value, Hash

              Kamal::Configuration::Validator::Env.new(
                value,
                example: example["tags"].values[1],
                context: context
              ).validate!
            end
          end
        end
      else
        error "tags are only allowed in the root env"
      end
    end
end
