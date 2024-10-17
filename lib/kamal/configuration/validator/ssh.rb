class Kamal::Configuration::Validator::Ssh < Kamal::Configuration::Validator
  BOOLEAN_OR_STRING_OR_ARRAY_OF_STRING_KEYS = [ "config" ]
  SPECIAL_KEYS = BOOLEAN_OR_STRING_OR_ARRAY_OF_STRING_KEYS

  def validate!
    validate_against_example! \
      config.except(*SPECIAL_KEYS),
      example.except(*SPECIAL_KEYS)

    BOOLEAN_OR_STRING_OR_ARRAY_OF_STRING_KEYS.each do |key|
      value = config[key]

      with_context(key) do
        validate_type! value, TrueClass, String, Array
        validate_array_of!(value, String) if value.is_a?(Array)
      end
    end
  end

  private

  def special_keys
    @special_keys ||= config.keys & SPECIAL_KEYS
  end
end
