module VCAP::CloudController
  class DockerLifecycleDataMessage < BaseMessage
    ALLOWED_KEYS = [].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    def self.create_from_http_request(body)
      DockerLifecycleDataMessage.new((body || {}).deep_symbolize_keys)
    end
  end
end
