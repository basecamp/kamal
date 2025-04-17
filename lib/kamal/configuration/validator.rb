class Kamal::Configuration::Validator
  attr_reader :config, :example, :context

  def initialize(config, example:, context:)
    @config = config
    @example = example
    @context = context
  end

  def validate!
    validate_against_example! config, example
  end

  private
    def validate_against_example!(validation_config, example)
      validate_type! validation_config, example.class

      if example.class == Hash
        check_unknown_keys! validation_config, example

        validation_config.each do |key, value|
          next if extension?(key)
          with_context(key) do
            example_value = example[key]

            if example_value == "..."
              unless key.to_s == "proxy" && boolean?(value.class)
                validate_type! value, *(Array if key == :servers), Hash
              end
            elsif key == "hosts"
              validate_servers! value
            elsif example_value.is_a?(Array)
              if key == "arch"
                validate_array_of_or_type! value, example_value.first.class
              else
                validate_array_of! value, example_value.first.class
              end
            elsif example_value.is_a?(Hash)
              case key.to_s
              when "options", "args"
                validate_type! value, Hash
              when "labels"
                validate_hash_of! value, example_value.first[1].class
              else
                validate_against_example! value, example_value
              end
            else
              validate_type! value, example_value.class
            end
          end
        end
      end
    end


    def valid_type?(value, type)
      value.is_a?(type) ||
        (type == String && stringish?(value)) ||
        (boolean?(type) && boolean?(value.class))
    end

    def type_description(type)
      if type == Integer || type == Array
        "an #{type.name.downcase}"
      elsif type == TrueClass || type == FalseClass
        "a boolean"
      else
        "a #{type.name.downcase}"
      end
    end

    def boolean?(type)
      type == TrueClass || type == FalseClass
    end

    def stringish?(value)
      value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
    end

    def validate_array_of_or_type!(value, type)
      if value.is_a?(Array)
        validate_array_of! value, type
      else
        validate_type! value, type
      end
    rescue Kamal::ConfigurationError
      type_error(Array, type)
    end

    def validate_array_of!(array, type)
      validate_type! array, Array

      array.each_with_index do |value, index|
        with_context(index) do
          validate_type! value, type
        end
      end
    end

    def validate_hash_of!(hash, type)
      validate_type! hash, Hash

      hash.each do |key, value|
        with_context(key) do
          validate_type! value, type
        end
      end
    end

    def validate_servers!(servers)
      validate_type! servers, Array

      servers.each_with_index do |server, index|
        with_context(index) do
          validate_type! server, String, Hash

          if server.is_a?(Hash)
            error "multiple hosts found" unless server.size == 1
            host, tags = server.first

            with_context(host) do
              validate_type! tags, String, Array
              validate_array_of! tags, String if tags.is_a?(Array)
            end
          end
        end
      end
    end

    def validate_type!(value, *types)
      type_error(*types) unless types.any? { |type| valid_type?(value, type) }
    end

    def error(message)
      raise Kamal::ConfigurationError, "#{error_context}#{message}"
    end

    def type_error(*expected_types)
      error "should be #{expected_types.map { |type| type_description(type) }.join(" or ")}"
    end

    def unknown_keys_error(unknown_keys)
      error "unknown #{"key".pluralize(unknown_keys.count)}: #{unknown_keys.join(", ")}"
    end

    def error_context
      "#{context}: " if context.present?
    end

    def with_context(context)
      old_context = @context
      @context = [ @context, context ].select(&:present?).join("/")
      yield
    ensure
      @context = old_context
    end

    def allow_extensions?
      false
    end

    def extension?(key)
      key.to_s.start_with?("x-")
    end

    def check_unknown_keys!(config, example)
      unknown_keys = config.keys - example.keys
      unknown_keys.reject! { |key| extension?(key) } if allow_extensions?
      unknown_keys_error unknown_keys if unknown_keys.present?
    end

    def validate_docker_options!(options)
      if options
        error "Cannot set restart policy in docker options, unless-stopped is required" if options["restart"]
      end
    end
end
