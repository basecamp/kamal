class Kamal::Configuration::Validator::Ssh < Kamal::Configuration::Validator
  def validate!
    validate_against_example!(
      config.except("key_data"),
      example.except("key_data")
    )

    validate_string_or_array! "key_data"
  end

  private
  def validate_string_or_array!(key)
    value = config[key]

    return unless value.present?

    unless value.is_a?(String) || value.is_a?(Array)
      error "should be a string (for secret lookup) or an array"
    end
  end

end
