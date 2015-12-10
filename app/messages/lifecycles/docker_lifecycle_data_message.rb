module VCAP::CloudController
  class DockerLifecycleDataMessage < BaseMessage
    ALLOWED_KEYS = [].freeze

    attr_accessor(*ALLOWED_KEYS)
    def allowed_keys
      ALLOWED_KEYS
    end

    validates_with NoAdditionalKeysValidator

    def self.create_from_http_request(body)
      DockerLifecycleDataMessage.new((body || {}).symbolize_keys)
    end
  end
end
