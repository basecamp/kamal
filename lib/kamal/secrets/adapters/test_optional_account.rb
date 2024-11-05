class Kamal::Secrets::Adapters::TestOptionalAccount < Kamal::Secrets::Adapters::Test
  def requires_account?
    false
  end
end
