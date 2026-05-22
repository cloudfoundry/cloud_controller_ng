require 'factory_bot'

FactoryBot.definition_file_paths = [File.expand_path('factory_definitions', __dir__)]

FactoryBot.define do
  to_create do |instance|
    instance.save
    instance.refresh
  end

  # Sequences must mirror BOTH the existing top-level sequences AND every name
  # defined inside Sham.define in spec/support/fakes/blueprints.rb, because
  # surviving blueprints reference them and the lint spec exercises both worlds
  # during coexistence.
  sequence(:name)              { |n| "name-#{n}" }
  sequence(:guid)              { |_n| SecureRandom.uuid.to_s }
  sequence(:domain)            { |n| "domain-#{n}.example.com" }
  sequence(:host)              { |n| "host-#{n}" }
  sequence(:uaa_id)            { |n| "uaa-id-#{n}" }
  sequence(:port)              { |n| n + 1024 }
  sequence(:label)             { |n| "label-#{n}" }
  sequence(:description)       { |n| "desc-#{n}" }
  sequence(:sequence_id)       { |n| n }
  sequence(:stack_name)        { |n| "cflinuxfs-#{n}" }
  sequence(:feature_flag_name) do |n|
    flags = VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS.keys.map(&:to_s)
    flags[(n - 1) % flags.size]
  end
  sequence(:auth_password)       { |n| "auth-password-#{n}" }
  sequence(:auth_username)       { |n| "auth-username-#{n}" }
  sequence(:email)               { |n| "user-#{n}@example.com" }
  sequence(:error_message)       { |n| "error-message-#{n}" }
  sequence(:extra)               { |n| "extra-#{n}" }
  sequence(:instance_index)      { |n| n }
  sequence(:long_description)    { |n| "long-description-#{n}" }
  sequence(:provider)            { |n| "provider-#{n}" }
  sequence(:service_credentials) { |n| { "creds-key-#{n}" => "creds-val-#{n}" } }
  sequence(:stack)               { |n| "stack-#{n}" }
  sequence(:status)              { |_n| 'active' }
  sequence(:token)               { |n| "token-#{n}" }
  sequence(:type)                { |n| "type-#{n}" }
  sequence(:unique_id)           { |n| "unique-id-#{n}" }
  sequence(:url)                 { |n| "https://example.com/#{n}" }
  sequence(:version)             { |n| "1.0.#{n}" }

  # Sequences that mirror the original Sham.define block from
  # spec/support/fakes/blueprints.rb byte-for-byte. The Sham compatibility
  # shim in spec/support/sham_shim.rb delegates to these.
  sequence(:sham_email)               { |n| "email-#{n}@somedomain.com" }
  sequence(:sham_name)                { |n| "name-#{n}" }
  sequence(:sham_label)               { |n| "label-#{n}" }
  sequence(:sham_token)               { |n| "token-#{n}" }
  sequence(:sham_auth_username)       { |n| "auth_username-#{n}" }
  sequence(:sham_auth_password)       { |n| "auth_password-#{n}" }
  sequence(:sham_provider)            { |n| "provider-#{n}" }
  sequence(:sham_port)                { |n| n + 1024 }
  sequence(:sham_url)                 { |n| "https://foo.com/url-#{n}" }
  sequence(:sham_type)                { |n| "type-#{n}" }
  sequence(:sham_description)         { |n| "desc-#{n}" }
  sequence(:sham_long_description)    { |n| "long description-#{n} over 255 characters #{'-' * 255}" }
  sequence(:sham_version)             { |n| "version-#{n}" }
  sequence(:sham_service_credentials) { |n| { "creds-key-#{n}" => "creds-val-#{n}" } }
  sequence(:sham_uaa_id)              { |n| "uaa-id-#{n}" }
  sequence(:sham_domain)              { |n| "domain-#{n}.example.com" }
  sequence(:sham_host)                { |n| "host-#{n}" }
  sequence(:sham_guid)                { |_n| SecureRandom.uuid.to_s }
  sequence(:sham_extra)               { |n| "extra-#{n}" }
  sequence(:sham_instance_index)      { |n| n }
  sequence(:sham_unique_id)           { |n| "unique-id-#{n}" }
  sequence(:sham_status)              { |_n| %w[active suspended canceled].sample(1).first }
  sequence(:sham_error_message)       { |n| "error-message-#{n}" }
  sequence(:sham_sequence_id)         { |n| n }
  sequence(:sham_stack)               { |n| "cflinuxfs-#{n}" }
end

FactoryBot.find_definitions

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
