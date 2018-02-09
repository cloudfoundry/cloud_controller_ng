require 'messages/base_message'
require 'messages/processes/process_scale_message'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    ALLOWED_KEYS = [:instances].freeze

    attr_accessor(*ALLOWED_KEYS)

    include SharedProcessScaleValidators

    def self.create_from_http_request(parsed_yaml)
      AppManifestMessage.new(parsed_yaml.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
