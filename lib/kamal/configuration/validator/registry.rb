class Kamal::Configuration::Validator::Registry < Kamal::Configuration::Validator
  STRING_OR_ONE_ITEM_ARRAY_KEYS = [ "username", "password" ]

  def validate!
    validate_against_example! \
      config.except(*STRING_OR_ONE_ITEM_ARRAY_KEYS),
      example.except(*STRING_OR_ONE_ITEM_ARRAY_KEYS)

    validate_string_or_one_item_array! "username"
    validate_string_or_one_item_array! "password"
  end

  private
    def validate_string_or_one_item_array!(key)
      with_context(key) do
        value = config[key]

        error "is required" unless value.present?

        unless value.is_a?(String) || (value.is_a?(Array) && value.size == 1 && value.first.is_a?(String))
          error "should be a string or an array with one string (for secret lookup)"
        end
      end
    end
end
