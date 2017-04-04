require 'messages/base_message'

module VCAP::CloudController
  class AppUpdateEnvironmentVariablesMessage < BaseMessage
    ALLOWED_KEYS = [:environment_variables].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      # Nest the requested variables under `environment_variables` as BaseMessage expects keys to be known up-front
      AppUpdateEnvironmentVariablesMessage.new(environment_variables: body.deep_symbolize_keys)
    end

    validates :environment_variables, environment_variables: true

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
